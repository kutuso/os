# The kutu OS ecosystem

kutu OS is not one repository. The distro lives at the center; a CLI and a
system library orbit it as sibling projects in the
[kutuso](https://github.com/kutuso) org, each with its own tests, releases
and documentation.

| Repo | What it is | Language | Tests |
|---|---|---|---|
| [kutuso/os](https://github.com/kutuso/os) | The distro: archiso profile, packages, installer, CI, this site | shell + pacman | lint/unit/package suites, QEMU smoke, release gate |
| [kutuso/doctor](https://github.com/kutuso/doctor) | `kutu-doctor` — live memory-health dashboard, `check` prober, live mode switching | Python (typer + rich) | fake-tree unit tests + in-VM QEMU harness |
| [kutuso/libmempressure](https://github.com/kutuso/libmempressure) | `libmempressure` — memory-pressure events from kernel PSI; C/C++/JVM/Python bindings (the M3 building block) | C | ctest (C/C++/JVM), pytest, ASan/UBSan CI |

The sibling [kutuso/resources](https://github.com/kutuso) project (per-app
cgroup resource GUI) will join the table once it ships as a package.

## How the pieces fit

```
        kutuso/os  (the distro, this site)
        ┌─────────────────────────────────────────────┐
        │ live ISO ──► Calamares ──► installed system │
        │   packages: kutu-memory, kutu-base, ...      │
        │              kutu-doctor (vendored ──────┐)  │
        └──────────────────────────────────────────┼──┘
                                                    │
   kutuso/doctor ──── source of truth ─────────────┘
        reads/writes only files kutu-base/kutu-memory own,
        applies cgroup state via systemctl only

   kutuso/libmempressure ── standalone C library
        consumed by future mempressured + applications
        (M3: apps shed memory instead of dying)
```

## Versioning and flow

- **os** tags `vX.Y.Z`; each tag builds the ISO, smoke-tests it in QEMU,
  publishes the pacman repo to this site and the ISO to the GitHub release.
- **doctor** versions independently; the os repo vendors a copy in
  `packages/kutu-doctor/` (synced with `make vendor` from the doctor repo,
  plus a `pkgrel` bump). The vendoring workflow is documented in
  [MAINTAINERS.md](https://github.com/kutuso/os/blob/master/MAINTAINERS.md).
- **libmempressure** versions independently (`libmempressure.so.0` soname);
  nothing in the distro links it yet — it is the foundation for the M3
  `mempressured` daemon and for applications that want pressure events.

## In-depth pages

- [kutu-doctor](DOCTOR.md) — usage, integration and the packaging workflow
- [libmempressure](LIBMEMPRESSURE.md) — API tour across the four bindings

For operational runbooks (kernel regressions, release failures, signing key
rotation), see the [playbooks](PLAYBOOK.md).
