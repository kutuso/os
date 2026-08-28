#!/usr/bin/env bash
set -euo pipefail
F="${KUTU_FIREFOX_DESKTOP:-/usr/share/applications/firefox.desktop}"
[ -r "$F" ] || exit 0
sed -i -E 's,^Exec=firefox( |$),Exec=kutu-run firefox\1,' "$F"
