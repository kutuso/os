#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/etc/kutu/apps.d"
cat > "$tmp/etc/kutu/apps.d/testapp.conf" <<'EOF'
KUTU_MEMORY_HIGH_PCT=50
KUTU_CPU_WEIGHT=80
KUTU_MEMORY_MERGE=1
EOF
printf 'MemTotal: 4194304 kB\n' > "$tmp/meminfo"
run() { KUTU_ROOT="$tmp" KUTU_MEMINFO="$tmp/meminfo" \
  packages/kutu-base/usr/bin/kutu-run --dry-run "$@"; }
out=$(run testapp /usr/bin/sleep 10)
grep -q 'MemoryHigh=2147483648' <<< "$out"
grep -q 'CPUWeight=80' <<< "$out"
grep -q 'MemoryMerge=yes' <<< "$out"
grep -q -- '--expand-environment=no' <<< "$out"
grep -Eq -- '--unit=app-testapp-[0-9]+-[0-9]+' <<< "$out"
out2=$(run testapp /usr/bin/sleep 10)
[ "$out" != "$out2" ] || { echo "FAIL: scope unit names are not unique"; exit 1; }
out=$(KUTU_ROOT="$tmp" packages/kutu-base/usr/bin/kutu-run --dry-run nosuchapp /bin/true)
if grep -q 'MemoryHigh' <<< "$out"; then echo "FAIL: unprofiled app got limits"; exit 1; fi
packages/kutu-base/usr/bin/kutu-run --dry-run 2>/dev/null && { echo "FAIL: bad usage accepted"; exit 1; } || true
echo "kutu-run tests: PASS"
