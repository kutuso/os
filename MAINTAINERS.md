# MAINTAINERS.md — kutu OS maintainer playbook

The operating manual for whoever maintains this distro. For what kutu OS
*is*, read `README.md` and `docs/MEMORY.md`. For how to hack on it, read
`CLAUDE.md`. This file is about running the project over time.

## The rules that keep the distro alive

1. **`make smoke` is the release gate.** Never tag without it passing
   locally. CI runs it again on the tag — a red smoke means pull the tag.
2. **Never mutate the host machine.** All builds/tests run in docker/QEMU.
   If a script needs sudo on the host, it is wrong.
3. **Bump `pkgrel` on every package content change.** Same-version rebuilds
   collide with stale pacman-cache copies (see the cache purge in
   `scripts/build-packages.sh` — it mitigates, the bump is the discipline).
4. **Tier-0 memory values are spec-locked.** The sysctls, zswap cmdline,
   MGLRU settings, and mode thresholds are defined in
   `docs/superpowers/specs/2026-08-27-ramageddon-pivot-design.md` §6–§7.
   Changing a value is a spec change: update the spec in the same commit.
5. **ISO stays under 2 GiB** (GitHub release asset limit). Currently ~1.7
   GiB; if you add packages, check the size before tagging.

## Release procedure

1. `make test` — lint, unit tests, package builds.
2. `make build` — full ISO.
3. `make smoke` — boot + assert the whole memory stack.
4. Check `ls -lh out/*.iso` < 2 GiB.
5. `git tag -s vX.Y.Z -m "..." && git push origin master vX.Y.Z`
   CI (`release.yml`) builds, smoke-tests, publishes the pacman repo to
   gh-pages and the ISO to the GitHub release.
6. Post-release verification (30 min, do it every time):
   - the release page has the ISO + SHA256SUMS
   - `https://<org>.github.io/os/repo/x86_64/` serves `kutu.db`
   - boot the released ISO in QEMU (`make test-vm`), click Install, boot the
     installed system, then: `grep zswap /proc/cmdline`,
     `kutu-check-kernel` exits 0, `pacman -Syu` reaches the kutu repo,
     Firefox launches inside an `app-firefox-*.scope` cgroup.
   - the docs site (`https://<org>.github.io/os/`) loads and shows the
     current README/MEMORY pages.

Versioning: `v0.X.Z` while M2/M3 are landing, `v1.0.0` when the signing key
exists and M2 ships. Tag from `master` only.

## Weekly / routine maintenance

- **Arch updates:** the ISO is built from current Arch repos, so security
  fixes flow into each release automatically. No backporting needed unless
  a CVE affects our own packages.
- **Kernel watch:** Arch kernel updates can move or remove sysfs interfaces
  the stack depends on (it happened before: zswap's `zpool` param was
  removed in 6.10, DAMON sysfs layout sits under `kdamonds/`). After any
  kernel bump: `make build && make smoke`. Users on installed systems get
  `kutu-check-kernel` results in the journal via the alpm hook — triage
  any FAIL reports against `kutu-check-kernel` output.
- **Vendored calamares:** track upstream releases
  (github.com/calamares/calamares). To update: set `pkgver`, replace the
  tarball URL + `sha256sums` (published in the release notes), delete the
  cached package, `make test` (20 min compile), `make smoke`. ckbcomp comes
  from Debian `console-setup`; update alongside, rarely needed.
- **Repo hygiene:** gh-pages `repo/x86_64/` grows monotonically today.
  When it passes ~500 MB, prune old package versions keeping the newest 3
  of each (`repo-add` rebuilds `kutu.db.tar.zst` from what remains).

## Signing (currently the one open TODO)

The repo ships unsigned (`SigLevel = Never` in the shipped pacman.conf) —
acceptable for v0.x, **must** be fixed before v1.0:

1. Generate a signing key (steps in `docs/RELEASE.md`).
2. Export the public key into `packages/kutu-keyring/keyrings/` (gpg +
   trusted files), bump its pkgrel.
3. Add the private key as the `KUTU_GPG_KEY` repo secret.
4. In `release.yml`, import the key and build with `makepkg --sign` /
   `repo-add --sign`; flip the shipped pacman.conf `[kutu]` SigLevel to
   `PackageRequired` and update the ISO's `/etc/pacman.conf` handling
   accordingly.
5. Release once more; installed systems pick up the keyring via
   `pacman -Syu`.

If the key ever leaks: revoke, generate a new one, ship it via the ISO
build (the only fully-trusted channel), and note the rotation in the
release notes.

## Handling user reports

- **"My app got killed"** → oomd did its job; check whether the app was
  past its `MemoryHigh` (`systemctl status app-*.scope`,
  `journalctl -b -u systemd-oomd`). If the kill was wrong (session
  services etc.), it's a bug in the avoid-drop-ins — treat as high
  priority.
- **"System feels slow"** → ask for `kutu-check-kernel` output and
  `/proc/pressure/memory`. If PSI is low, the problem isn't the memory
  stack; suggest `sudo kutu-reset` as a diagnostic (if performance returns,
  we over-tuned — file an issue with the numbers).
- **"Firefox is sluggish under memory pressure"** → tab-unload thresholds
  live in `packages/kutu-desktop-xfce/firefox/mozilla.cfg`; the per-app
  ceiling lives in `kutu-firstboot` mode values.
- **"Install fails"** → Calamares logs: `/var/log/calamares` (on the live
  system). The installer runs offline-unpackfs; most failures are
  partitioning edge cases.

## Adding a package to the distro

1. Create `packages/<name>/` with a PKGBUILD (follow `kutu-memory` for
   config-package patterns: `$startdir` sources, `.install` scriptlets,
   `|| true` guards for absent units).
2. If installed systems need updates for it: add it to
   `archiso/packages.x86_64` AND make sure the installed system's
   `pacman.conf` `[kutu]` repo covers it (it will — the repo is the same).
3. `make test` then `make smoke`; commit with a `pkgname:` prefix.
4. New system services need: enable via the package `.install`, and a
   smoke assertion in `scripts/smoke-test.sh`.

## Roadmap ownership

- **M2** — `kutu-memoryd` (PSI-driven policy daemon, mode dial) and
  `kutu-doctor` (memory health TUI). Spec §8. Needs its own
  spec+plan in `docs/superpowers/` before work starts.
- **M3** — `mempressured` + `libmempressure` (Linux onTrimMemory). Spec §9.
- **Sibling project** — `../resources` (per-app cgroup resource GUI),
  designed to ship on kutu OS as a package once built.