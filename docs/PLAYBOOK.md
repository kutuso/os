# Operations playbooks

Runbooks for the situations a kutu OS maintainer will actually face. When
in doubt: reproduce in QEMU (`make test-vm`), never on a real machine, and
never tag past a red gate.

## 1. A kernel update broke the memory stack

**Symptoms:** `kutu-doctor check` (or `kutu-check-kernel`) reports FAILs
after `pacman -Syu`; users report kills or sluggishness.

1. Boot the new kernel in QEMU against the current ISO packages:
   `make build && make smoke` — the smoke suite asserts zswap, MGLRU,
   DAMON, PSI and all services.
2. Identify the moved interface. Precedent: zswap's `zpool` parameter was
   removed in 6.10 (handled by `kutu-memory-early` at runtime); DAMON's
   sysfs lives under `admin/kdamonds/`.
3. Patch the reader (`kutu-check-kernel`, `kutu-memory-early`,
   `kutu-damon`, and the doctor repo's `memory.py` — the doctor's QEMU
   harness `make vmtest` re-verifies it against the real kernel).
4. Add a failing check first, then the fix; bump `pkgrel`; `make test`.
5. If the value changes touch Tier-0 locked numbers, this is a spec
   change — amend the design spec in the same commit (see CLAUDE.md).

## 2. "My app got killed"

1. `kutu-doctor status` — was there real pressure (PSI some avg10)?
2. `systemctl status 'app-*.scope'` — had the app crossed its
   `MemoryHigh`? `journalctl -b -u systemd-oomd` shows the kill decision.
3. If oomd killed a session-critical unit (audio, portal), that's a bug in
   the avoid-drop-ins — treat as high priority (see MAINTAINERS.md).
4. User-side mitigation: `kutu-doctor mode set performance` (looser
   ceilings) or `sudo kutu-reset` as a diagnostic.

## 3. Release failed mid-way

**Symptoms:** tag pushed, `release.yml` red, ISO/repo partially published.

1. Read the failing step in Actions. The workflow fails hard by design:
   - *build/smoke failed* → fix on master, re-tag (delete and re-push the
     tag after the fix lands; never move forward past a red gate).
   - *publish push failed (master moved)* → re-run the release from a
     fresh tag; the workflow pushes the repo to master, so concurrent
     master merges can race it (a `concurrency` group serializes releases).
   - *verification failed (db/package 404)* → Pages deploy lag or the
     `.gitignore` negations regressed; check `docs/repo/x86_64/` on
     master actually contains the `.pkg.tar.zst` files.
2. The GitHub release is only created **after** repo verification passes,
   so a half-published state means: no release exists, re-tag cleanly.

## 4. Signing key rotation (or first provisioning)

Follow [RELEASE.md](RELEASE.md) "One-time": generate the key, export the
public key into `kutu-keyring/keyrings/`, set the `KUTU_GPG_KEY` secret.
CI then signs packages + db automatically. Sequence for flipping
enforcement:

1. Release once with the key shipped but `SigLevel = Never` intact —
   installed systems pick up `kutu-keyring` (its `post_upgrade` populates
   the key) via plain `pacman -Syu`.
2. Verify on a QEMU install: `pacman-key --list-keys | grep kutu`.
3. Flip the shipped `[kutu]` `SigLevel` to `Required DatabaseOptional`
   and the `shellprocess@done.conf` section in the installer; release.
4. If a key is ever compromised: revoke, ship the new one via the ISO
   build (the only fully-trusted channel), note the rotation in release
   notes.

## 5. Updating the vendored kutu-doctor

```sh
cd ../doctor && make test && make vmtest   # gates on the source repo
make vendor                                 # rsync into ../os
cd ../os && $EDITOR packages/kutu-doctor/PKGBUILD   # bump pkgrel
make test && make smoke
```

## 6. Updating vendored calamares (or yay)

See MAINTAINERS.md "Vendored calamares": set `pkgver`, replace the tarball
URL + `sha256sums` from the release notes, delete the cached package,
`make test` (20-minute compile), `make smoke`.

## 7. ISO exceeds 2 GiB

GitHub caps release assets at 2 GiB. Check `ls -lh out/*.iso`. Levers, in
order: drop heavy firmware from `archiso/packages.x86_64` (verify hardware
coverage in QEMU), squashfs already runs zstd-19, consider splitting
`linux-lts` into its own flavor rather than growing the main ISO.

## 8. Smoke test failed

1. Read `work/smoke.log` — each assertion is a `SMOKE:` line; the runner
   prints exactly which one failed.
2. Reproduce interactively: `make test-vm`, then the same commands by hand
   (the smoke script is plain `expect` — copy the failing command).
3. Installer-related assertions (`initramfs-linux.img`, firstboot, repo
   section) mean the Calamares sequence regressed — the sequence test in
   `tests/calamares-sequence-test.sh` usually catches this earlier.

## 9. Wrong ceilings on a machine (mode mis-calibration)

Firstboot picked a mode from RAM size; the user edited or the RAM changed.

- Show: `kutu-doctor mode` (current vs. recommended-for-this-RAM).
- Fix: `sudo kutu-doctor mode set <recommended>` — applies live, no
  reboot.
- The persisted mode is a pacman backup file; package upgrades never
  overwrite it. If `/var/lib/kutu/firstboot-done` is missing on an
  installed system (it shouldn't be — the installer removes the live
  marker), firstboot recalibrates on next boot.

## 10. Docs site broken (404s / empty sidebar)

- The site is branch-deployed from `docs/` on master; `docs/.nojekyll`
  must exist (Jekyll drops `_sidebar.md` → empty docsify sidebar).
- The pacman repo is served from `docs/repo/x86_64/` on the same site —
  if `kutu.db` 404s, the release publish step didn't run or its gitignore
  negations were lost.
- Check the Pages deployment in the repo settings (branch: master,
  directory: /docs).
