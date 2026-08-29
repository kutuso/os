#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

KNOWN="swappiness page-cluster watermark_scale_factor watermark_boost_factor dirty_background_ratio dirty_ratio min_free_kbytes compaction_proactiveness vfs_cache_pressure"

while IFS= read -r file; do
  grep -E '^[a-z.]+\s*=' "$file" | cut -d= -f1 | tr -d ' ' | while IFS= read -r key; do
    [ "${key#vm.}" = "$key" ] && { echo "FAIL: non-vm key '$key' in $file"; continue; }
    base="${key#vm.}"
    grep -qw "$base" <<< "$KNOWN" || echo "FAIL: unknown key '$key' in $file"
  done
done < <(find packages \( -path '*/pkg' -o -path '*/src' \) -prune -o -path '*/sysctl/*' -name '*.conf' -print)

while IFS= read -r unit; do
  systemd-analyze verify --man=no "$unit" 2>&1 | grep -Ev 'Failed to lookup|is not executable' || true
done < <(find packages \( -path '*/pkg' -o -path '*/src' \) -prune -o -name '*.service' -print)

mapfile -t scripts < <(find packages \( -path '*/pkg' -o -path '*/src' \) -prune -o \( -path '*/usr/bin/*' -o -path '*/usr/lib/*' \) -type f -print; find scripts -name '*.sh')
shellcheck "${scripts[@]}"
echo "validate-configs: OK"
