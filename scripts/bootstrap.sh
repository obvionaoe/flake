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
  echo "==> $flake_dir already exists, leaving it as-is (not re-cloning)."
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

echo "==> Running first darwin-rebuild switch for host '$hostname' (requires sudo)..."
/usr/bin/sudo "$DARWIN_REBUILD" switch \
  --flake "$flake_dir#$hostname" \
  --extra-experimental-features "nix-command flakes"

echo "==> Done. $flake_dir is now the source of truth for this machine."
echo "    Future rebuilds: darwin-rebuild switch --flake $flake_dir#$hostname"
