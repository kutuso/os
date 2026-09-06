#!/usr/bin/env bash
set -euo pipefail
F="${KUTU_FIREFOX_DESKTOP:-/usr/share/applications/firefox.desktop}"
[ -r "$F" ] || exit 0
sed -i -E 's,^Exec=(firefox|/usr/lib/firefox/firefox)( |$),Exec=kutu-run firefox\2,' "$F"
wrapped=$(grep -c '^Exec=kutu-run firefox' "$F" || true)
[ "$wrapped" -gt 0 ] || { echo "kutu firefox wrap: no Exec lines matched in $F" >&2; exit 1; }
