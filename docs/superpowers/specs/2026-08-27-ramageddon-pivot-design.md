# kutu OS — RAMageddon Pivot Design

**Date:** 2026-08-27
**Status:** Approved design, pre-implementation
**Supersedes:** the ML-inference-appliance positioning of this repository
**Source spec:** "Linux Memory-Conservation Technology Stack" (RAMageddon two-track research, Track A + Track B), produced 2026-08

---

## 1. Context & Motivation

DRAM prices rose ~485% year-over-year (Tom's Hardware tracker, Aug 2026); TrendForce forecasts no relief before H2 2027, plausibly 2028-2029. Every gigabyte a machine doesn't need is a purchase deferred at 3-5x historical prices. Google (software-defined far memory, ASPLOS 2019) and Meta (TMO, ASPLOS 2022, 20-32% per-server savings) proved the mechanisms at fleet scale; the consumer gap is packaging, defaults, and policy — not missing kernel features.

kutu OS pivots from a headless ML-inference appliance (128GB+ RAM target) to **a Linux desktop that makes small-RAM machines genuinely livable** — the "lifesaver" for RAMageddon victims. Realistic target: 20-40% effective working-set reclamation at single-digit-percent CPU overhead, bounded by an interactivity SLO.

## 2. Product Definition

- **Target user:** non-technical. Person with a 4-8GB laptop that became unusable. GUI installer, safe defaults, everything automatic. Visibility available via `kutu-doctor` but never required.
- **Hardware floor:** x86_64, 2GB RAM (installer warns below 1.5GB), NVMe or SATA SSD strongly recommended (zswap needs a backing swap device that isn't painful). No GPU requirements beyond baseline Mesa.
- **Identity:** kutu OS — an Arch-based desktop distro, XFCE, branded with the existing kutu assets (themes, wallpapers, logos).
- **Promise:** "Your old machine, usable again." Boot, install, browse — memory management is invisible until it saves you.

## 3. Goals / Non-Goals

**Goals (v1):**
1. Tier 0 of the source spec as distro defaults: zswap (zstd/zsmalloc/shrinker/35% pool), MGLRU, DAMON watermarked reclaim, PSI-driven systemd-oomd, per-app cgroup limits, tuned sysctls, NVMe swap-first layout.
2. Tier 1 of the source spec: `kutu-memoryd` (B2 desktop-TMO policy daemon) and `libmempressure`/`mempressured` (B4 onTrimMemory-for-Linux).
3. ISO built and distributed via GitHub Actions; installed systems updated via plain `pacman -Syu` against a kutu pacman repo.
4. Calamares GUI installer, offline, branded.
5. `kutu-doctor` — memory health visibility + safe `--fix`.
6. Escape hatches: every intervention reversible to stock Arch behavior.

**Non-Goals (v1):**
- Any ML/inference software (pivot is total; old appliance files removed, git history preserves them).
- Custom kernel (stock Arch `linux` + `linux-lts`; `linux-kutu` exists only as a documented fallback).
- zram-as-primary-swap flavor (source spec: zswap in front of NVMe is the desktop-correct choice; zram flavor may come later for diskless/EEPROM-constrained boxes).
- Wayland session default (XFCE 4.20 Wayland is experimental; X11 for stability — revisit post-v1).
- Track B research items: B1, B5, B8, B10-B17, B20-B22, B25 (deferred per source spec's own tiering).
- A per-app resource-manager GUI — split into the sibling project `../resources` (see §18).

## 4. System Architecture

```
┌─ GitHub Actions ──────────────────────────────────────────────┐
│ tag push → build+sign kutu-* packages (makepkg, containers)   │
│          → repo-add → publish pacman repo (gh-pages)          │
│          → mkarchiso ISO → QEMU smoke test → GitHub Release   │
└───────────────┬────────────────────────────┬──────────────────┘
                ▼                            ▼
   https://kutu-so.github.io/os/repo/   GitHub Release (ISO ~1.6-2GB)
                │                            │
                ▼                            ▼
   installed systems: pacman -Syu      user boots live ISO, installs
   pulls ALL kutu updates forever      with Calamares (offline unpackfs)
```

The load-bearing decision: **all kutu value ships as pacman packages.** The ISO is Arch base + kutu repo snapshot + Calamares; installed machines point `pacman.conf` at the live repo. Updates, tuning changes, and new features (M2/M3) roll out as ordinary package updates. No custom update tooling.

**Cgroup ownership rule:** systemd is the sole cgroup hierarchy writer. `kutu-memoryd` adjusts limits via `systemctl set-property --runtime` and one-shot `memory.reclaim` writes; it never manages cgroupfs directly. This prevents multi-writer conflicts and keeps the system inspectable with stock tooling.

## 5. Package Architecture

| Package | Language | Purpose |
|---|---|---|
| `kutu-base` | any | Branding, os-release, `/etc/kutu/` tree, `kutu-run` launcher wrapper, `kutu-firstboot.service`, `kutu-check-kernel` feature prober |
| `kutu-memory` | any | Tier 0: grub.d zswap cmdline snippet, sysctl.d, MGLRU enable unit, `kutu-damon` service, systemd-oomd config + slice drop-ins, udev I/O rules, journald volatile config, `kutu-reset` (escape hatch) |
| `kutu-desktop-xfce` | any | Curated XFCE 4.20 set + kutu theming + Firefox + wrapped launchers + Firefox autoconfig |
| `kutu-calamares-config` | any | Calamares settings, branding component, offline install flow |
| `kutu-keyring` | any | pacman signing key(s) for the kutu repo |
| `kutu-memoryd` | Rust | B2 desktop-TMO daemon (M2) |
| `kutu-doctor` | Rust | Memory doctor TUI + `--fix` (M2) |
| `mempressured` | Rust | B4 D-Bus pressure-level broadcaster (M3) |
| `libmempressure` | C | B4 client library + `kutu-trim` demo (M3) |

Each package is self-contained under `packages/<name>/` (PKGBUILD + sources), built in CI containers. Rolling repo retention: last 3 versions per package.

**Signing:** CI holds the repo signing key as a secret; `kutu-keyring` (baked into the ISO) distributes the public key; `pacman.conf` uses `SigLevel = PackageRequired`. If CI signing proves unexpectedly painful in M1, it may slip to M2 with `SigLevel = Never` temporarily — never past v1.

## 6. Kernel Policy

- Stock Arch `linux` (current) + `linux-lts` (fallback boot entry, hardware-compat safety net).
- All Tier 0 mechanisms are mainline and runtime-tunable; no kernel rebuild required.
- `kutu-check-kernel` (runs at first boot + on kernel updates via pacman hook) verifies: zswap params, `lru_gen`, DAMON sysfs, per-cgroup zswap, PSI. Missing features → doctor reports degraded mode; `linux-kutu` custom kernel is the documented fallback (not built in v1).
- **Removed** from the old appliance cmdline (each was actively harmful on a small-RAM desktop): `hugepages=2048` (reserved 4GB at boot), `isolcpus`/`nohz_full`/`rcu_nocbs`, `numa=fake=4`, `mitigations=off` (indefensible for a non-technical user's browser machine), `preempt=full`, `nvme_core.default_ps_max_latency_us=0`.
- **Added:** `zswap.enabled=1 zswap.compressor=zstd zswap.zpool=zsmalloc zswap.max_pool_percent=35 zswap.shrinker_enabled=1 psi=1 transparent_hugepage=madvise`.

## 7. Tier 0 Memory Stack (exact defaults)

**Swap:** Calamares default layout creates a swap partition = `min(RAM, 16GiB)`, floor 4GiB, on NVMe/SATA SSD. zswap sits in front; the shrinker drains cold compressed pages to disk under pressure.

**sysctl.d/60-kutu-memory.conf:**
```
vm.swappiness = 120              # spec: 100-180 when swap is compressed
vm.page-cluster = 0              # single-page swap-in for the compressed tier
vm.watermark_scale_factor = 125  # ~1.25% kswapd headroom (default 10 = 0.1%)
vm.watermark_boost_factor = 0    # no reclaim bursts; memoryd owns pressure response
vm.dirty_background_ratio = 5    # smooth writeback
vm.dirty_ratio = 15
```

**MGLRU:** enabled `0x0007` (aging + page-table walks + bloom filters), `min_ttl_ms = 1000`, applied by a oneshot unit at boot.

**DAMON:** `kutu-damon.service` — a dependency-free shell service driving the DAMON sysfs interface directly (no Python `damo` dependency): system-wide monitoring, `DAMOS_PAGEOUT` scheme with free-memory-rate watermarks (acts only under mild pressure, defers to normal reclaim under heavy pressure). Gracefully no-ops if DAMON sysfs is absent.

**systemd-oomd:** Fedora-style config — `ManagedOOMSwap=kill` and PSI-based `ManagedOOMMemoryPressure=kill` on user slices; shell/compositor/XWayland/pipewire units marked `ManagedOOMPreference=avoid`; swap present so oomd has reaction room.

**Journald:** `Storage=volatile`, `RuntimeMaxUse=64M` (tmpfs-resident logs compress under zswap; persistent journal documented as opt-in).

**Per-app cgroups:** `user.slice` gets `MemoryHigh` = 90% RAM (first-boot computed). Heavy shipped apps (Firefox) launch via `kutu-run` → `app-<name>.scope` with per-app profiles from `/etc/kutu/apps.d/*.conf` (`MemoryHighPct`, `MemorySwapMax`, `CPUWeight`, `MemoryMerge`). `kutu-run` resolves percentages against total RAM at launch and invokes `systemd-run --user --scope`. Systemd ≥254's `MemoryMerge=` (KSM per-process opt-in) enabled in Saver mode.

**Firefox autoconfig** (shipped by `kutu-desktop-xfce`): `browser.tabs.unloadOnLowMemory=true`, unload thresholds raised (`browser.low_commit_space_threshold_mb` ≈ RAM/4, `low_commit_space_threshold_pct` ≈ 10) so tab discard fires early rather than last-ditch. Known limitation (source spec A19): Firefox reads `/proc/meminfo`, which is cgroup-blind — native PSI wiring is future upstream work.

**Background hygiene:** XFCE ships no tracker/baloo (A20 free win); no snap/flatpak runtimes on the ISO; no preload.

## 8. `kutu-memoryd` (B2 — desktop TMO)

Single small Rust binary, root systemd service, zero runtime deps (plain std + libc).

**Modes** (user-visible dial; persisted `/etc/kutu/memory.conf`; first-boot auto-selection: <6GB→Saver, 6-16GB→Balanced, >16GB→Performance):

| knob | Saver | Balanced | Performance |
|---|---|---|---|
| vm.swappiness | 150 | 120 | 60 |
| zswap.max_pool_percent | 40 | 35 | 20 |
| MGLRU min_ttl_ms | 3000 | 1000 | 0 |
| DAMON reclaim | aggressive watermarks | gentle | off |
| KSM (+MemoryMerge on wrapped apps) | on, scan-time advisor | off | off |
| Firefox MemoryHigh | 40% RAM | 50% | 70% |
| oomd PSI kill threshold | tighter | Fedora-like | Fedora-like |

**Control loop (v1 — honest hysteresis, no ML):**
- PSI event-driven: registers kernel PSI poll() triggers on `/proc/pressure/memory` (mild/moderate/severe thresholds) plus a 1s stats tick.
- On trigger: adjust `vm.swappiness`, `zswap.max_pool_percent`, DAMON watermarks within ±20% of mode defaults; 10s minimum dwell between changes; changes journaled.
- Sustained severe pressure (`some avg10` > 30% for 30s): write `memory.reclaim` on the top-3 cgroup memory consumers (by `memory.current` among user-app scopes) — never system slices.
- Interactivity SLO (the Senpai/TMO insight): if a reclaim action *worsens* PSI, back off immediately. Reclaim aggressiveness is bounded by measured stall, never tuned blindly.
- Rollback: when PSI recovers below mild for 60s, knobs return to mode defaults.
- Failure safety: if memoryd crashes, systemd restarts it; all mode defaults are also applied statically by `kutu-memory` config files at boot, so the system never depends on the daemon being alive.

**Status API:** `/run/kutu/memoryd.sock` — JSON (mode, effective knobs, PSI series, per-scope top consumers, last actions). Consumed by `kutu-doctor` and the panel applet.

## 9. `mempressured` + `libmempressure` (B4 — Linux onTrimMemory)

**`mempressured`:** standalone D-Bus daemon (Rust, ~500 lines), deliberately decoupled from memoryd — the pitch is a freedesktop standard, so it must stand alone. Bus name `net.kutu.MemoryPressure1` (renamed to org.freedesktop if standardization proceeds). Signal `LevelChanged(s: level)`, property `CurrentLevel`. Levels (Android-modeled, source spec B4):
- `ui-hidden` — session idle/screensaver active
- `background` — `some avg60` > 5%
- `moderate` — `some avg10` > 15% or zswap pool > 80% of cap
- `critical` — `some avg10` > 30% or `full avg10` > 10% (pre-oomd territory)

Storm avoidance: 5s level hysteresis + jittered delivery per subscriber.

**`libmempressure`:** C, ~300 lines. `mp_watch(cb, userdata)` (sd-bus listener thread), `mp_get_level()`, `mp_trim_self()` (malloc_trim + MADV_COLD on own heap). Ships pkg-config, man pages, `kutu-trim` demo CLI.

**v1 reference integrations:** XFCE genmon panel applet (memory health from memoryd.sock + mode switcher), Firefox autoconfig (§7 — tuning-level integration now, native PSI later), `kutu-trim` demo. Electron/JVM/Python runtime patches (B22) are follow-up ecosystem work.

## 10. Desktop & Applications

XFCE 4.20 on X11. Composition: xfce4 (base), thunar, xfce4-terminal, mousepad, ristretto, xfce4-screenshooter, xfce4-power-manager, xfce4-screensaver, lightdm + gtk-greeter, pipewire + wireplumber + pavucontrol, network-manager-applet, blueberry, firefox, noto-fonts + dejavu, kutu branding (existing Greybird-based kutu themes, wallpapers, logos). No office suite/media apps on ISO — space and RAM discipline; installable post-install via pacman (guided by a small "Get Apps" favorites list in thunar bookmarks → wiki).

Firefox and every heavy shipped app launch through `kutu-run` wrapped `.desktop` entries.

Autologin defaults ON (personal-machine positioning; toggleable in installer; password still required for sudo).

## 11. Installer & First Boot

**Calamares** (kutu branding component reusing existing assets), offline install from the live environment:
`welcome` (min 1.5GB RAM check) → `locale` → `keyboard` → `partition` (default: erase-disk, swap = min(RAM,16GiB) floor 4GiB; manual mode available; LUKS optional) → `users` (autologin checkbox, default on) → `unpackfs` (copies live rootfs — installed system is byte-identical to the live env) → `machineid`, `fstab`, `displaymanager` (lightdm + autologin), `grubcfg`, `bootloader` → post-install `shellprocess` (repoint pacman.conf at the live kutu repo URL).

**First boot:** `kutu-firstboot.service` — detect RAM → select + persist mode, compute user.slice MemoryHigh and Firefox MemoryHigh, run `kutu-check-kernel` (degraded-mode notification if features missing), enable oomd/damon/memoryd units, mark done. One-shot, idempotent.

## 12. CI, Releases & Updates

- **`ci.yml`** (PRs): shellcheck/shfmt on scripts, namcap on PKGBUILDs, package builds in `archlinux:base-devel` containers, `cargo test` for Rust packages, C unit tests, config sanity checks (sysctl keys referenced against kernel documentation list).
- **`release.yml`** (tags `v*`): build + sign packages → `repo-add` → deploy pacman repo to gh-pages (`https://kutu-so.github.io/os/repo/x86_64/`, rolling 3-version retention) → `mkarchiso` ISO → sha256 → QEMU smoke test (TCG; asserts: zswap active with zstd/zsmalloc, MGLRU enabled, systemd-oomd + kutu-memoryd + kutu-damon active, lightdm up, `kutu-doctor --status` exit 0, DAMON sysfs present-or-degraded-gracefully) → GitHub Release with ISO + checksums.
- **Local dev:** `make build` unchanged in spirit; plus `make test-vm` (KVM-accelerated QEMU for interactive testing).
- **Release cadence:** tag-driven; ISO named `kutu-os-<version>-x86_64.iso`; M1/M2/M3 each culminate in a tagged release.

## 13. Repository Restructure

```
os/
├── archiso/            # rewritten: XFCE + Calamares desktop profile
├── packages/           # 9 PKGBUILD dirs (§5)
├── configs/            # desktop branding stays; kernel/AI configs removed
├── scripts/            # build/dev/test-vm helpers
├── .github/workflows/  # ci.yml, release.yml
└── docs/               # rewritten for new identity + this spec
```

**Deleted** (git history preserves): `scripts/software/*`, `scripts/drivers/*`, `scripts/build-time-install-software.sh`, `configs/kernel/config-ai-optimized`, `configs/kernel/cmdline.amd|int` (AI-specific), ML docs (`docs/SOFTWARE_CATALOG.md`, `docs/SOFTWARE_INSTALLATION.md`), old `first-boot-setup.sh` ML flow. `configs/systemd/*` and udev rules are revised rather than deleted (I/O scheduler rules survive nearly unchanged). README.md, CLAUDE.md rewritten for the pivot.

## 14. Testing & Verification

- **Unit:** memoryd policy matrix tests (PSI time-series fixtures → expected knob decisions, dwell/hysteresis, SLO back-off); libmempressure C tests; shellcheck/namcap everywhere; PKGBUILD lint in CI.
- **Integration:** CI QEMU smoke test of the live ISO (§12).
- **Installed-system test:** release checklist boots the ISO in QEMU, performs a scripted install (expect-driven Calamares GUI automation, or an equivalent scripted rsync of the live rootfs to a test disk — same unpackfs semantics), boots the installed disk, re-runs the smoke assertions (catches unpackfs/fstab/bootloader regressions).
- **Benchmark harness** (release checklist, source-spec methodology): scripted heavy-multitab Firefox session + idle measures — `some avg60` PSI, pswpin/pswpout, zswap pool stats, before/after comparison against a stock Arch+XFCE baseline ISO. Target evidence: memory-PSI `some avg60` < 5-10% under the scripted session.

## 15. Escape Hatches & Safety

Every intervention must be reversible to stock Arch behavior:
- `kutu-reset` (shipped by `kutu-memory`): stops+disables kutu-damon/memoryd extras, reverts sysctls to defaults, removes grub.d snippet + re-runs grub-mkconfig, sets `lru_gen/enabled=0` (classic LRU), disables zswap — one command, prints what it did.
- `pacman -R kutu-memory kutu-memoryd` leaves a bootable stock-ish XFCE system.
- memoryd knobs are bounded (±20% around mode defaults) and rate-limited; static config-file floors apply even if the daemon dies.
- oomd never targets the shell/compositor/audio path (§7 avoid rules).
- Per the source spec's caveat: a minority of workloads regress under aggressive reclaim — the mode dial (Performance ≈ near-stock) is the user-facing answer, and doctor surfaces the numbers that motivate a switch.

## 16. Milestones

Each milestone ends in a tagged, released ISO.

- **M1 — Foundation & First ISO:** repo restructure; packages `kutu-base`, `kutu-memory`, `kutu-desktop-xfce`, `kutu-calamares-config`, `kutu-keyring`; both CI workflows; smoke test; rewritten docs. *Immediately useful: a tuned, installable, updatable kutu desktop.*
- **M2 — Visibility & Policy:** `kutu-memoryd` full control loop + modes + socket API; `kutu-doctor` TUI + `--fix`; `kutu-reset`.
- **M3 — Cooperative Apps:** `mempressured`, `libmempressure`, `kutu-trim`; XFCE genmon applet; Firefox autoconfig integration; KSM/MemoryMerge Saver path.

## 17. Decisions Log

| # | Decision | Rationale |
|---|---|---|
| D1 | Full pivot; ML files deleted (history preserved) | "fuck ML, lets build for resource optimization" |
| D2 | Security mitigations stay ON | Non-technical users browse the web; old `mitigations=off` was appliance-only |
| D3 | Autologin default ON | Personal-machine "lifesaver" positioning; installer toggle |
| D4 | 3 sequenced milestones inside v1 | Never months-from-ISO; M2/M3 roll out as package updates |
| D5 | zswap over zram (NVMe swap behind it) | Source spec's desktop recommendation; composable, cgroup-accounted, shrinker-tiers to disk |
| D6 | Stock Arch kernel, no custom build in v1 | All Tier 0/1 is mainline + runtime-tunable; custom kernel only as fallback |
| D7 | XFCE on X11 | ~400-500MB idle, stability for non-technical users; Wayland revisit post-v1 |
| D8 | Package-first architecture | Updates via `pacman -Syu` are native, not bolted on |
| D9 | Repo signing in M1 (slippable to M2, not past v1) | Supply-chain safety for non-technical users |
| D10 | Per-app resource GUI = sibling project `../resources` | Right scope boundary; kutu OS will ship it as a package when it exists |

## 18. Out of Scope / Deferred

- **`../resources`** — per-app cgroup resource-manager GUI (idea doc created there).
- `linux-kutu` custom kernel with B6 curated swap patches (mTHP swap allocator etc. — most already merged in current Arch kernels; rest tracked upstream).
- zram-only flavor; Wayland session; ARM; B7 LLM KV-cache tiering; B12 Electron shared runtime; B15 codec tuning; all Tier-3 research items.
- Firefox native PSI integration (upstream ecosystem effort; autoconfig covers v1).

## 19. Risks & Mitigations

| Risk | Mitigation |
|---|---|
| Workload incompressibility (media, encrypted data) | Doctor surfaces zswap compression ratio per machine; mode dial + `kutu-reset`; spec's incompressible-page handling lands upstream over time |
| ISO > 2GiB GitHub asset limit | zstd squashfs, tight package list, selective firmware; fallback: external hosting for ISO assets |
| QEMU smoke test slow on CI (no KVM) | Runs only on tag/release workflow; PRs get package-level tests only |
| DAMON/feature gaps in future kernels | `kutu-check-kernel` prober + graceful degradation + `linux-kutu` fallback path documented |
| memoryd misbehavior | Bounded knobs, rate limits, static-file floors, systemd restart, `kutu-reset`, Performance mode ≈ stock |
| Calamares unpackfs divergence | Installed-system boot test in release checklist |
| gh-pages repo bandwidth/limits | Packages are small; ISO never served from gh-pages |
| Unsigned repo window (if D9 slips) | Time-boxed; never past v1 |
| Trim-storms / oomd killing wrong things | Hysteresis + jitter (§9); ManagedOOMPreference avoid rules (§7); tested in smoke suite |
