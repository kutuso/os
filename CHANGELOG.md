# Changelog

All notable changes to kutu OS. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions follow
the repo's `vX.Y.Z` tags. The ISO for each tag is attached to the matching
[GitHub release](https://github.com/kutuso/os/releases); installed systems
move between versions with plain `pacman -Syu`.

## Unreleased

Audit-driven hardening pass over M1. The full review behind these changes
covered installer bootability, the update channel, the memory stack's
effective behavior, build/CI verification, and supply-chain posture.

### Fixed

**Installed-system bootability (critical)**

- Installed systems could fail to boot: the installer hand-wrote a
  mkinitcpio `HOOKS=` list that omitted `block`, `filesystems`, `encrypt`,
  `lvm2`, `resume` and `microcode`. The hook set is now derived from the
  actual partition layout by Calamares `initcpiocfg` and built by
  `initcpio` in the target; `amd-ucode`/`intel-ucode` are shipped so the
  microcode hook has blobs to embed.
- Installed systems received no `[kutu]` pacman repository section (the
  old finalizer rewrote a `file://` line that did not exist in the target
  and suppressed its own failure, and pointed at a nonexistent
  `kutu-so.github.io` host). The finalizer now writes the section with the
  canonical `kutuso.github.io` URL and asserts it exists exactly once.
- Post-install security cleanup was failure-suppressed (`-` command
  prefixes) and unasserted; every cleanup command is now mandatory and the
  installer aborts unless root autologin, passwordless wheel sudo, the
  live `kutu` user, live SSH host keys, an enabled sshd, the live
  firstboot marker and the missing initramfs are all confirmed gone/present.
- Live-session firstboot state (marker, generated ceilings, firefox
  profile) is stripped from the target so the installed system
  recalibrates on its own hardware.
- The Calamares installer launcher is removed from the installed system.

**Memory stack**

- oomd policy was inert: `ManagedOOMMemoryPressureLimitSec` and
  `DefaultMemoryPressureLimitSec` are not valid systemd properties
  (silently ignored). Corrected to
  `ManagedOOMMemoryPressureLimit=50%`/`DefaultMemoryPressureDurationSec=30s`;
  pressure monitoring moved from `user.slice` to the root-owned
  `user@.service` so preferences are honored, and the pipewire/
  wireplumber/portal avoid-drop-ins moved from the system to the user
  manager search path where those units actually live.
- `kutu-run` scope names collided (`app-<profile>-%n` is not unique), so
  a second firefox launch — URL handler, new window, private window —
  could fail against the existing scope. Scope names are now unique and
  environment expansion is disabled so literal arguments are preserved.
- Firefox desktop wrapping only matched `Exec=firefox` while current Arch
  ships `Exec=/usr/lib/firefox/firefox`, so firefox silently bypassed its
  `MemoryHigh` ceiling. Both forms are wrapped and the alpm hook now
  fails if a present firefox desktop file yields no wrapped actions.
- `kutu-reset` claimed to restore stock but left oomd, journald, I/O
  scheduler rules and generated ceilings active, and disabled MGLRU
  entirely (stock Arch has it on). It now restores stock values for all
  of those, kernel zswap/MGLRU defaults included.
- `kutu-check-kernel` did not verify the locked zswap pool cap (35%) or
  MGLRU min TTL (1000 ms); it does, the smoke test asserts both, and a
  unit test proves wrong values fail.
- `kutu-firstboot` was ordered after `multi-user.target` (racing the
  display manager into the session) and never ran the kernel prober; it
  now runs before the session and journals `kutu-check-kernel` results.
- The installed GRUB cmdline carried `zswap.zpool=zsmalloc`, a parameter
  removed in kernels ≥ 6.10 (the pre-6.10 runtime fallback in
  `kutu-memory-early` remains).
- Package lifecycle: GRUB config regenerates on `kutu-memory`
  install/upgrade/remove; services stop before removal; the calibrated
  `/etc/kutu/memory.conf` is a pacman backup file so upgrades cannot
  revert the mode.

**Build and verification**

- `validate-configs.sh` printed OK while ignoring every failure — it
  also silently skipped sysctl keys containing underscores (its key regex
  predated this fix and never matched e.g. `vm.watermark_scale_factor`).
  It now exits nonzero on unknown sysctl keys, invalid oomd/unit
  properties, systemd verify errors, or unparseable Calamares YAML, and
  a negative unit test proves invalid input fails.
- Package builds suppressed repository sync and dependency-install
  failures, and `chown -R`ed the bind-mounted sources to a container uid.
  Dependency failures are now fatal (own packages excluded) and
  `builduser` is mapped onto the source owner so host ownership never
  changes.
- Release tags did not run the lint/unit/package suite; the release
  workflow now runs `scripts/test.sh` before building.
- Smoke test: dropped debug writes to obsolete/duplicate sysfs paths;
  added the zswap pool-cap assertion.
- Release ISO naming could diverge from the profile's version at
  midnight or with `SOURCE_DATE_EPOCH`; the version is tag-derived via
  `KUTU_ISO_VERSION` and mismatched filenames now fail the build.

### Security

- Repo publication was structurally broken: package files and
  `kutu.db.tar.zst` matched `.gitignore` patterns (the database could be
  committed while its packages were not), the push and Pages trigger
  failures were swallowed, and the GitHub release was created before
  anything was reachable. Publication artifacts are force-added, failures
  are fatal, and the workflow polls the published db and verifies every
  package over HTTPS before announcing the release.
- The vendored Debian `console-setup` source (which supplies the
  root-executed `ckbcomp` installer binary) shipped with `SKIP` checksum
  verification; pinned to the verified SHA-256, and `perl` is now a
  declared dependency.
- Installer: autologin defaults off and a non-empty 8+ character
  password is required (an empty-password autologin admin was previously
  possible); the destructive whole-disk erase choice is no longer
  preselected; LUKS2 is used for automated encryption.
- `kutu-keyring` now populates on `post_upgrade` so signing keys
  introduced later reach existing systems via `pacman -Syu`; the release
  workflow imports `KUTU_GPG_KEY` when provisioned and detach-signs all
  packages and the repo db (unsigned until the key exists — see
  docs/RELEASE.md).

### Changed

- Calamares module configs brought to their schemas: welcome checks
  (storage/ram/power/root) enforced, locale starts from the live system
  timezone, mount options moved to `mount.conf` (ext4/btrfs `noatime`,
  EFI `umask=0077`), `/tmp` is disk-backed on SSD roots (previously
  silently RAM-backed — the wrong default for a RAM-conservation
  distro), keyboard/locale/displaymanager configs de-noised, branding
  links point at the `kutuso` org.
- Desktop: `xfce4-notifyd` added for notifications; `kutu-desktop-xfce`
  declares its `kutu-base` dependency (the firefox wrap calls
  `kutu-run`); the default-wallpaper marker is only set when at least
  one output was actually configured.
- Docs: the memory-mode table describes the real M1 behavior
  (ceilings-only), the 20–40% reclamation figure is labeled a design
  target pending the M2 benchmark harness, `KUTU_VM_*` semantics and the
  `KUTU_IN_DOCKER=1` host-mode warning are corrected, and spec §20
  records the accepted deviations (swap sizing, zpool param, oomd
  placement, installer autologin, M1 mode scope, initramfs derivation).

## 0.1.0 — 2026-08-31

First milestone: the RAM-conservation desktop (M1).

### Added

- Package-first distro base: `kutu-memory` (Tier-0 zswap/MGLRU/DAMON/
  oomd/journald/sysctl tuning with spec-locked values), `kutu-base`
  (first-boot RAM-size calibration into saver/balanced/performance
  modes, `kutu-run` per-application cgroup scopes, `kutu-check-kernel`
  feature prober), `kutu-desktop-xfce` (curated XFCE 4.20 set, KutuDark
  theming, wallpapers, Firefox autoconfig with raised tab-unload
  thresholds), `kutu-keyring` (scaffolding), and a vendored Calamares
  3.3.14 build with ckbcomp.
- archiso profile (BIOS syslinux + UEFI systemd-boot) producing a live
  ISO with an autologin XFCE session and an offline "Install kutu OS"
  flow (unpackfs + target-built initramfs + grub).
- CI: lint/unit/package-build suite in docker; tag-triggered release
  workflow with a QEMU smoke test of the live image; pacman repo
  published through GitHub Pages (branch-deployed from `docs/`).
- Documentation site (docsify) with landing page, memory-stack,
  building, architecture and release guides.
