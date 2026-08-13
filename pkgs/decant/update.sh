#!/usr/bin/env bash
### Prints {"version":"...","url":"..."} for the latest darwin-arm64 release,
### or exits non-zero with a message on stderr. Called by `pkgs-update` (see
### ../pkgs-update and ../../scripts/pkgs-update.sh) — this script never reads
### or writes source.json itself, the driver does.
set -euo pipefail

release="$(curl -fsSL https://api.github.com/repos/dosu-ai/decant/releases/latest)"

version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$release")"
url="$(jq -r '.assets[] | select(.name == "decant-darwin-arm64.tar.gz") | .browser_download_url' <<<"$release")"

if [[ -z "$version" || "$version" == "null" || -z "$url" || "$url" == "null" ]]; then
  echo "error: couldn't find version/darwin-arm64 asset in the latest dosu-ai/decant release" >&2
  exit 1
fi

jq -nc --arg version "$version" --arg url "$url" '{version: $version, url: $url}'
