#!/usr/bin/env bash
### Prints {"version":"...","url":"..."} for the latest darwin-universal
### release, or exits non-zero with a message on stderr. Called by
### `pkgs-update` (see ../pkgs-update and ../../scripts/pkgs-update.sh) — this
### script never reads or writes source.json itself, the driver does.
set -euo pipefail

# Soloterm has no appcast/latest.json/GitHub-releases endpoint (all checked,
# all 404). The only machine-readable source is this Inertia.js page, whose
# root element carries the whole payload as HTML-escaped JSON in its
# `data-page="…"` attribute. This is scraping — if soloterm.com restyles the
# download page this will start failing loudly, which is the correct failure
# mode (no bump), not silently emitting a stale/wrong version.
page="$(curl -fsSL https://soloterm.com/download)"

escaped="$(grep -o 'data-page="[^"]*"' <<<"$page" | sed -E 's/^data-page="(.*)"$/\1/')"

if [[ -z "$escaped" ]]; then
  echo "error: no data-page attribute found on soloterm.com/download (page layout changed?)" >&2
  exit 1
fi

# Unescape the handful of HTML entities Blade/Inertia use to embed JSON in an
# HTML attribute. The escaping sits on top of otherwise-valid JSON, so
# unescaping restores it (e.g. release notes with `\&quot;` become `\"`).
# &amp; must be last, or a double-escaped entity would wrongly unescape twice.
json="$(
  sed \
    -e 's/&quot;/"/g' \
    -e "s/&#0*39;/'/g" \
    -e 's/&lt;/</g' \
    -e 's/&gt;/>/g' \
    -e 's/&amp;/\&/g' \
    <<<"$escaped"
)"

result="$(jq -er '.props.versions["darwin-universal"] | {version, url: .download_url} | @json' <<<"$json" 2>/dev/null || true)"

if [[ -z "$result" || "$result" == "null" ]]; then
  echo "error: darwin-universal version/download_url not found in soloterm.com/download payload (page layout changed?)" >&2
  exit 1
fi

echo "$result"
