# M1 development notes — read before touching this repo again

Written 2026-08-29, immediately after M1 shipped (v0.1.0, smoke ALL PASS).
For rules and commands see `CLAUDE.md`; this file is the WHY and the
scars. Read alongside the spec and the M1 plan.

## Environment facts

- Dev host: **Manjaro** (not Arch) — that's why everything runs in
  `archlinux:base-devel` docker. `KUTU_IN_DOCKER=1` skips the docker
  wrapper when already inside a container.
- The repo lives on an ext4 mount; bind mounts into docker work fine.
- KVM is available locally (`--device /dev/kvm`) — smoke takes ~3 min
  locally, ~30+ min in CI (TCG).
- The pacman cache docker volume (`kutu-pacman-cache`) is shared between
  test and build runs; `build-packages.sh` purges our own packages from it
  because same-version rebuilds otherwise collide (see below).

## War stories (each of these cost a debug cycle — don't relearn them)

1. **pacman scriptlet `$1` is the package VERSION, not a root.** Scriptlets
   already run chrooted; use plain `systemctl enable` and `/etc/...` paths.
   `systemctl --root="$1"` silently no-ops (it enables inside a directory
   literally named `0.1.0-1`).
2. **Stale package caches lie.** If you edit a package and forget to bump
   `pkgrel` (and delete the old `*.pkg.tar.zst`), docker-layer/ISO pacstrap
   validates the OLD cached file against the NEW repo db and fails with
   "invalid or corrupted package (checksum)". It looks transient; it
   isn't. `build-packages.sh` purges kutu/calamares packages from the
   pacman cache volume for this reason.
3. **`zswap.zpool=` stopped existing.** Kernels ≥6.10 removed the param —
   zsmalloc is baked in (`CONFIG_ZSWAP_ZPOOL_DEFAULT_ZSMALLOC=y` on Arch).
   The runtime fallback in `kutu-memory-early` handles pre-6.10 only.
   Never add it back to the cmdline.
4. **DAMON sysfs layout:** `/sys/kernel/mm/damon/admin/kdamonds/nr_kdamonds`
   (one level deeper than instinct), and `targets/0/regions/nr_regions`
   (regions dir!). Writing a nonexistent sysfs path yields **EACCES**
   ("Permission denied"), not ENOENT — sysfs dirs aren't creatable. When
   a sysfs write fails with EACCES, suspect the path first.
5. **Arch lightdm PAM autologin requires the `autologin` group.** Without
   it the live session autologin dies with "conversation failed" and you
   get a greeter instead of a desktop. Calamares handles this on the
   installed system (`autologinGroup` in users.conf); `customize_airootfs`
   handles it for the live user.
6. **syslinux two-stage boot needs both timeouts.** `whichsys` needs
   `-iso-` mapped AND the second-stage `archiso_sys.cfg` menu needs its own
   `TIMEOUT` — otherwise headless QEMU boots sit at the menu forever.
7. **mkarchiso ordering:** airootfs overlay is copied BEFORE packages
   install — that's why the mkinitcpio archiso preset/HOOKS in
   `airootfs/etc/mkinitcpio.d/*.preset` + `mkinitcpio.conf.d/archiso.conf`
   work (the `linux` package builds its initramfs with them during
   pacstrap). Without this the ISO boots to emergency mode ("Failed to
   start Switch Root").
8. **mkarchiso in docker needs `--privileged`** — pacstrap mounts
   proc/sys/dev into the build chroot. Plain containers get
   "mount: permission denied" mid-build.
9. **`xfce4` is a package GROUP** — makepkg `depends` can't resolve groups;
   list members explicitly. And `xfce4-settings` owns the system
   `xsettings.xml` — override configs in `/etc/skel/.config/` instead
   (skel applies to every new user; zero file conflicts).
10. **`qemu-headless` no longer exists** — use `qemu-system-x86` +
    `qemu-system-x86-firmware`.
11. **Serial logs are polluted by OSC/kitty-style shell-integration
    sequences** (`]3008;...`) interleaved with output — smoke assertions
    grep for exact markers and must never count matches loosely (one count
    check burned us; we assert per-item markers now).
12. **`/etc/os-release` is owned by the `filesystem` package** — kutu-base
    ships it at `/usr/lib/kutu/os-release` and symlinks it in post_install.

## Known gaps / deliberate deviations (all documented in the spec or here)

- **Repo unsigned** (`SigLevel = Never`) — the one open TODO before v1.0;
  full key-rotation playbook in `MAINTAINERS.md` and `docs/RELEASE.md`.
- **Swap default = RAM-sized** (`initialSwapChoice: suspend`) instead of
  spec §7's min(RAM,16GiB) — Calamares canned choices + laptop hibernation
  value; amend the spec at M2 if this stands.
- **linux-lts dropped from the ISO** to fit the 2 GiB GitHub asset limit
  (1.71 GiB at zstd-19). If LTS returns, it returns as a separate flavor.
- **Installed-system install test is manual** (checklist in
  docs/RELEASE.md). Automating an expect-driven Calamares run in QEMU is
  the natural next CI job — nontrivial (GUI automation), not started.
- **Repo retention on gh-pages is keep-all** — prune to 3 versions/package
  when it passes ~500 MB (MAINTAINERS.md).
- **Docs site is docsify** (client-side rendered markdown from `site/` +
  `docs/` copied by `release.yml`) — zero build step, no jekyll.

## M2/M3 starting points

- M2 = spec §8 (`kutu-memoryd` modes + control loop) + `kutu-doctor`.
  The mode thresholds are LOCKED (spec §6–§7); `kutu-firstboot` already
  writes `MODE=` into `/etc/kutu/memory.conf` and the per-app
  `apps.d/firefox.conf` — memoryd consumes those, don't fork new config.
  PSI triggers: `open("/proc/pressure/memory")` + `poll()` with
  "some <threshold_us> <window_us>" writes (kernel PSI trigger API).
  systemd owns cgroups — adjust with `systemctl set-property --runtime`,
  never raw cgroupfs writes.
- M3 = spec §9 (`mempressured` D-Bus service + C lib). Standalone daemons
  (no memoryd dependency) — the freedesktop pitch requires it.
- The per-app resource-manager GUI lives in the SIBLING repo
  `../resources` (idea doc there); kutu OS ships it as a package later.
- Rust toolchain for M2/M3 packages: add `rust` to makedepends in those
  PKGBUILDs; CI containers build fine (cargo in base-devel? no — add rust
  to the container install list in `scripts/test.sh` when M2 lands).

## Smoke-test mechanics (you will extend it)

`scripts/smoke-test.sh` boots the ISO in QEMU (KVM passthrough locally),
drives the serial root shell with expect, emits `SMOKE:<name>:<value>`
markers, then greps the persistent log at `work/smoke.log`. Rules that
kept it reliable: assert exact markers (never count loosely), remember the
OSC-sequence pollution, quote expect `send` bodies in braces (TCL eats
`$`), and always finish with `poweroff` + `expect eof`.