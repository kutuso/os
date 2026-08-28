#!/usr/bin/env bash
# Build the kutu OS ISO. Runs inside docker by default; nothing touches the host.
set -euo pipefail
cd "$(dirname "$0")/.."

if [ "${KUTU_IN_DOCKER:-0}" != 1 ]; then
  command -v docker >/dev/null 2>&1 || { echo "docker required (or set KUTU_IN_DOCKER=1 inside an arch container)"; exit 1; }
  exec docker run --rm -v "$PWD:/w" -v kutu-pacman-cache:/var/cache/pacman/pkg \
    -w /w -e KUTU_IN_DOCKER=1 archlinux:base-devel bash scripts/build.sh
fi

VERSION="$(date +%Y.%m.%d)"
mkdir -p out

./scripts/build-packages.sh

PROFILE_TMP="work/profile"
rm -rf "$PROFILE_TMP"
cp -r archiso "$PROFILE_TMP"
sed -i "s|file://KUTU_REPO_PLACEHOLDER|file://$PWD/work/repo|" "$PROFILE_TMP/pacman.conf"

pacman -Sy --noconfirm --needed archiso >/dev/null 2>&1
mkarchiso -v -w work/chroot -o out "$PROFILE_TMP"

ISO="out/kutu-os-$VERSION-x86_64.iso"
echo "built: $ISO"
( cd out && sha256sum "kutu-os-$VERSION-x86_64.iso" > "kutu-os-$VERSION-x86_64.iso.sha256" )
ls -lh "$ISO"
