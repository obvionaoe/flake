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

if [[ "$(/usr/bin/uname -m)" == "arm64" ]]; then
  echo "==> Checking Rosetta 2..."
  if ! /usr/bin/arch -arch x86_64 /usr/bin/true >/dev/null 2>&1; then
    echo "Rosetta 2 not found — installing (requires sudo)."
    /usr/bin/sudo /usr/sbin/softwareupdate --install-rosetta --agree-to-license
  fi
  echo "Rosetta 2 OK."
fi

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
  echo "==> $flake_dir already exists, syncing to latest $REPO_URL (local changes discarded)..."
  git -C "$flake_dir" remote set-url origin "$REPO_URL"
  git -C "$flake_dir" fetch origin main
  git -C "$flake_dir" checkout -B main origin/main
  git -C "$flake_dir" reset --hard origin/main
  git -C "$flake_dir" clean -fd
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
  else
    echo "Host '$hostname' keeps its git identity out of the repo, in $identity_path."
    git_name=""
    git_email=""
    # `|| true`: the wrapper runs under `set -e`, and `read` fails on EOF (a
    # non-interactive run) — that should fall through to the warning, not abort
    # the whole bootstrap.
    read -rp "  git user.name: " git_name || true
    read -rp "  git user.email: " git_email || true
    if [[ -z "$git_name" || -z "$git_email" ]]; then
      echo "warning: name or email left empty — skipping. git will have no identity" >&2
      echo "         on this machine until you create $identity_path yourself:" >&2
      echo "           [user]" >&2
      echo "             name = ..." >&2
      echo "             email = ..." >&2
    else
      /bin/mkdir -p "$(/usr/bin/dirname "$identity_path")"
      /bin/cat >"$identity_path" <<EOF
# Written by scripts/bootstrap.sh. Not managed by ~/.flake, and deliberately
# outside it — this identity must not be committed to a public repo.
[user]
	name = $git_name
	email = $git_email
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

echo "==> Done. $flake_dir is now the source of truth for this machine."
echo "    Future rebuilds: darwin-rebuild switch --flake $flake_dir#$hostname"
