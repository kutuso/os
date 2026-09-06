#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

SCAN="${KUTU_VALIDATE_DIR:-packages}"
fail=0

KNOWN_SYSCTL="swappiness page-cluster watermark_scale_factor watermark_boost_factor dirty_background_ratio dirty_ratio min_free_kbytes compaction_proactiveness vfs_cache_pressure"
while IFS= read -r file; do
  while IFS= read -r key; do
    [ "${key#vm.}" = "$key" ] && { echo "FAIL: non-vm key '$key' in $file"; fail=1; continue; }
    base="${key#vm.}"
    grep -qw "$base" <<< "$KNOWN_SYSCTL" || { echo "FAIL: unknown key '$key' in $file"; fail=1; }
  done < <(grep -E '^[A-Za-z0-9._]+[[:space:]]*=' "$file" | cut -d= -f1 | tr -d ' ')
done < <(find "$SCAN" \( -path '*/pkg' -o -path '*/src' \) -prune -o -path '*/sysctl/*' -name '*.conf' -print)

check_oomd_keys() {
  local file="$1" allowed="$2"
  while IFS= read -r key; do
    [ -n "$key" ] || continue
    grep -qw "$key" <<< "$allowed" || { echo "FAIL: invalid oomd/systemd key '$key' in $file"; fail=1; }
  done < <(grep -E '^[A-Za-z0-9._]+[[:space:]]*=' "$file" | cut -d= -f1 | tr -d ' ')
}

OOMD_MAIN_KEYS="SwapUsedLimit DefaultMemoryPressureLimit DefaultMemoryPressureDurationSec"
OOMD_UNIT_KEYS="ManagedOOMSwap ManagedOOMMemoryPressure ManagedOOMMemoryPressureLimit ManagedOOMMemoryPressureDurationSec ManagedOOMPreference MemoryHigh MemoryMax MemorySwapMax CPUWeight"
while IFS= read -r file; do
  check_oomd_keys "$file" "$OOMD_MAIN_KEYS"
done < <(find "$SCAN" \( -path '*/pkg' -o -path '*/src' \) -prune -o -path '*oomd.conf.d*' -name '*.conf' -print)
while IFS= read -r file; do
  check_oomd_keys "$file" "$OOMD_UNIT_KEYS"
done < <(find "$SCAN" \( -path '*/pkg' -o -path '*/src' \) -prune -o -path '*.service.d*' -name '*.conf' -print)

while IFS= read -r unit; do
  out=$(systemd-analyze verify --man=no "$unit" 2>&1 | grep -Ev 'Failed to lookup|is not executable' || true)
  if [ -n "$out" ]; then
    echo "FAIL: systemd verify on $unit:"
    echo "$out"
    fail=1
  fi
done < <(find "$SCAN" \( -path '*/pkg' -o -path '*/src' \) -prune -o -name '*.service' -print)

mapfile -t scripts < <(find "$SCAN" \( -path '*/pkg' -o -path '*/src' \) -prune -o \( -path '*/usr/bin/*' -o -path '*/usr/lib/*' \) -type f -print; find scripts -name '*.sh')
shellcheck "${scripts[@]}"

if command -v python3 >/dev/null 2>&1 && python3 -c 'import yaml' 2>/dev/null; then
  while IFS= read -r y; do
    python3 -c 'import sys, yaml; yaml.safe_load(open(sys.argv[1]))' "$y" \
      || { echo "FAIL: invalid YAML: $y"; fail=1; }
  done < <(find packages/kutu-calamares-config \( -path '*/pkg' -o -path '*/src' \) -prune -o \( -name '*.conf' -o -name '*.desc' \) -print)
fi

if [ "$fail" != 0 ]; then
  echo "validate-configs: FAILED"
  exit 1
fi
echo "validate-configs: OK"
