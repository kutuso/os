# kutu OS Release Process

## One-time (or key rotation): signing key

1. `gpg --quick-gen-key "kutu OS Release <release@kutu.so>" ed25519 sign never`
2. Export the public key:
   `gpg --armor --export release@kutu.so > packages/kutu-keyring/keyrings/kutu.gpg`
3. Set ownertrust (replace KEYID):
   `printf '<KEYID>:4:\n' > packages/kutu-keyring/keyrings/kutu-trusted`
4. Export the private key for CI:
   `gpg --armor --export-secret-keys release@kutu.so`
   Add it as GitHub secret `KUTU_GPG_KEY` (repo Settings -> Secrets and
   variables -> Actions).

Without a key, CI builds unsigned packages and the shipped pacman.conf uses
`SigLevel = Never` (never past v1 — spec decision D9).

## Releasing

1. Ensure `make smoke` passes locally (full pipeline: packages in docker,
   ISO build, QEMU boot assertions).
2. Tag: `git tag -s vX.Y.Z -m "kutu OS vX.Y.Z" && git push origin vX.Y.Z`
3. CI (release.yml) then:
   - builds + signs all packages (makepkg --sign when key present)
   - publishes the pacman repo to gh-pages (`repo/x86_64/`)
   - builds the ISO with mkarchiso
   - smoke-tests the ISO in QEMU (TCG)
   - attaches `kutu-os-X.Y.Z-x86_64.iso` + `SHA256SUMS` to the GitHub release
4. Manual release checklist (run in QEMU with the release ISO):
   - boot live ISO -> lightdm autologin reaches the XFCE desktop
   - run "Install kutu OS" (Calamares) to disk with default options -> reboot
   - installed system: `grep zswap.enabled=1 /proc/cmdline`
   - `kutu-check-kernel` exits 0
   - `pacman -Sl kutu` lists packages (repo reachable)
   - Firefox launches inside an `app-firefox-*.scope` cgroup (`systemd-cgls`)
   - landing page + docs render on the deployed Pages site
   - refresh `site/screenshots/` if the desktop or installer look changed
