# Building kutu OS

Everything builds inside docker; your host is never touched. You need:

- docker (with permission to run containers)
- ~10 GB free disk
- for `make test-vm` / interactive testing: QEMU locally (KVM optional)

## Targets

```sh
make test      # shellcheck + unit tests + package builds (docker)
make build     # full ISO -> out/kutu-os-<date>-x86_64.iso (docker, privileged)
make smoke     # automated boot + memory-stack assertions in QEMU (docker)
make test-vm   # interactive QEMU boot of the latest ISO (needs local qemu)
make packages  # build just the packages into work/repo
make clean     # remove work/ (docker, no sudo needed)
```

`make test-vm` honors environment overrides: `KUTU_VM_RAM` (MiB),
`KUTU_VM_XRES`/`KUTU_VM_YRES` (display size), `KUTU_VM_DISK` (path to a
scratch disk image — created sparse if missing; Calamares needs a disk to
install to), `KUTU_VM_VNC=1` (serve VNC on 127.0.0.1:5900 instead of a
local window, for headless hosts — tunnel with `ssh -L 5900:localhost:5900`),
and `KUTU_VM_BOOT=disk` (boot the installed disk instead of the ISO, to
verify an install).

## How the build works

1. `scripts/build-packages.sh` builds every `packages/*/` PKGBUILD inside an
   `archlinux:base-devel` container (makepkg as a build user, deps resolved
   against official repos; our own packages resolve against each other in
   alphabetical order) and collects them into `work/repo/` with `repo-add`.
2. `scripts/build.sh` copies the `archiso/` profile, points its pacman.conf
   at the local repo, and runs `mkarchiso` in a **privileged** container
   (pacstrap must mount proc/sys/dev into the build chroot).
3. The ISO boots via BIOS (syslinux) and UEFI (systemd-boot); the live
   session autologs into XFCE; "Install kutu OS" runs Calamares offline.

First run takes 30–90 minutes (package downloads, calamares compile,
squashfs compression at zstd-19). Subsequent runs reuse the
`kutu-pacman-cache` docker volume and cached package builds (remove a
package's `*.pkg.tar.zst` or set `KUTU_FORCE_BUILD=1` to force a rebuild).

## Building on an Arch host without docker

Set `KUTU_IN_DOCKER=1` and run the scripts directly on a real Arch system
with `archiso`, `expect`, and `qemu-system-x86_64` installed. Not
recommended: the docker path is the canonical, reproducible one.

## Notes

- `work/` and `out/` are root-owned after builds (docker); `make clean`
  removes them via docker so you never need sudo.
- The pacman cache volume also serves the test suite — the scripts purge
  kutu/calamares packages from it to avoid same-version checksum collisions.
- ISO must stay under 2 GiB (GitHub release asset limit); currently ~1.7 GiB.
