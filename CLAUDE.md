# kutu OS — repository guide

kutu OS is a RAM-conservation Linux desktop (Arch-based, XFCE, Calamares
installer). This file orients agents working in this repo.

## Architecture in one paragraph

All kutu value ships as pacman packages under `packages/` (package-first
distro). `scripts/build-packages.sh` builds them into a local repo inside
docker; `scripts/build.sh` feeds that repo to an archiso profile
(`archiso/`) which produces the ISO. Installed systems update via
`pacman -Syu` against the kutu repo published to GitHub Pages by CI
(`release.yml`). The memory stack is Tier-0 (spec): zswap+MGLRU+DAMON+oomd
tuning as config packages; a policy daemon (kutu-memoryd) and pressure API
(libmempressure) arrive in M2/M3.

## Packages (packages/)

| Package | What it is |
|---|---|
| `kutu-memory` | Tier-0 tuning: sysctl.d, grub.d zswap cmdline, `kutu-memory-early` (zpool+MGLRU), `kutu-damon`, oomd configs, `kutu-reset` |
| `kutu-base` | os-release, `kutu-firstboot` (RAM-based mode calibration), `kutu-run` (per-app cgroup launcher), `kutu-check-kernel` |
| `kutu-desktop-xfce` | curated XFCE set, kutu theming (branding/), lightdm config, Firefox autoconfig + kutu-run wrapping (via alpm hook) |
| `kutu-calamares-config` | /etc/calamares settings + branding; offline install via unpackfs from the live env |
| `kutu-keyring` | pacman keyring (empty until a signing key exists — see docs/RELEASE.md) |
| `calamares` | vendored upstream 3.3.14 build (+ ckbcomp from Debian console-setup) since Arch repos don't ship calamares |

## Hard rules

- **Never mutate the host.** All builds/tests run in docker (`archlinux:base-devel`)
  or QEMU. Scripts honor `KUTU_IN_DOCKER` to skip the docker wrapper.
- **Tier-0 values are locked** by `docs/superpowers/specs/2026-08-27-ramageddon-pivot-design.md`
  (§6–§7): sysctls, zswap cmdline, MGLRU 0x0007/min_ttl 1000, mode thresholds
  (<6G saver / 6–16G balanced / >16G performance; user.slice 85/90/95%;
  Firefox 40/50/70%). Changing them is a spec change.
- **systemd is the sole cgroup writer** (scriptlets and services use
  `systemctl`, never raw cgroupfs writes, except documented one-shots).
- Kernel realities baked into the code: kernels ≥6.10 have **no zswap zpool
  param** (zsmalloc is the baked default); DAMON sysfs is
  `/sys/kernel/mm/damon/admin/kdamonds/nr_kdamonds` (note the kdamonds/
  level); MGLRU is on by default in Arch kernels (we set min_ttl_ms).
- pacman scriptlets run chrooted with `$1` = package version — never use
  `--root="$1"`; plain `systemctl enable` works.
- Scriptlets must not break when units/files are absent (ISO builds,
  upgrades): `|| true` guards.
- Bump `pkgrel` on every package content change (stale-cache checksum
  failures otherwise; build-packages.sh also purges our pkgs from the pacman
  cache for this reason).

## Commands

```sh
make test      # shellcheck + unit tests + package builds (in docker)
make build     # full ISO (docker, privileged for pacstrap mounts)
make smoke     # QEMU boot + assertions of the whole stack (the release gate)
make test-vm   # interactive QEMU boot of the latest ISO
```

The smoke test asserts: zswap params, MGLRU, DAMON kdamond state, six
services active, `kutu-check-kernel` exit 0, `kutu-run`, and a live XFCE
session. It must pass before any release tag.

## Tests

- `tests/kutu-damon-test.sh` — DAMON sysfs setup script against a fake tree
  (`KUTU_DAMON_SYSFS` override); run after any damon script change.
- `tests/kutu-firstboot-test.sh` — mode selection + MemoryHigh math for
  4/16/64 GB.
- `tests/kutu-run-test.sh` — profile parsing and systemd-run arg building.
- `tests/patch-firefox-desktop-test.sh` — the Exec wrapping sed.

## Release

Tag `vX.Y.Z` → `.github/workflows/release.yml` builds + smoke-tests +
publishes (ISO to GitHub release ≤2GiB — keep it that way; pacman repo to
gh-pages at `repo/x86_64/`). Manual checklist in `docs/RELEASE.md`.

## Conventions

- Commits: lowercase imperative, one feature per commit ("kutu-memory: ...").
- Shell scripts must pass `shellcheck` (enforced by `scripts/test.sh`).
- No comments in code unless the file is documentation (config files may
  carry explanatory comments).
- Plans/specs live in `docs/superpowers/`; M2/M3 get their own spec+plan
  when started.
