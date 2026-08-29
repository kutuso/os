#!/usr/bin/env bash
# kutu OS test runner. NEVER touches the host system:
# all linting, unit tests, and package builds run inside a disposable
# archlinux:base-devel container; integration tests run in QEMU (smoke-test.sh).
set -euo pipefail
cd "$(dirname "$0")/.."

if [ "${KUTU_IN_DOCKER:-0}" != 1 ]; then
  command -v docker >/dev/null 2>&1 || { echo "docker required for testing (or set KUTU_IN_DOCKER=1 inside an arch container)"; exit 1; }
  exec docker run --rm -v "$PWD:/w" -v kutu-pacman-cache:/var/cache/pacman/pkg \
    -w /w -e KUTU_IN_DOCKER=1 archlinux:base-devel bash scripts/test.sh
fi

echo "== kutu OS test suite (in-container) =="
pacman -Sy --noconfirm --needed shellcheck || { pacman -Syy --noconfirm archlinux-keyring && pacman -Sy --noconfirm --needed shellcheck; }

echo "-- shellcheck"
mapfile -t scripts < <(find packages \( -path '*/pkg' -o -path '*/src' \) -prune -o \
  \( -path '*/usr/bin/*' -o -path '*/usr/lib/*' \) -type f -print; find scripts -name '*.sh')
shellcheck "${scripts[@]}"

echo "-- config validation"
./scripts/validate-configs.sh

echo "-- package builds"
./scripts/build-packages.sh

echo "-- unit tests"
for t in tests/*-test.sh; do
  echo "   $t"
  "$t"
done

echo "== ALL TESTS PASS =="
