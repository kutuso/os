#!/usr/bin/env bash
set -euo pipefail

WALLPAPER="${KUTU_WALLPAPER:-/usr/share/backgrounds/xfce/kutu-default.svg}"
MARKER="${XDG_CONFIG_HOME:-$HOME/.config}/kutu/wallpaper-applied"

[ -f "$MARKER" ] && exit 0
command -v xrandr >/dev/null 2>&1 || exit 0
command -v xfconf-query >/dev/null 2>&1 || exit 0
[ -f "$WALLPAPER" ] || exit 0

mkdir -p "$(dirname "$MARKER")"
for output in $(xrandr --current | awk '/ connected/ {print $1}'); do
  prop="/backdrop/screen0/monitor${output}/workspace0/last-image"
  if xfconf-query -c xfce4-desktop -p "$prop" >/dev/null 2>&1; then
    xfconf-query -c xfce4-desktop -p "$prop" -s "$WALLPAPER"
  else
    xfconf-query -c xfce4-desktop -n -t string -p "$prop" -s "$WALLPAPER"
  fi
done
touch "$MARKER"