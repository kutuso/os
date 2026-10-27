#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
BIN=packages/kutu-memory/usr/bin/kutu-memory-early
mkdir -p "$tmp/sys/module/zswap/parameters" "$tmp/sys/kernel/mm/lru_gen" "$tmp/bin"
printf 'Y' > "$tmp/sys/module/zswap/parameters/enabled"
: > "$tmp/sys/kernel/mm/lru_gen/enabled"
: > "$tmp/sys/kernel/mm/lru_gen/min_ttl_ms"
printf 'MemTotal: 4194304 kB\n' > "$tmp/meminfo"
for c in modprobe mkswap swapon; do
  printf '#!/bin/sh\necho "%s $*" >> "%s/calls"\n' "$c" "$tmp" > "$tmp/bin/$c"
  chmod +x "$tmp/bin/$c"
done
printf '#!/bin/sh\necho "zramctl $*" >> "%s/calls"\necho /dev/zram0\n' "$tmp" > "$tmp/bin/zramctl"
chmod +x "$tmp/bin/zramctl"
run() { PATH="$tmp/bin:$PATH" KUTU_SYSFS="$tmp/sys" KUTU_MEMINFO="$tmp/meminfo" KUTU_SWAPS="$tmp/swaps" "$BIN" >/dev/null; }

printf 'Filename\tType\tSize\tUsed\tPriority\n' > "$tmp/swaps"
: > "$tmp/calls"
run
grep -q 'zramctl --find --algorithm zstd --size 4194304K' "$tmp/calls" || { echo "FAIL: zram not created without swap"; cat "$tmp/calls"; exit 1; }
grep -q 'swapon --priority 100 /dev/zram0' "$tmp/calls" || { echo "FAIL: zram not enabled"; exit 1; }
[ "$(cat "$tmp/sys/module/zswap/parameters/enabled")" = N ] || { echo "FAIL: zswap left on beside zram"; exit 1; }
[ "$(cat "$tmp/sys/kernel/mm/lru_gen/enabled")" = 0x0007 ] || { echo "FAIL: mglru"; exit 1; }

printf 'Y' > "$tmp/sys/module/zswap/parameters/enabled"
printf '/dev/vda2\tpartition\t1024\t0\t-2\n' >> "$tmp/swaps"
: > "$tmp/calls"
run
! grep -q zramctl "$tmp/calls" || { echo "FAIL: zram created despite existing swap"; exit 1; }
[ "$(cat "$tmp/sys/module/zswap/parameters/enabled")" = Y ] || { echo "FAIL: zswap disabled with disk swap"; exit 1; }
echo "kutu-memory-early test: PASS"
