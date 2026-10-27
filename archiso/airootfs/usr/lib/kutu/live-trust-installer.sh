#!/usr/bin/env bash
set -euo pipefail
f="$HOME/Desktop/install-kutu-os.desktop"
[ -f "$f" ] || exit 0
sum=$(sha256sum "$f" | cut -d' ' -f1)
gio set -t string "$f" metadata::xfce-exe-checksum "$sum"
gio set "$f" metadata::trusted true
