### REPO_URL and DARWIN_REBUILD are injected by flake.nix's writeShellApplication wrapper.

if [[ "$(/usr/bin/uname)" != "Darwin" ]]; then
  echo "error: this bootstrap only supports macOS hosts (nix-darwin)." >&2
  exit 1
fi

hostname="${1:-}"
if [[ -z "$hostname" ]]; then
  read -rp "Hostname (matches a hosts/darwin/<name> directory in the flake): " hostname
fi
if [[ -z "$hostname" ]]; then
  echo "error: no hostname given." >&2
  exit 1
fi

echo "==> Checking Xcode Command Line Tools..."
if ! /usr/bin/xcode-select -p >/dev/null 2>&1; then
  echo "Xcode Command Line Tools not found — triggering install (finish the GUI dialog that pops up)."
  /usr/bin/xcode-select --install
  until /usr/bin/xcode-select -p >/dev/null 2>&1; do
    sleep 5
  done
fi
echo "Xcode Command Line Tools OK."

echo "==> Backing up any pre-existing /etc files that would conflict with nix-darwin..."
etc_conflicts=(
  "/etc/nix/nix.conf"
  "/etc/bashrc"
  "/etc/zshrc"
  "/etc/bash.bashrc"
  "/etc/zprofile"
  "/etc/zshenv"
)
for f in "${etc_conflicts[@]}"; do
  if [[ -e "$f" && ! -e "$f.before-nix-darwin" ]]; then
    echo "backing up $f -> $f.before-nix-darwin"
    /usr/bin/sudo /bin/mv "$f" "$f.before-nix-darwin"
  fi
done

flake_dir="$HOME/.flake"
if [[ -d "$flake_dir" ]]; then
  if [[ ! -d "$flake_dir/.git" ]]; then
    echo "error: $flake_dir exists but isn't a git repo; move or remove it and re-run." >&2
    exit 1
  fi
  echo "==> $flake_dir already exists."
  # Syncing is destructive (reset --hard + clean -fd), so never do it unasked;
  # a non-interactive run (read fails on EOF) defaults to leaving it alone.
  if [[ -n "$(git -C "$flake_dir" status --porcelain)" ]]; then
    echo "    It has local changes:"
    git -C "$flake_dir" status --short | /usr/bin/sed 's/^/      /'
  fi
  sync_answer=""
  # An existing checkout keeps whatever origin it has (e.g. an SSH alias for
  # pushing); REPO_URL is only used to add one when there is none.
  git -C "$flake_dir" remote get-url origin >/dev/null 2>&1 \
    || git -C "$flake_dir" remote add origin "$REPO_URL"
  origin_url="$(git -C "$flake_dir" remote get-url origin)"
  read -rp "Sync it to the latest main from $origin_url? This DISCARDS all local changes and untracked files. [y/N] " sync_answer || true
  if [[ "$sync_answer" =~ ^[Yy]$ ]]; then
    git -C "$flake_dir" fetch origin main
    git -C "$flake_dir" checkout -B main origin/main
    git -C "$flake_dir" reset --hard origin/main
    git -C "$flake_dir" clean -fd
  else
    echo "    Leaving $flake_dir as is."
  fi
else
  echo "==> Cloning $REPO_URL to $flake_dir..."
  git clone "$REPO_URL" "$flake_dir"
fi

if [[ ! -d "$flake_dir/hosts/darwin/$hostname" ]]; then
  echo "error: no hosts/darwin/$hostname directory in the flake." >&2
  echo "Available hosts:" >&2
  ls "$flake_dir/hosts/darwin" >&2
  exit 1
fi

echo "==> Checking that host '$hostname' is configured for this macOS account..."
expected_user="$(nix eval --raw \
  --option experimental-features "nix-command flakes" \
  "$flake_dir#darwinConfigurations.$hostname.config.system.primaryUser" 2>/dev/null || true)"
current_user="$(/usr/bin/id -un)"
if [[ -n "$expected_user" && "$expected_user" != "$current_user" ]]; then
  echo "error: host '$hostname' is configured for macOS account '$expected_user', but you are '$current_user'." >&2
  echo "       Fix system.primaryUser in hosts/darwin/$hostname/default.nix, or bootstrap a different host." >&2
  exit 1
fi

# Hosts whose git identity can't be committed to this public repo set
# `modules.git.identityFile` to a path outside it (see modules/shared/git).
# Nothing creates that file but this, so prompt for it before the first switch —
# git silently ignores a missing include, so a skipped prompt just means an
# identity-less git until the file is written by hand.
echo "==> Checking git identity for host '$hostname'..."
identity_file="$(nix eval --raw \
  --option experimental-features "nix-command flakes" \
  --apply 'v: if v == null then "" else v' \
  "$flake_dir#darwinConfigurations.$hostname.config.modules.git.identityFile" 2>/dev/null || true)"

