#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
cat > "$tmp/firefox.desktop" <<'EOF'
[Desktop Entry]
Exec=/usr/lib/firefox/firefox %u
Actions=new-window;new-private-window;

[Desktop Action new-window]
Exec=/usr/lib/firefox/firefox --new-window %u

[Desktop Action new-private-window]
Exec=/usr/lib/firefox/firefox --private-window %u
EOF
cat > "$tmp/firefox-short.desktop" <<'EOF'
[Desktop Entry]
Exec=firefox %u

[Desktop Action new-window]
Exec=firefox --new-window %u
EOF
SCRIPT="packages/kutu-desktop-xfce/usr/lib/kutu/patch-firefox-desktop.sh"
KUTU_FIREFOX_DESKTOP="$tmp/firefox.desktop" "$SCRIPT"
grep -q '^Exec=kutu-run firefox %u$' "$tmp/firefox.desktop"
[ "$(grep -c 'Exec=kutu-run firefox' "$tmp/firefox.desktop")" = 3 ]
KUTU_FIREFOX_DESKTOP="$tmp/firefox.desktop" "$SCRIPT"
KUTU_FIREFOX_DESKTOP="$tmp/firefox-short.desktop" "$SCRIPT"
grep -q '^Exec=kutu-run firefox %u$' "$tmp/firefox-short.desktop"
[ "$(grep -c 'Exec=kutu-run firefox' "$tmp/firefox-short.desktop")" = 2 ]
cat > "$tmp/other.desktop" <<'EOF'
[Desktop Entry]
Exec=/opt/other/browser %u
EOF
if KUTU_FIREFOX_DESKTOP="$tmp/other.desktop" "$SCRIPT" 2>/dev/null; then
  echo "FAIL: unwrapped firefox Exec lines did not fail the patch"; exit 1
fi
KUTU_FIREFOX_DESKTOP="$tmp/nonexistent.desktop" "$SCRIPT"
echo "patch-firefox-desktop tests: PASS"
