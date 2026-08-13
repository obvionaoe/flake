#!/usr/bin/env bash
### Prints {"version":"...","url":"..."} for the latest darwin-arm64 desktop
### release, or exits non-zero with a message on stderr. Called by
### `pkgs-update` (see ../pkgs-update and ../../scripts/pkgs-update.sh) — this
### script never reads or writes source.json itself, the driver does.
###
### `desktop-latest` is a rolling tag get-bb/bb republishes on every release,
### so its assets always carry the current version in their filename.
set -euo pipefail

release="$(curl -fsSL https://api.github.com/repos/get-bb/bb/releases/tags/desktop-latest)"

url="$(jq -r '.assets[] | select(.name | test("^bb-.*-arm64\\.dmg$")) | .browser_download_url' <<<"$release")"
version="$(grep -oE '[0-9]+\.[0-9]+\.[0-9]+' <<<"$url" | head -1)"

if [[ -z "$version" || -z "$url" || "$url" == "null" ]]; then
  echo "error: couldn't find version/arm64 dmg asset in get-bb/bb's desktop-latest release" >&2
  exit 1
fi

jq -nc --arg version "$version" --arg url "$url" '{version: $version, url: $url}'
