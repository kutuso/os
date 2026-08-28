# kutu OS

**The RAM-sipping Linux desktop for the DRAM-shortage era.**

Between 2025 and 2026 DRAM prices roughly quintupled. A 64GB kit that cost
$191 in 2025 cleared $1,100 a year later, and analysts expect no relief
before 2028. If your machine has 4–16GB and started feeling cramped, kutu OS
is for it: a Linux desktop that treats memory as the scarce resource it now
is — every gigabyte your software doesn't waste is an upgrade you don't have
to buy at crisis prices.

kutu OS applies the memory-conservation stack that Google and Meta proved at
fleet scale (compressed swap tiers, smarter page aging, proactive reclaim,
pressure-driven killing) to a normal desktop, with safe defaults and nothing
to configure. See [docs/MEMORY.md](docs/MEMORY.md) for what runs under the
hood and how to tune or disable any of it.

## What you get

- An Arch-based XFCE desktop that boots into a live session and installs
  itself with a few clicks (Calamares installer, offline, no accounts needed)
- A memory stack that typically reclaims 20–40% of effective working set:
  zswap (zstd-compressed swap in RAM), MGLRU page aging, DAMON proactive
  reclaim, PSI-driven systemd-oomd, and per-application memory ceilings
- First-boot auto-tuning by RAM size (saver / balanced / performance modes)
- Everything reversible: `sudo kutu-reset` returns you to stock behavior
- Updates forever via plain `pacman -Syu` against the kutu repository

## Getting it

Download the latest ISO from
[releases](https://github.com/kutu-so/os/releases), write it to a USB stick
(`dd if=kutu-os-*.iso of=/dev/sdX bs=4M status=progress`), boot it, click
"Install kutu OS".

- Needs: x86_64, 2GB+ RAM (8GB+ storage for install), USB or DVD
- The live session logs in automatically — poke around before installing

## Project status

- **M1 (current):** tuned OS + installer + CI, smoke-tested end to end in
  QEMU on every release
- **M2:** `kutu-doctor` (memory health dashboard) and `kutu-memoryd`
  (PSI-driven policy daemon with a user-visible aggressiveness dial)
- **M3:** `libmempressure` — a Linux answer to Android's onTrimMemory, so
  apps can shed memory gracefully under pressure instead of dying

Design spec: [docs/superpowers/specs/2026-08-27-ramageddon-pivot-design.md](docs/superpowers/specs/2026-08-27-ramageddon-pivot-design.md)

## Building from source

Requires only docker and ~10GB of disk:

```sh
make build      # packages + ISO, all inside docker (30-90 min)
make smoke      # boot the ISO in QEMU and assert the memory stack
make test-vm    # boot the ISO interactively
make test       # lint + unit tests + package builds (docker)
```

Nothing on your host is touched — every build and test runs in disposable
containers and VMs. Details: [docs/BUILDING.md](docs/BUILDING.md),
[docs/RELEASE.md](docs/RELEASE.md).

## FAQ

**Is this Arch Linux?** It is built from Arch packages with a custom
repository of kutu packages on top, so the wiki, AUR, and pacman all work.
kutu-specific behavior is configuration and a handful of small packages —
removable without breaking the system.

**What happened to the ML-inference appliance OS?** This repository was
originally that. It pivoted; the history is in git.

**Why not just buy more RAM?** If you can, do. This is for everyone who
can't — or shouldn't have to.
