#!/usr/bin/env bash
### Prints {"version":"...","url":"..."} for the latest strix-agent macOS arm64
### wheel on PyPI, or exits non-zero with a message on stderr. Called by
### `pkgs-update` (see ../pkgs-update and ../../scripts/pkgs-update.sh) — this
### script never reads or writes source.json itself, the driver does.
set -euo pipefail

release="$(curl -fsSL https://pypi.org/pypi/strix-agent/json)"

version="$(jq -r '.info.version' <<<"$release")"
url="$(jq -r '.urls[] | select(.packagetype == "bdist_wheel" and (.filename | test("-macosx_[0-9_]+_arm64\\.whl$"))) | .url' <<<"$release")"

if [[ -z "$version" || "$version" == "null" || -z "$url" || "$url" == "null" ]]; then
  echo "error: couldn't find version/macOS arm64 wheel in the latest strix-agent PyPI release" >&2
  exit 1
fi

jq -nc --arg version "$version" --arg url "$url" '{version: $version, url: $url}'
