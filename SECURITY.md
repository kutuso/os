# Security Policy

## Supported versions

The `master` branch is supported. Released versions are the tagged `vX.Y.Z`
ISOs and the package repository snapshots they publish.

## Reporting a vulnerability

Please report vulnerabilities privately:
[GitHub security advisories](https://github.com/kutuso/os/security/advisories/new).

The highest-impact areas, in order:

1. **The package repository / supply chain** — signing gaps, the release
   workflow, the vendored sources (`calamares`, `ckbcomp`, `yay`, the
   `kutu-doctor` copy), or anything that could serve a malicious package to
   `pacman -Syu` on installed systems.
2. **The installer** — Calamares configuration, post-install cleanup, or
   anything that leaves an installed system weaker than intended.
3. **The live ISO** — session defaults, services, the autologin live user.

## Current posture (honest inventory)

- The kutu repository is **unsigned** (`SigLevel = Never`) until a release
  key is provisioned — tracked as the pre-v1 blocker in
  [docs/RELEASE.md](docs/RELEASE.md) and MAINTAINERS.md. The signing
  machinery (keyring package, CI signing step, `post_upgrade` population)
  exists and activates when the `KUTU_GPG_KEY` secret is set.
- Secure Boot is **not** supported; the boot chain is unsigned by design
  for v0.x.
- CI follows least privilege (`contents: read` except the release publish
  job), and Actions updates are tracked by Dependabot.
