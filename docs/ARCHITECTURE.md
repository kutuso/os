# kutu OS Architecture

## The one-paragraph version

kutu OS is package-first: all distro value lives in pacman packages
(`packages/`), built in docker (`scripts/build-packages.sh`) into a local
repository, consumed by an archiso profile (`archiso/`) to produce a live
ISO, and installed offline via Calamares (unpackfs copies the live system to
disk). Installed machines keep a pacman.conf entry pointing at the kutu repo
on GitHub Pages, so every improvement — tuning changes, new features — flows
to them as ordinary `pacman -Syu` updates.

```
┌─ GitHub Actions (release.yml) ────────────────────────────────┐
│ tag push → build+test packages (docker) → repo-add            │
│          → mkarchiso ISO (privileged docker)                  │
│          → QEMU smoke test (the release gate)                 │
└──────────────┬─────────────────────────────┬──────────────────┘
               ▼                             ▼
   gh-pages pacman repo              GitHub Release (ISO)
   repo/x86_64/                      kutu-os-*.iso ≤ 2GiB
               │                             │
               ▼                             ▼
   installed systems               user boots live ISO,
   update via pacman -Syu          installs via Calamares
```

## Layers

### Live ISO (archiso/)

- Profile: syslinux (BIOS) + systemd-boot (UEFI), zstd-19 squashfs.
- Kernel cmdline carries the Tier-0 boot-time params (zswap zstd/pool 35%/
  shrinker, PSI, THP=madvise) and serial console for smoke testing.
- The airootfs overlay carries live-session glue (autologin for user
  `kutu`, serial getty, sudoers, mkinitcpio archiso hooks) that Calamares
  removes from the installed system (`shellprocess@done`).

### Memory stack (kutu-memory, kutu-base)

- Boot time: kernel cmdline (zswap), `kutu-memory-early.service` (zswap
  zpool on pre-6.10 kernels + MGLRU enable), sysctl.d (swappiness etc).
- Always on: `kutu-damon.service` (DAMON sysfs scheme: page-out regions
  untouched ≥10s, watermark-gated 5–15% free band), systemd-oomd with
  ManagedOOM on user.slice and avoid-preference on session services,
  journald volatile.
- First boot: `kutu-firstboot.service` calibrates mode (saver/balanced/
  performance by RAM size), writes user.slice MemoryHigh and the Firefox
  per-app ceiling.
- Apps: `kutu-run` wraps launches into `app-*.scope` units with MemoryHigh
  etc.; Firefox's desktop Exec is wrapped via an alpm hook that re-applies
  after firefox upgrades.

### Desktop (kutu-desktop-xfce)

XFCE 4.20 on X11, lightdm (autologin via PAM `autologin` group on live;
Calamares wires the installed user), PipeWire, NetworkManager, Firefox with
raised tab-unload thresholds via autoconfig. Theming from
`branding/` (KutuDark GTK theme, kutu wallpapers).

### Installer (calamares + kutu-calamares-config)

Upstream Calamares 3.3.14 built in our repo (Arch doesn't ship it; ckbcomp
vendored from Debian console-setup). Our config: welcome (1.5GB RAM check) →
locale/keyboard → partition (erase-disk + RAM-sized swap default) → users
(autologin default on) → unpackfs (byte-identical offline install) →
kernel + initramfs install (archiso strips kernels from the live squashfs,
so the kernel is copied from the ISO boot tree and a fresh initramfs is
built in the target with mkinitcpio — the live initramfs is archiso's and
cannot boot an installed disk) → displaymanager/fstab/bootloader (grub) →
post-install cleanup (repoint pacman.conf at the live repo, strip
live-session files, enable kutu-firstboot). The mount module binds
/dev, /proc, /sys and /run/udev into the target so grub-install and
mkinitcpio work in the chroot; custom shellprocess instances
(`shellprocess@kernel`, `shellprocess@done`) are declared in the settings
`instances:` section.

## Design decisions

See the design spec (`superpowers/specs/2026-08-27-ramageddon-pivot-design.md`)
for rationale on: package-first architecture, stock kernel (no custom build
in v1), zswap over zram, XFCE on X11, systemd as sole cgroup writer, escape
hatches, and the M1/M2/M3 roadmap (M2: kutu-doctor + kutu-memoryd; M3:
libmempressure + mempressured).
