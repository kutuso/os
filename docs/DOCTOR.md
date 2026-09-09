# kutu-doctor

`kutu-doctor` is the M2 control surface of kutu OS: a live memory-health
dashboard plus the commands to verify, tune and revert the memory stack.
It ships preinstalled on the ISO and installed systems (the
`kutu-doctor` package) and also runs standalone on any Arch-ish machine.

Source of truth: [kutuso/doctor](https://github.com/kutuso/doctor).

```
╭─ kutu-doctor ───────────────────────────────────────────────────╮
│ memory                     │ stack                               │
│   ram    ━━━━━━━ 9.8/16.0G │ mglru   ● on · ttl 1000 ms          │
│   swap  ━ 300M/8.0G        │ damon   on                          │
│   pressure some ▏0.1% ...  │ oomd    ● on                        │
│ zswap                      │ user.slice  MemoryHigh 14.1 GiB     │
│   pool   ━━ 512M / 5.6G    │ firefox     ceiling 8.0 GiB (50%)   │
│   compression ━ ≈1.0×      │ top consumers: user.slice 1.5G ...  │
╰────────────────────────────┴─────────────────────────────────────╯
```

Run `kutu-doctor` with no arguments and you get the live dashboard
(Ctrl-C to exit). Everything else is a subcommand.

## Commands

| Command | What it does |
|---|---|
| `kutu-doctor` / `dash [-i SEC]` | The live dashboard: RAM/swap bars, PSI gauges, zswap pool + compression ratio, stack states, ceilings, top cgroup consumers. |
| `kutu-doctor status [--json]` | One-shot snapshot; `--json` for scripting (`kutu-doctor status --json \| jq .zswap`). |
| `kutu-doctor check [--json]` | Every kernel feature and service the stack relies on, PASS/FAIL with fix hints; non-zero exit on failure. The `kutu-check-kernel` contract in friendlier clothes. |
| `kutu-doctor mode` | Current mode + the one recommended for this machine's RAM. |
| `kutu-doctor mode set <saver\|balanced\|performance>` | Persist the mode **and apply its ceilings live** (no reboot). |
| `kutu-doctor mode apply` | Idempotently re-apply the persisted mode. |
| `kutu-doctor apps` / `apps run <profile> <cmd>` | Inspect per-app ceilings; run a command inside its `app-*.scope` (same semantics as `kutu-run`). |
| `kutu-doctor reset [--yes]` | Run `kutu-reset`: the whole stack back to stock Arch defaults. |

## Mode switching, exactly

The ceiling matrices are locked by the design spec (§6–§7):

| Mode | Chosen when | user.slice | firefox |
|---|---|---|---|
| saver | < 6 GiB | 85% | 40% |
| balanced | 6–16 GiB | 90% | 50% |
| performance | > 16 GiB | 95% | 70% |

`mode set` touches exactly the files `kutu-firstboot` owns —
`/etc/kutu/memory.conf`, the `user.slice` drop-in, and the
`KUTU_MEMORY_HIGH_PCT` lines in `/etc/kutu/apps.d/` — then applies them
live:

```sh
systemctl daemon-reload
systemctl set-property --runtime user.slice MemoryHigh=<bytes>
```

systemd remains the sole cgroup writer; nothing touches cgroupfs directly.
Custom ceilings in non-builtin app profiles are never overwritten. This is
the "mode dial" the memory-stack docs promised for M2.

## Environment overrides

Same conventions as the OS shell tools (also how the test suite fakes a
whole machine): `KUTU_ROOT` (prefix for `/`), `KUTU_SYSFS`, `KUTU_PROC`,
`KUTU_SYSTEMCTL`, `KUTU_SYSTEMD_RUN`, `KUTU_DRY_RUN=1`.

## Development and testing

```sh
git clone https://github.com/kutuso/doctor
cd doctor && python3 -m venv .venv && . .venv/bin/activate
pip install -e ".[dev]"
pytest               # unit tests over a full fake /sys + /proc + /etc tree
ruff check .
make vmtest          # boots the real kutu ISO in QEMU and drives the real
                     # kernel: flips zswap pool cap / MGLRU ttl / DAMON
                     # state and asserts the CLI observes each change,
                     # including the systemctl -> cgroupfs round-trip
```

The QEMU harness is the interesting part: unit fakes prove the parsing, the
VM proves the CLI reads a real kernel and that its writes actually land
(it has caught a real relative-path bug that no fake could).

## Packaging into the distro

The os repo vendors the module (`packages/kutu-doctor/`). From the doctor
repo: `make vendor`, then bump `pkgrel` in
`packages/kutu-doctor/PKGBUILD` and run `make test` over in the os
checkout. The full checklist lives in the os repo's MAINTAINERS.md.
