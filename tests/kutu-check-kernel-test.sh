#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

SCRIPT="packages/kutu-base/usr/bin/kutu-check-kernel"
[ -f "$SCRIPT" ] || { echo "FAIL: $SCRIPT missing"; exit 1; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

make_fixture() {
  rm -rf "$tmp/sys" "$tmp/proc"
  mkdir -p "$tmp/sys/module/zswap/parameters" "$tmp/sys/kernel/mm/lru_gen" \
    "$tmp/sys/kernel/mm/damon/admin" "$tmp/sys/kernel/mm/transparent_hugepage" \
    "$tmp/sys/fs/cgroup/system.slice" "$tmp/proc/pressure"
  printf Y > "$tmp/sys/module/zswap/parameters/enabled"
  printf zstd > "$tmp/sys/module/zswap/parameters/compressor"
  printf Y > "$tmp/sys/module/zswap/parameters/shrinker_enabled"
  printf 35 > "$tmp/sys/module/zswap/parameters/max_pool_percent"
  printf 0x0007 > "$tmp/sys/kernel/mm/lru_gen/enabled"
  printf 1000 > "$tmp/sys/kernel/mm/lru_gen/min_ttl_ms"
  touch "$tmp/proc/pressure/memory" "$tmp/sys/fs/cgroup/system.slice/memory.zswap.max"
  printf 'always madvise [madvise] never' > "$tmp/sys/kernel/mm/transparent_hugepage/enabled"
}

run_ck() { KUTU_SYSFS="$tmp/sys" KUTU_PROC="$tmp/proc" "$SCRIPT" >/dev/null 2>&1; }

make_fixture
run_ck || { echo "FAIL: all-good fixture should pass"; exit 1; }

printf 20 > "$tmp/sys/module/zswap/parameters/max_pool_percent"
run_ck && { echo "FAIL: wrong max_pool_percent should fail"; exit 1; } || true
printf 35 > "$tmp/sys/module/zswap/parameters/max_pool_percent"

printf 0 > "$tmp/sys/kernel/mm/lru_gen/min_ttl_ms"
run_ck && { echo "FAIL: wrong min_ttl_ms should fail"; exit 1; } || true
printf 1000 > "$tmp/sys/kernel/mm/lru_gen/min_ttl_ms"

printf N > "$tmp/sys/module/zswap/parameters/enabled"
run_ck && { echo "FAIL: disabled zswap should fail"; exit 1; } || true

make_fixture
run_ck || { echo "FAIL: fixture restore should pass"; exit 1; }

echo "kutu-check-kernel tests: PASS"
