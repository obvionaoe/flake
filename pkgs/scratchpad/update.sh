#!/usr/bin/env bash
### Prints {"version":"...","url":"..."} for the current trial build, or exits
### non-zero with a message on stderr. Called by `pkgs-update` (see
### ../pkgs-update and ../../scripts/pkgs-update.sh) — this script never reads
### or writes source.json itself, the driver does.
set -euo pipefail

# No API or stable "latest" URL exists: the trial link is a Dropbox file whose
# name embeds the version and a timestamp, linked from the "Trial" section of
# the product page. Scraping it is brittle by nature — if the page changes this
# fails loudly (no bump) rather than emitting a wrong URL.
page="$(curl -fsSL https://sindresorhus.com/scratchpad)"

url="$(grep -oE 'https://www\.dropbox\.com/scl/fi/[^"]*Scratchpad-[0-9][^"]*-trial-[^"]*\.zip[^"]*' <<<"$page" | head -n1 | sed 's/&amp;/\&/g')"

if [[ -z "$url" ]]; then
  echo "error: trial download link not found on sindresorhus.com/scratchpad (page layout changed?)" >&2
  exit 1
fi

version="$(sed -E 's#.*/Scratchpad-([0-9][0-9.]*)-trial-.*#\1#' <<<"$url")"

if [[ -z "$version" || "$version" == "$url" ]]; then
  echo "error: could not parse a version from trial URL: $url" >&2
  exit 1
fi

jq -nc --arg version "$version" --arg url "$url" '{version: $version, url: $url}'
