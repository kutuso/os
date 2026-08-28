# The kutu OS Memory Stack

kutu OS exists because RAM got expensive — DRAM prices roughly quintupled
between 2025 and 2026 and relief is not expected before 2028. Every gigabyte
your machine doesn't waste is a purchase deferred at crisis prices. kutu OS
applies the memory-conservation techniques proven at fleet scale by Google
(far memory) and Meta (TMO) to a normal desktop.

This document explains what runs on your kutu OS machine, what each piece
does, and how to turn any of it off.

## What is active on every kutu OS machine

### zswap — compressed swap in RAM

The kernel's zswap layer intercepts pages it wants to swap out, compresses
them with zstd, and keeps them in a RAM pool (up to 35% of RAM). Cold data
compresses 2-3x, so "swapping" mostly means "shrinking": it rarely touches
your disk. On kernels 6.10+ zswap always uses the zsmalloc allocator for
maximum density. Cold pages in the pool are drained to disk under real
pressure by the zswap shrinker.

- `/sys/module/zswap/parameters/` shows the live values.
- Compression costs a little CPU; the pool is capped so it can never eat
  your RAM.

### MGLRU — better eviction decisions

The multi-generational LRU is the kernel's modern page-aging engine (it
replaced the old active/inactive lists). It identifies genuinely cold pages
with far less CPU and far fewer wrongful evictions — Google measured a 40%
drop in reclaim CPU and 85% fewer low-memory kills across tens of millions
of ChromeOS/Android devices. kutu OS enables all MGLRU components and sets a
1-second minimum working-set protection window to resist thrashing.

### DAMON — proactive reclaim

DAMON samples which memory regions are actually being touched and lets the
kernel page out regions that have been untouched for 10+ seconds — but only
when free memory drops into the "mild pressure" band (5–15% free). When
memory is plentiful it does nothing; when you're in real trouble it steps
aside and lets the emergency reclaim paths work.

- Check it: `cat /sys/kernel/mm/damon/admin/kdamonds/0/state` → `on`

### PSI + systemd-oomd — graceful pressure handling

The kernel's Pressure Stall Information (PSI) measures how much time tasks
actually spend stalled waiting for memory. systemd-oomd watches PSI and
kills a whole misbehaving application (not your session, not your compositor,
not your audio) *before* the machine grinds to a halt.

### Per-application memory ceilings

Applications launched through kutu OS (Firefox is the big one) run in their
own systemd scope with a `MemoryHigh` soft ceiling (50% of RAM for Firefox).
When an app crosses its ceiling, the kernel reclaims from *that app's* cold
pages first — the app polices itself before it can pressure everyone else.
The whole user session also gets a ceiling just under total RAM so the
system always keeps headroom.

### Tuned reclaim knobs

`vm.swappiness=120` (swap-to-compressed-RAM is cheap, so do it early),
`vm.page-cluster=0` (bring back one page at a time — snappier under pressure),
raised kswapd headroom, and smoothed disk writeback. All in
`/etc/sysctl.d/60-kutu-memory.conf`.

### The rest

- Journald logs live in RAM (compressed under zswap, capped at 64MB, gone on
  reboot).
- I/O schedulers per device class (none for NVMe — the hardware is smarter).
- Transparent huge pages only for apps that ask (`madvise`).
- Firefox tab unloading fires early (thresholds raised well above upstream
  defaults).

## First boot

`kutu-firstboot` measures your RAM and picks a mode:

| Mode | Chosen when | Effect |
|---|---|---|
| saver | < 6 GB | tighter ceilings, more aggressive reclaim |
| balanced | 6–16 GB | the values documented above |
| performance | > 16 GB | looser ceilings, zswap pool 20% |

The mode is recorded in `/etc/kutu/memory.conf` — edit it and reboot to
change. (A user-visible mode switcher ships with M2, along with `kutu-doctor`
for live memory-health visibility and the `kutu-memoryd` policy daemon.)

## Escape hatches

Everything is reversible:

- `sudo kutu-reset` — reverts all kutu memory tuning to stock Arch defaults,
  disables the kutu services, and regenerates the boot configuration.
  Reboot afterwards.
- Remove individual pieces: `systemctl disable --now kutu-damon` (DAMON),
  `kutu-memory-early` (zswap zpool + MGLRU), `systemd-oomd`.
- `kutu-check-kernel` — verifies every feature the stack relies on; run it
  after kernel updates (kutu OS does this automatically and reports in the
  journal).

## Kernel requirements

All features are mainline: zswap (always), MGLRU (6.1+), per-cgroup zswap
accounting (6.8+), DAMON sysfs (5.18+), PSI (4.20+). kutu OS ships the
current Arch `linux` kernel which has all of them enabled. On other kernels
run `kutu-check-kernel` — anything reported FAIL degrades gracefully (the
service simply doesn't act).