if [[ -z "$identity_file" ]]; then
  echo "Host '$hostname' declares its git identity in the flake — nothing to write."
else
  identity_path="${identity_file/#\~/$HOME}"
  if [[ -e "$identity_path" ]]; then
    echo "$identity_path already exists — leaving it alone."
    # Files written before signing was pinned per identity have no signingkey.
    # Add just that line (derived from the file's own email) so re-running the
    # bootstrap upgrades them; everything else in the file is untouched.
    existing_email="$(git config --file "$identity_path" user.email 2>/dev/null || true)"
    if [[ -n "$existing_email" && -z "$(git config --file "$identity_path" user.signingkey 2>/dev/null || true)" ]]; then
      git config --file "$identity_path" user.signingkey "$existing_email"
      /bin/chmod 600 "$identity_path"
      echo "Added signingkey = $existing_email to $identity_path."
    fi
  else
    echo "Host '$hostname' keeps its git identity out of the repo, in $identity_path."
    git_name=""
    git_email=""
    # `|| true`: the wrapper runs under `set -e`, and `read` fails on EOF (a
    # non-interactive run) — that should fall through to the warning, not abort
    # the whole bootstrap. An empty answer ends the loop the same way.
    # The email is also this identity's GPG signing key (modules/shared/git
    # pins user.signingKey to it), so a typo here silently breaks signing:
    # reject anything that isn't shaped like an address and make the user
    # confirm what they typed.
    while true; do
      read -rp "  git user.name: " git_name || true
      read -rp "  git user.email: " git_email || true
      [[ -z "$git_name" || -z "$git_email" ]] && break
      if [[ ! "$git_email" =~ ^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$ ]]; then
        echo "  '$git_email' doesn't look like an email address — try again." >&2
        continue
      fi
      confirm=""
      read -rp "  Use $git_name <$git_email>? [Y/n] " confirm || true
      [[ ! "$confirm" =~ ^[Nn]$ ]] && break
    done
    if [[ -z "$git_name" || -z "$git_email" ]]; then
      echo "warning: name or email left empty — skipping. git will have no identity" >&2
      echo "         on this machine until you create $identity_path yourself:" >&2
      echo "           [user]" >&2
      echo "             name = ..." >&2
      echo "             email = ..." >&2
      echo "             signingkey = <same email>" >&2
    else
      /bin/mkdir -p "$(/usr/bin/dirname "$identity_path")"
      /bin/cat >"$identity_path" <<EOF
# Written by scripts/bootstrap.sh. Not managed by ~/.flake, and deliberately
# outside it — this identity must not be committed to a public repo.
[user]
	name = $git_name
	email = $git_email
	signingkey = $git_email
EOF
      /bin/chmod 600 "$identity_path"
      echo "Wrote $identity_path."
    fi
  fi
fi

echo "==> Running first darwin-rebuild switch for host '$hostname' (requires sudo)..."
/usr/bin/sudo "$DARWIN_REBUILD" switch \
  --flake "$flake_dir#$hostname" \
  --option experimental-features "nix-command flakes"

# gh is installed by the switch above (modules.gh), so its login can only
# happen afterwards. The credential goes into gh's own store (keyring), never
# the repo, and the zsh/session wiring in modules/shared/gh picks it up as
# GH_TOKEN/GITHUB_TOKEN in any terminal window opened after this. Token vars
# are stripped from the calls since gh would otherwise report them as the login.
gh_enabled="$(nix eval --raw \
  --option experimental-features "nix-command flakes" \
  --apply 'v: if v then "yes" else "no"' \
  "$flake_dir#darwinConfigurations.$hostname.config.modules.gh.enable" 2>/dev/null || true)"
if [[ "$gh_enabled" == "yes" ]]; then
  echo "==> Checking GitHub CLI login..."
  gh_bin="/etc/profiles/per-user/$current_user/bin/gh"
  gh_state="$(nix eval --raw \
    --option experimental-features "nix-command flakes" \
    "$flake_dir#darwinConfigurations.$hostname.config.home-manager.users.$current_user.xdg.stateHome" 2>/dev/null || true)/gh"
  if [[ ! -x "$gh_bin" ]]; then
    echo "warning: $gh_bin not found — skipping. Run 'gh auth login' yourself once it's on PATH." >&2
  elif env -u GH_TOKEN -u GITHUB_TOKEN GH_CONFIG_DIR="$gh_state" "$gh_bin" auth status >/dev/null 2>&1; then
    echo "Already logged in to GitHub — leaving it alone."
  else
    echo "Not logged in to GitHub — starting 'gh auth login' (browser flow; SSH keys are handled separately)."
    # `|| echo`: a failed or skipped login (including a non-interactive run) shouldn't
    # abort the bootstrap, which has already done the important part.
    env -u GH_TOKEN -u GITHUB_TOKEN GH_CONFIG_DIR="$gh_state" "$gh_bin" auth login \
      --hostname github.com --git-protocol ssh --web --skip-ssh-key \
      || echo "warning: gh login didn't complete — run 'gh auth login' yourself later." >&2
  fi
