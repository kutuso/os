#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
R="$tmp/admin"
K="kdamonds/0"; C="$K/contexts/0"; S="$C/schemes/0"
mkdir -p "$R/$C/monitoring_attrs/intervals" "$R/$C/targets/0/regions/"{0,1,2,3,4,5,6,7} \
  "$R/$S/access_pattern/nr_accesses" "$R/$S/access_pattern/age" "$R/$S/quotas" "$R/$S/watermarks"
for f in nr_kdamonds "$K/state" "$K/contexts/nr_contexts" "$C/operations" \
  "$C/monitoring_attrs/intervals/sample_us" "$C/monitoring_attrs/intervals/aggr_us" \
  "$C/monitoring_attrs/intervals/update_us" "$C/targets/nr_targets" "$C/targets/0/nr_regions" \
  "$C/targets/0/regions/0/start" "$C/targets/0/regions/0/end" \
  "$C/schemes/nr_schemes" "$S/action" "$S/access_pattern/nr_accesses/min" \
  "$S/access_pattern/nr_accesses/max" "$S/access_pattern/age/min" "$S/access_pattern/age/max" \
  "$S/quotas/ms" "$S/quotas/bytes" "$S/quotas/reset_interval_ms" "$S/watermarks/metric" \
  "$S/watermarks/interval_us" "$S/watermarks/low" "$S/watermarks/mid" "$S/watermarks/high"; do
  : > "$R/$f"
done
export KUTU_DAMON_SYSFS="$R"
BIN=packages/kutu-memory/usr/bin/kutu-damon
assert() { [ "$(cat "$R/$1")" = "$2" ] || { echo "FAIL: $1='$(cat "$R/$1")' want '$2'"; exit 1; }; }

printf 'MemTotal: 16777216 kB\n' > "$tmp/meminfo"
KUTU_MEMINFO="$tmp/meminfo" KUTU_IOMEM="$tmp/nonexistent" "$BIN" start
assert "$C/operations" paddr
assert "$C/monitoring_attrs/intervals/sample_us" 5000
assert "$C/monitoring_attrs/intervals/aggr_us" 100000
assert "$C/targets/nr_targets" 1
assert "$C/targets/0/nr_regions" 1
assert "$C/targets/0/regions/0/start" 0
assert "$C/targets/0/regions/0/end" 17179869184
assert "$S/action" pageout
assert "$S/access_pattern/nr_accesses/min" 0
assert "$S/access_pattern/nr_accesses/max" 0
assert "$S/access_pattern/age/min" 100
assert "$S/quotas/ms" 100
assert "$S/quotas/bytes" 0
assert "$S/watermarks/metric" free_mem_rate
assert "$S/watermarks/low" 50
assert "$S/watermarks/mid" 100
assert "$S/watermarks/high" 150
assert "$K/state" on
"$BIN" status | grep -q on
"$BIN" stop
assert "$K/state" off

printf '00000000-0009fbff : System RAM\n00100000-3fffffff : System RAM\n' > "$tmp/iomem"
KUTU_MEMINFO="$tmp/meminfo" KUTU_IOMEM="$tmp/iomem" "$BIN" start
assert "$C/targets/0/nr_regions" 2
assert "$C/targets/0/regions/0/end" 654336
assert "$C/targets/0/regions/1/start" 1048576
"$BIN" stop
echo "kutu-damon tests: PASS"
