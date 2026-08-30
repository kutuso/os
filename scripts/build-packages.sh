#!/usr/bin/env bash
# Build all kutu-* packages into work/repo (a pacman repo).
# Runs inside docker by default; nothing touches the host.
set -euo pipefail
cd "$(dirname "$0")/.."

if [ "${KUTU_IN_DOCKER:-0}" != 1 ]; then
  command -v docker >/dev/null 2>&1 || { echo "docker required (or set KUTU_IN_DOCKER=1 inside an arch container)"; exit 1; }
  exec docker run --rm -v "$PWD:/w" -v kutu-pacman-cache:/var/cache/pacman/pkg \
    -w /w -e KUTU_IN_DOCKER=1 archlinux:base-devel bash scripts/build-packages.sh
fi

REPO_DIR="work/repo"
mkdir -p "$REPO_DIR"
rm -f "$REPO_DIR"/kutu.db*
# never let our own packages linger in the shared pacman cache: same-name
# rebuilds would collide with stale copies and fail checksum validation
rm -f /var/cache/pacman/pkg/kutu-*.pkg.tar.zst /var/cache/pacman/pkg/calamares-*.pkg.tar.zst
pacman -Sy --noconfirm >/dev/null 2>&1 || true
if ! id builduser >/dev/null 2>&1; then useradd -m builduser; fi

for pkg in packages/*/; do
  name=$(basename "$pkg")
  chown -R builduser "$pkg"
  # install deps (official repos only; our own packages satisfy each other
  # via pacman -U below, alphabetical build order)
  # shellcheck disable=SC1091
  ver=$( (cd "$pkg" && source PKGBUILD && echo "${pkgver:?}-${pkgrel:?}") )
  # shellcheck disable=SC1091
  (cd "$pkg" && source PKGBUILD && \
    mapfile -t deps < <(printf '%s\n' "${depends[@]:-}" "${makedepends[@]:-}" | grep -v '^$') && \
    for d in "${deps[@]:-}"; do pacman -S --needed --noconfirm --asdeps "$d" >/dev/null 2>&1 || true; done)
  if [ "${KUTU_FORCE_BUILD:-0}" != 1 ] && compgen -G "${pkg}${name}-${ver}-"*.pkg.tar.zst >/dev/null; then
    echo "   $name: cached ($ver)"
  else
    rm -f "$pkg${name}-"*.pkg.tar.zst
    echo "   building $name ($ver)"
    (cd "$pkg" && runuser -u builduser -- makepkg -f --noconfirm >/dev/null)
  fi
  rm -f "$REPO_DIR/${name}-"*.pkg.tar.zst
  pacman -U --noconfirm "$pkg${name}-"*.pkg.tar.zst >/dev/null
  cp "$pkg${name}-"*.pkg.tar.zst "$REPO_DIR/"
done

(cd "$REPO_DIR" && repo-add -R kutu.db.tar.zst ./*.pkg.tar.zst >/dev/null)
set -- "$REPO_DIR"/*.pkg.tar.zst
echo "repo ready: $REPO_DIR ($# packages)"