fi

# Things only a person can finish: nothing in the flake creates SSH or GPG
# keys, grants macOS permissions, or signs into apps. Check what can be checked
# and print the rest as a checklist, limited to what this host actually enables.
host_cfg="$flake_dir#darwinConfigurations.$hostname.config"
# flag <attr under config> [nix function turning the value into a bool]
flag() {
  [[ "$(nix eval --raw \
    --option experimental-features "nix-command flakes" \
    --apply "v: if (${2:-v}) then \"yes\" else \"no\"" \
    "$host_cfg.$1" 2>/dev/null || true)" == "yes" ]]
}
# str <attr under config>: the value, or "" if null/unset.
str() {
  nix eval --raw \
    --option experimental-features "nix-command flakes" \
    --apply 'v: if v == null then "" else v' \
    "$host_cfg.$1" 2>/dev/null || true
}

todo=()

if flag modules.ssh.enable; then
  ssh_keys=()
  default_key="$(str modules.ssh.defaultIdentityFile)"
  [[ -n "$default_key" ]] && ssh_keys+=("$default_key")
  # The key modules/shared/git pins for ~/.flake and ~/personal, if any.
  personal_key="$(str modules.git.personalSshKey)"
  [[ -n "$personal_key" ]] && ssh_keys+=("$personal_key")
  for key in "${ssh_keys[@]}"; do
    if [[ ! -e "${key/#\~/$HOME}" ]]; then
      todo+=("SSH key $key is missing: create or restore it, register it on GitHub, then 'ssh-add --apple-use-keychain $key' (git over SSH fails without it).")
    fi
  done
fi

if flag modules.gnupg.enable; then
  gpg_bin="/etc/profiles/per-user/$current_user/bin/gpg"
  # Signing is strict and each identity signs only with the key matching its
  # own email (modules/shared/git pins user.signingKey), so a missing key blocks
  # commits for that identity instead of falling back to another one. ~/.flake
  # and ~/personal always use the public identity, on every host; this host's
  # own identity, when it lives in an identity file, is checked too.
  gpg_emails=("obvionaoe@protonmail.com")
  if [[ -n "${identity_path:-}" && -e "$identity_path" ]]; then
    identity_email="$(git config --file "$identity_path" user.email 2>/dev/null || true)"
    [[ -n "$identity_email" ]] && gpg_emails+=("$identity_email")
    if [[ -n "$identity_email" && -z "$(git config --file "$identity_path" user.signingkey 2>/dev/null || true)" ]]; then
      todo+=("$identity_path has no 'signingkey = $identity_email' under [user]: add it so commits are only ever signed with that identity's key.")
    fi
  fi
  for email in "${gpg_emails[@]}"; do
    if ! "$gpg_bin" --list-secret-keys --with-colons "$email" 2>/dev/null | /usr/bin/grep -q '^sec'; then
      todo+=("No GPG secret key for $email: generate or import one (its user ID must contain that exact email), otherwise commits made as that identity fail to sign.")
    fi
  done
fi

if flag modules.containers.enable; then
  todo+=("Docker Desktop: launch it once, accept the license, and check Settings > General > 'Start Docker Desktop when you log in'.")
fi
for m in openlogi skhd wheelclick; do
  if flag "modules.$m.enable"; then
    todo+=("$m: grant it Accessibility (and Input Monitoring where asked) in System Settings > Privacy & Security.")
  fi
done
if flag homebrew.masApps 'v != {}'; then
  todo+=("Mac App Store apps are declared for this host: sign into the App Store (or finish MDM enrollment) so they provision.")
fi
if flag modules.bitwarden.enable; then todo+=("Bitwarden: sign in."); fi
if flag modules.claude-code.enable; then todo+=("Claude Code: run 'claude' and sign in."); fi
if flag modules.cloud.enable; then
  todo+=("Cloud CLIs: 'aws configure sso' and 'gcloud auth login' as needed.")
fi

if ((${#todo[@]} > 0)); then
  echo "==> Still to do by hand:"
  for item in "${todo[@]}"; do
    echo "  - $item"
  done
fi

echo "==> Done. $flake_dir is now the source of truth for this machine."
echo "    Future rebuilds: darwin-rebuild switch --flake $flake_dir#$hostname"
