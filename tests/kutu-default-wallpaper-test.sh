#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

SCRIPT="packages/kutu-desktop-xfce/usr/lib/kutu/kutu-default-wallpaper.sh"
[ -f "$SCRIPT" ] || { echo "FAIL: $SCRIPT missing"; exit 1; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/home/.config" "$tmp/props"

cat > "$tmp/bin/xrandr" <<'EOF'
#!/usr/bin/env bash
echo "Virtual-1 connected 2560x1440+0+0 (normal) inverted X axis 1024mm x 576mm"
echo "HDMI-A-1 connected primary 1920x1080+2560+0 (normal) left inverted X axis 597mm x 336mm"
echo "DP-1 disconnected 2560x1440+0+0"
EOF

cat > "$tmp/bin/xfconf-query" <<'EOF'
#!/usr/bin/env bash
prop=""
mode="read"
while [ $# -gt 0 ]; do
  case "$1" in
    -p) prop="$2"; shift 2 ;;
    -s) mode="set"; val="$2"; shift 2 ;;
    -n|-c) shift ;;
    -t) shift 2 ;;
    *) shift ;;
  esac
done
echo "$mode:$prop" >> "$STUB_LOG"
if [ "$mode" = "set" ]; then
  file="$STUB_PROPS/$prop"
  mkdir -p "$(dirname "$file")"
  printf '%s' "$val" > "$file"
  exit 0
fi
if [ -f "$STUB_PROPS/$prop" ]; then cat "$STUB_PROPS/$prop"; exit 0; fi
exit 1
EOF
chmod +x "$tmp/bin/xrandr" "$tmp/bin/xfconf-query"

export PATH="$tmp/bin:$PATH"
export STUB_LOG="$tmp/stub.log"
export STUB_PROPS="$tmp/props"
export HOME="$tmp/home"
export KUTU_WALLPAPER="$tmp/wallpapers/kutu-default.svg"
mkdir -p "$tmp/wallpapers"
touch "$KUTU_WALLPAPER"

: > "$STUB_LOG"
env -u XDG_CONFIG_HOME "$SCRIPT"
grep -q '^set:/backdrop/screen0/monitorVirtual-1/workspace0/last-image$' "$STUB_LOG"
grep -q '^set:/backdrop/screen0/monitorHDMI-A-1/workspace0/last-image$' "$STUB_LOG"
if grep -q 'monitorDP-1' "$STUB_LOG"; then echo "FAIL: set wallpaper on disconnected output"; exit 1; fi
[ -f "$HOME/.config/kutu/wallpaper-applied" ] || { echo "FAIL: marker not created"; exit 1; }
grep -q kutu-default.svg "$tmp/props/backdrop/screen0/monitorVirtual-1/workspace0/last-image"

: > "$STUB_LOG"
env -u XDG_CONFIG_HOME "$SCRIPT"
if [ -s "$STUB_LOG" ]; then echo "FAIL: ran again despite marker"; exit 1; fi

rm -f "$HOME/.config/kutu/wallpaper-applied"
: > "$STUB_LOG"
env -u XDG_CONFIG_HOME "$SCRIPT"
grep -q '^set:/backdrop/screen0/monitorVirtual-1/workspace0/last-image$' "$STUB_LOG"
[ -f "$HOME/.config/kutu/wallpaper-applied" ] || { echo "FAIL: marker not re-created"; exit 1; }

echo "kutu-default-wallpaper tests: PASS"