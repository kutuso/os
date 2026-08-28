#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
cat > "$tmp/firefox.desktop" <<'EOF'
[Desktop Entry]
Exec=firefox %u
Actions=new-window;new-private-window;

[Desktop Action new-window]
Exec=firefox --new-window %u

[Desktop Action new-private-window]
Exec=firefox --private-window %u
EOF
KUTU_FIREFOX_DESKTOP="$tmp/firefox.desktop" packages/kutu-desktop-xfce/usr/lib/kutu/patch-firefox-desktop.sh
grep -q '^Exec=kutu-run firefox %u$' "$tmp/firefox.desktop"
[ "$(grep -c 'Exec=kutu-run firefox' "$tmp/firefox.desktop")" = 3 ]
KUTU_FIREFOX_DESKTOP="$tmp/nonexistent.desktop" packages/kutu-desktop-xfce/usr/lib/kutu/patch-firefox-desktop.sh
echo "patch-firefox-desktop tests: PASS"
