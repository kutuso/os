#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/sysctl" "$tmp/oomd.conf.d"
printf 'vm.swappiness = 100\nvm.bogus_knob = 1\nkernel.bogus = 2\n' > "$tmp/sysctl/bad.conf"
printf '[OOM]\nDefaultMemoryPressureLimitSec=30s\n' > "$tmp/oomd.conf.d/bad.conf"

out=$(KUTU_VALIDATE_DIR="$tmp" ./scripts/validate-configs.sh 2>&1) && {
  echo "FAIL: validate-configs accepted invalid input"; exit 1;
} || true
grep -q "unknown key 'vm.bogus_knob'" <<< "$out" || { echo "FAIL: unknown sysctl key not reported"; exit 1; }
grep -q "non-vm key 'kernel.bogus'" <<< "$out" || { echo "FAIL: non-vm key not reported"; exit 1; }
grep -q "DefaultMemoryPressureLimitSec" <<< "$out" || { echo "FAIL: invalid oomd key not reported"; exit 1; }

echo "validate-configs tests: PASS"
