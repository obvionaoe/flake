### Refreshes self-rolled derivations under pkgs/<name>/ to their latest
### upstream version. Never builds or activates anything — it only rewrites
### pkgs/<name>/source.json; you review the diff and run darwin-rebuild
### yourself. See pkgs/CLAUDE.md for the update.sh contract new packages
### must follow to be picked up here.
###
### Usage:
###   pkgs-update <name>...   # update one or more named packages
###   pkgs-update --all       # every pkgs/*/ that has an update.sh
###   pkgs-update --dry-run   # combine with the above: report only, write nothing

set -euo pipefail

usage() {
  echo "usage: pkgs-update [--dry-run] (<name>... | --all)" >&2
  exit 1
}

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "$repo_root" || ! -f "$repo_root/flake.nix" ]]; then
  repo_root="$HOME/.flake"
fi
pkgs_dir="$repo_root/pkgs"

dry_run=false
names=()
all=false

for arg in "$@"; do
  case "$arg" in
    --dry-run) dry_run=true ;;
    --all) all=true ;;
    -*) usage ;;
    *) names+=("$arg") ;;
  esac
done

if $all; then
  names=()
  for dir in "$pkgs_dir"/*/; do
    name="$(basename "$dir")"
    [[ -x "$dir/update.sh" ]] && names+=("$name")
  done
elif [[ ${#names[@]} -eq 0 ]]; then
  usage
fi

if [[ ${#names[@]} -eq 0 ]]; then
  echo "no packages with an update.sh found under $pkgs_dir" >&2
  exit 1
fi

updated=0
failed=0

for name in "${names[@]}"; do
  pkg_dir="$pkgs_dir/$name"
  update_script="$pkg_dir/update.sh"
  source_json="$pkg_dir/source.json"

  if [[ ! -x "$update_script" ]]; then
    echo "$name: no update.sh at $update_script" >&2
    failed=$((failed + 1))
    continue
  fi
  if [[ ! -f "$source_json" ]]; then
    echo "$name: no source.json at $source_json" >&2
    failed=$((failed + 1))
    continue
  fi

  if ! latest_json="$("$update_script")"; then
    echo "$name: update.sh failed, skipping" >&2
    failed=$((failed + 1))
    continue
  fi

  latest_version="$(jq -r '.version' <<<"$latest_json")"
  latest_url="$(jq -r '.url' <<<"$latest_json")"
  current_version="$(jq -r '.version' "$source_json")"
  current_hash="$(jq -r '.hash' "$source_json")"

  if [[ "$latest_version" == "$current_version" ]]; then
    echo "$name: already up to date ($current_version)"
    continue
  fi

  echo "$name: $current_version -> $latest_version"

  if $dry_run; then
    echo "  (dry run, not writing)"
    updated=$((updated + 1))
    continue
  fi

  if ! prefetch_json="$(nix store prefetch-file --json --hash-type sha256 "$latest_url" 2>&1)"; then
    echo "$name: prefetch of $latest_url failed:" >&2
    echo "$prefetch_json" >&2
    failed=$((failed + 1))
    continue
  fi
  latest_hash="$(jq -r '.hash' <<<"$prefetch_json")"

  echo "  hash: $current_hash -> $latest_hash"

  tmp="$(mktemp "$pkg_dir/source.json.XXXXXX")"
  jq -n \
    --arg version "$latest_version" \
    --arg url "$latest_url" \
    --arg hash "$latest_hash" \
    '{version: $version, url: $url, hash: $hash}' \
    >"$tmp"
  mv "$tmp" "$source_json"

  updated=$((updated + 1))
done

echo
if [[ $updated -eq 0 ]]; then
  echo "no packages updated."
else
  host="$(scutil --get LocalHostName 2>/dev/null || hostname -s 2>/dev/null || echo '<host>')"
  if [[ ! -d "$repo_root/hosts/darwin/$host" ]]; then
    host="<host>"
  fi
  echo "$updated package(s) updated. Review the diff, then:"
  echo "  darwin-rebuild switch --flake $repo_root#$host"
fi

[[ $failed -eq 0 ]]
