#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
printf 'MemTotal: 4194304 kB\n' > "$tmp/meminfo"
KUTU_ROOT="$tmp/root" KUTU_MEMINFO="$tmp/meminfo" packages/kutu-base/usr/bin/kutu-firstboot
grep -q '^MODE=saver$' "$tmp/root/etc/kutu/memory.conf"
grep -q 'MemoryHigh=3650722201' "$tmp/root/etc/systemd/system/user.slice.d/50-kutu.conf"
grep -q '^KUTU_MEMORY_HIGH_PCT=40$' "$tmp/root/etc/kutu/apps.d/firefox.conf"
KUTU_ROOT="$tmp/root" KUTU_MEMINFO="$tmp/meminfo" packages/kutu-base/usr/bin/kutu-firstboot
grep -q '^MODE=saver$' "$tmp/root/etc/kutu/memory.conf"
printf 'MemTotal: 16777216 kB\n' > "$tmp/meminfo"
KUTU_ROOT="$tmp/root2" KUTU_MEMINFO="$tmp/meminfo" packages/kutu-base/usr/bin/kutu-firstboot
grep -q '^MODE=balanced$' "$tmp/root2/etc/kutu/memory.conf"
grep -q 'MemoryHigh=15461882265' "$tmp/root2/etc/systemd/system/user.slice.d/50-kutu.conf"
grep -q '^KUTU_MEMORY_HIGH_PCT=50$' "$tmp/root2/etc/kutu/apps.d/firefox.conf"
printf 'MemTotal: 67108864 kB\n' > "$tmp/meminfo"
KUTU_ROOT="$tmp/root3" KUTU_MEMINFO="$tmp/meminfo" packages/kutu-base/usr/bin/kutu-firstboot
grep -q '^MODE=performance$' "$tmp/root3/etc/kutu/memory.conf"
grep -q '^KUTU_MEMORY_HIGH_PCT=70$' "$tmp/root3/etc/kutu/apps.d/firefox.conf"
echo "kutu-firstboot tests: PASS"
