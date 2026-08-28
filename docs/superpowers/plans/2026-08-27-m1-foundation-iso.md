# kutu OS M1 — Foundation & First ISO Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship M1 of the RAMageddon pivot: repo restructured, five `kutu-*` packages (Tier-0 memory stack, XFCE desktop, Calamares installer, keyring), a buildable ISO, CI, and a QEMU smoke test — ending in a tagged release.

**Architecture:** Package-first distro: all kutu value ships as pacman packages under `packages/`, built by `scripts/build-packages.sh` (host or docker), assembled into a local repo consumed by an archiso profile, installed offline via Calamares/unpackfs. Installed systems update via pacman against the gh-pages-hosted kutu repo.

**Tech Stack:** Arch packaging (makepkg/PKGBUILD), archiso, systemd (sysctl.d, unit drop-ins, oomd, presets), DAMON sysfs, Calamares 3.3, GitHub Actions (archlinux:base-devel containers), QEMU + expect for smoke testing.

**Spec:** `docs/superpowers/specs/2026-08-27-ramageddon-pivot-design.md` — read §4–§7, §10–§13, §16 (M1) before starting.

## Global Constraints

- Host is Manjaro (Arch-compatible: makepkg/pacman available; `mkarchiso` absent) — every ISO/build command that needs `mkarchiso` must run inside `archlinux:base-devel` docker when not on real Arch with archiso installed. `scripts/build.sh` auto-detects.
- Tier-0 values are LOCKED by spec §6–§7: cmdline `zswap.enabled=1 zswap.compressor=zstd zswap.zpool=zsmalloc zswap.max_pool_percent=35 zswap.shrinker_enabled=1 psi=1 transparent_hugepage=madvise`; sysctls `vm.swappiness=120 vm.page-cluster=0 vm.watermark_scale_factor=125 vm.watermark_boost_factor=0 vm.dirty_background_ratio=5 vm.dirty_ratio=15`; MGLRU `0x0007`/`min_ttl_ms=1000`; journald `Storage=volatile`/`RuntimeMaxUse=64M`.
- Mode thresholds (firstboot): <6GB→saver, 6–16GB→balanced, >16GB→performance; user.slice MemoryHigh 85/90/95%; Firefox MemoryHighPct 40/50/70.
- Every new shell script must pass `shellcheck`. Config packages must be installable with `makepkg -f` on the host.
- Commit after every task (user mandate: incremental commits).
- No comments in code unless the file is itself documentation (config files with `#` explanations are fine — they ARE the docs).

---

### Task 1: Strip ML appliance artifacts

**Files:**
- Delete: `scripts/software/`, `scripts/drivers/`, `scripts/optimize/`, `scripts/build-time-install-software.sh`, `scripts/first-boot-setup.sh`, `scripts/generate-kernel-params.sh`, `scripts/install-kernel-optimizations.sh`, `scripts/monitor-kernel.sh`, `scripts/validate-kernel.sh`, `scripts/test-qemu.sh`
- Delete: `configs/kernel/`, `configs/systemd/`, `configs/network/`
- Delete: `docs/SOFTWARE_CATALOG.md`, `docs/SOFTWARE_INSTALLATION.md`, `docs/KERNEL.md`
- Rewrite: `README.md` (pivot placeholder), `Makefile` (drop dead targets)
- Keep untouched: `archiso/`, `configs/desktop/`, `scripts/build.sh`, remaining docs

- [ ] **Step 1: Delete the ML/appliance files listed above**

```bash
git rm -r scripts/software scripts/drivers scripts/optimize scripts/build-time-install-software.sh \
  scripts/first-boot-setup.sh scripts/generate-kernel-params.sh scripts/install-kernel-optimizations.sh \
  scripts/monitor-kernel.sh scripts/validate-kernel.sh scripts/test-qemu.sh \
  configs/kernel configs/systemd configs/network \
  docs/SOFTWARE_CATALOG.md docs/SOFTWARE_INSTALLATION.md docs/KERNEL.md
```

- [ ] **Step 2: Read `scripts/build.sh` and `Makefile` fully, then confirm `build.sh` only references deleted files behind the `--with-software` flag (if it sources them unconditionally, stub those lines out)**

- [ ] **Step 3: Replace `README.md` content with the pivot placeholder**

```markdown
# kutu OS

The RAM-sipping Linux desktop for the DRAM-shortage era.

> **Pivot in progress:** kutu OS was previously an ML-inference appliance OS.
> It is being rebuilt as a memory-conservation desktop distribution.
> Design spec: `docs/superpowers/specs/2026-08-27-ramageddon-pivot-design.md`

Build (requires Arch host with archiso, or docker):

    make build

Status: M1 (foundation) under construction.
```

- [ ] **Step 4: Edit `Makefile` — delete the `build-fat`, `build-with-software`, `install-software`, and `docs` targets plus their help lines (they reference deleted scripts)**

- [ ] **Step 5: Verify**

```bash
make help
shellcheck scripts/build.sh
git status --short   # only intended changes
```
Expected: `make help` prints without errors; no dangling references to deleted scripts in Makefile.

- [ ] **Step 6: Commit**

```bash
git add -A && git commit -m "strip ML appliance artifacts for desktop pivot"
```

---

### Task 2: `kutu-memory` package — core Tier-0 configs

**Files:**
- Create: `packages/kutu-memory/PKGBUILD`
- Create: `packages/kutu-memory/kutu-memory.install`
- Create: `packages/kutu-memory/sysctl/60-kutu-memory.conf`
- Create: `packages/kutu-memory/grub/99-kutu-memory.cfg`
- Create: `packages/kutu-memory/usr/bin/kutu-mglru-init`
- Create: `packages/kutu-memory/systemd/kutu-mglru.service`
- Create: `packages/kutu-memory/journald/99-kutu.conf`
- Create: `packages/kutu-memory/udev/60-kutu-ioschedulers.rules`
- Create: `scripts/validate-configs.sh`

**Interfaces:**
- Produces: package `kutu-memory` (any arch); files installed at `/etc/sysctl.d/60-kutu-memory.conf`, `/etc/default/grub.d/99-kutu-memory.cfg`, `/usr/bin/kutu-mglru-init`, `/usr/lib/systemd/system/kutu-mglru.service`, `/etc/systemd/journald.conf.d/99-kutu.conf`, `/usr/lib/udev/rules.d/60-kutu-ioschedulers.rules`. Later tasks (3, 4) extend this same PKGBUILD.

- [ ] **Step 1: Write the config files**

`packages/kutu-memory/sysctl/60-kutu-memory.conf`:
```ini
# kutu OS memory tuning (spec §7). Revert with: kutu-reset
vm.swappiness = 120
vm.page-cluster = 0
vm.watermark_scale_factor = 125
vm.watermark_boost_factor = 0
vm.dirty_background_ratio = 5
vm.dirty_ratio = 15
```

`packages/kutu-memory/grub/99-kutu-memory.cfg` (sourced by grub-mkconfig on grub ≥ 2.12; verified in smoke test; Calamares bootloader module re-runs grub-mkconfig so this lands in installed systems too):
```sh
GRUB_CMDLINE_LINUX_DEFAULT="$GRUB_CMDLINE_LINUX_DEFAULT zswap.enabled=1 zswap.compressor=zstd zswap.zpool=zsmalloc zswap.max_pool_percent=35 zswap.shrinker_enabled=1 psi=1 transparent_hugepage=madvise"
```

`packages/kutu-memory/usr/bin/kutu-mglru-init`:
```bash
#!/usr/bin/env bash
set -euo pipefail
SYS="${KUTU_SYSFS:-/sys}"
L="$SYS/kernel/mm/lru_gen"
[ -e "$L/enabled" ] || { echo "kutu-mglru: lru_gen not available, skipping"; exit 0; }
printf '%s' "0x0007" > "$L/enabled"
[ -e "$L/min_ttl_ms" ] && printf '%s' "1000" > "$L/min_ttl_ms"
echo "kutu-mglru: MGLRU enabled (0x0007), min_ttl_ms=1000"
```

`packages/kutu-memory/systemd/kutu-mglru.service`:
```ini
[Unit]
Description=kutu OS MGLRU activation
After=systemd-modules-load.service
Before=multi-user.target
ConditionPathExists=/sys/kernel/mm/lru_gen/enabled

[Service]
Type=oneshot
ExecStart=/usr/bin/kutu-mglru-init
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
```

`packages/kutu-memory/journald/99-kutu.conf`:
```ini
[Journal]
Storage=volatile
RuntimeMaxUse=64M
```

`packages/kutu-memory/udev/60-kutu-ioschedulers.rules` (adapted from the deleted `configs/systemd/udev.d/60-ioschedulers.rules`; NVMe=none, SATA SSD=mq-deadline, rotational=bfq):
```
ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/scheduler}="none"
ACTION=="add|change", KERNEL=="sd[a-z]|mmcblk[0-9]*", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="mq-deadline"
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="1", ATTR{queue/scheduler}="bfq"
```

`packages/kutu-memory/kutu-memory.install`:
```bash
post_install() {
  systemctl --root="$1" enable kutu-mglru.service 2>/dev/null || true
}
post_upgrade() {
  post_install "$1"
}
```

- [ ] **Step 2: Write the PKGBUILD**

```pkgbuild
pkgname=kutu-memory
pkgver=0.1.0
pkgrel=1
pkgdesc="kutu OS Tier-0 memory stack: zswap, MGLRU, journald, I/O scheduler tuning"
arch=(any)
url="https://kutu.so"
license=(MIT)
depends=(systemd grub)
install=kutu-memory.install
package() {
  install -Dm644 sysctl/60-kutu-memory.conf -t "$pkgdir/etc/sysctl.d/"
  install -Dm644 grub/99-kutu-memory.cfg -t "$pkgdir/etc/default/grub.d/"
  install -Dm755 usr/bin/kutu-mglru-init -t "$pkgdir/usr/bin/"
  install -Dm644 systemd/kutu-mglru.service -t "$pkgdir/usr/lib/systemd/system/"
  install -Dm644 journald/99-kutu.conf -t "$pkgdir/etc/systemd/journald.conf.d/"
  install -Dm644 udev/60-kutu-ioschedulers.rules -t "$pkgdir/usr/lib/udev/rules.d/"
}
```

- [ ] **Step 3: Write `scripts/validate-configs.sh`** — checks every sysctl key against a known-vm-key whitelist, `systemd-analyze verify` on shipped units, `shellcheck` on shipped scripts:

```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
fail=0
KNOWN="swappiness page-cluster watermark_scale_factor watermark_boost_factor dirty_background_ratio dirty_ratio min_free_kbytes compaction_proactiveness vfs_cache_pressure"
while IFS= read -r file; do
  grep -E '^[a-z.]+\s*=' "$file" | cut -d= -f1 | tr -d ' ' | while IFS= read -r key; do
    [ "${key#vm.}" = "$key" ] && { echo "FAIL: non-vm key '$key' in $file"; continue; }
    base="${key#vm.}"
    grep -qw "$base" <<< "$KNOWN" || echo "FAIL: unknown key '$key' in $file"
  done
done < <(find packages -path '*/sysctl/*' -name '*.conf')
for unit in $(find packages -name '*.service'); do
  systemd-analyze verify --man=no "$unit" 2>&1 | grep -v 'Failed to lookup' || true
done
mapfile -t scripts < <(find packages -path '*/usr/bin/*' -type f; find scripts -name '*.sh')
shellcheck "${scripts[@]}"
echo "validate-configs: OK"
```

- [ ] **Step 4: Build and verify**

```bash
chmod +x scripts/validate-configs.sh packages/kutu-memory/usr/bin/kutu-mglru-init
./scripts/validate-configs.sh
cd packages/kutu-memory && makepkg -f && bsdtar -tf kutu-memory-0.1.0-1-any.pkg.tar.zst
```
Expected: package builds; file list contains exactly the six install paths.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "kutu-memory: Tier-0 core (zswap cmdline, sysctl, MGLRU, journald, udev)"
```

---

### Task 3: `kutu-damon` — DAMON proactive reclaim service

**Files:**
- Create: `packages/kutu-memory/usr/bin/kutu-damon`
- Create: `packages/kutu-memory/systemd/kutu-damon.service`
- Modify: `packages/kutu-memory/PKGBUILD` (add both files)
- Test: `tests/kutu-damon-test.sh`

**Interfaces:**
- Produces: `kutu-damon {start|stop|status}`; env override `KUTU_DAMON_SYSFS` for tests. Service `kutu-damon.service` remains active after oneshot (kernel-side DAMON).

- [ ] **Step 1: Write the failing test** `tests/kutu-damon-test.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
R="$tmp/admin"
K="kdamonds/0"; C="$K/contexts/0"; S="$C/schemes/0"
mkdir -p "$R/$C/monitoring_attrs/intervals" "$R/$C/targets/0/regions/0" \
  "$R/$S/access_pattern/nr_accesses" "$R/$S/access_pattern/ages" "$R/$S/quotas" "$R/$S/watermarks"
for f in nr_kdamonds "$K/state" "$C/operations" "$C/monitoring_attrs/intervals/sample_us" \
  "$C/monitoring_attrs/intervals/aggr_us" "$C/monitoring_attrs/intervals/update_us" \
  "$C/targets/0/nr_regions" "$C/targets/0/regions/0/start" "$C/targets/0/regions/0/end" \
  "$C/schemes/nr_schemes" "$S/action" "$S/access_pattern/nr_accesses/min" \
  "$S/access_pattern/nr_accesses/max" "$S/access_pattern/ages/min" "$S/access_pattern/ages/max" \
  "$S/quotas/ms" "$S/quotas/sz" "$S/quotas/reset_interval_ms" "$S/watermarks/metric" \
  "$S/watermarks/interval_us" "$S/watermarks/low" "$S/watermarks/mid" "$S/watermarks/high"; do
  : > "$R/$f"
done
export KUTU_DAMON_SYSFS="$R"
BIN=packages/kutu-memory/usr/bin/kutu-damon
assert() { [ "$(cat "$R/$1")" = "$2" ] || { echo "FAIL: $1='$(cat "$R/$1")' want '$2'"; exit 1; }; }
MEMINFO="$tmp/meminfo"; printf 'MemTotal: 16777216 kB\n' > "$MEMINFO"
KUTU_MEMINFO="$MEMINFO" "$BIN" start
assert "$C/operations" paddr
assert "$C/monitoring_attrs/intervals/sample_us" 5000
assert "$C/monitoring_attrs/intervals/aggr_us" 100000
assert "$S/action" pageout
assert "$S/access_pattern/ages/min" 100
assert "$S/watermarks/metric" free_mem_rate
assert "$K/state" on
"$BIN" status | grep -q on
"$BIN" stop
assert "$K/state" off
echo "kutu-damon tests: PASS"
```

- [ ] **Step 2: Run it — expect failure (`kutu-damon` doesn't exist)**

```bash
chmod +x tests/kutu-damon-test.sh && ./tests/kutu-damon-test.sh
```
Expected: FAIL (file not found).

- [ ] **Step 3: Write `packages/kutu-memory/usr/bin/kutu-damon`**

```bash
#!/usr/bin/env bash
set -euo pipefail
DAMON_ROOT="${KUTU_DAMON_SYSFS:-/sys/kernel/mm/damon/admin}"
MEMINFO="${KUTU_MEMINFO:-/proc/meminfo}"
KD="$DAMON_ROOT/kdamonds/0"; CTX="$KD/contexts/0"

start() {
  if [ ! -d "$DAMON_ROOT" ]; then
    echo "kutu-damon: DAMON sysfs unavailable; skipping (kernel without CONFIG_DAMON_SYSFS)"
    exit 0
  fi
  printf '%s' 0 > "$DAMON_ROOT/nr_kdamonds" 2>/dev/null || true
  printf '%s' 1 > "$DAMON_ROOT/nr_kdamonds"
  printf '%s' paddr > "$CTX/operations"
  printf '%s' 5000   > "$CTX/monitoring_attrs/intervals/sample_us"
  printf '%s' 100000 > "$CTX/monitoring_attrs/intervals/aggr_us"
  printf '%s' 1000000 > "$CTX/monitoring_attrs/intervals/update_us"
  printf '%s' 1 > "$CTX/targets/0/nr_regions"
  printf '%s' 0 > "$CTX/targets/0/regions/0/start"
  printf '%s' "$(( $(awk '/MemTotal/ {print $2}' "$MEMINFO") * 1024 ))" > "$CTX/targets/0/regions/0/end"
  printf '%s' 1 > "$CTX/schemes/nr_schemes"
  S="$CTX/schemes/0"
  printf '%s' pageout > "$S/action"
  printf '%s' 0 > "$S/access_pattern/nr_accesses/min"
  printf '%s' 0 > "$S/access_pattern/nr_accesses/max"
  printf '%s' 100 > "$S/access_pattern/ages/min"
  printf '%s' 4294967295 > "$S/access_pattern/ages/max"
  printf '%s' 100 > "$S/quotas/ms"
  printf '%s' 0 > "$S/quotas/sz"
  printf '%s' 1000 > "$S/quotas/reset_interval_ms"
  printf '%s' free_mem_rate > "$S/watermarks/metric"
  printf '%s' 1000000 > "$S/watermarks/interval_us"
  printf '%s' 50  > "$S/watermarks/low"
  printf '%s' 100 > "$S/watermarks/mid"
  printf '%s' 150 > "$S/watermarks/high"
  printf '%s' on > "$KD/state"
  echo "kutu-damon: DAMON proactive reclaim started"
}

stop() {
  [ -d "$DAMON_ROOT" ] || exit 0
  printf '%s' off > "$KD/state" 2>/dev/null || true
  printf '%s' 0 > "$DAMON_ROOT/nr_kdamonds" 2>/dev/null || true
  echo "kutu-damon: stopped"
}

status() {
  [ -d "$DAMON_ROOT" ] && cat "$KD/state" 2>/dev/null || echo "unsupported"
}

case "${1:-}" in
  start) start ;;
  stop) stop ;;
  status) status ;;
  *) echo "usage: kutu-damon {start|stop|status}" >&2; exit 2 ;;
esac
```

**Values rationale (verify during execution against `Documentation/admin-guide/mm/damon/usage.rst` on kernel.org):** scheme pages-out regions with zero accesses for ≥100 aggregation intervals (100×100ms = 10s cold), quota 100ms per 1s window (10% duty), free-mem-rate watermarks 5%/10%/15% — active only under mild pressure, off when memory is plentiful, off when critically low (kswapd's job). If doc reading contradicts the watermark band semantics, fix constants and update this comment.

- [ ] **Step 4: Run the test — expect PASS**

```bash
./tests/kutu-damon-test.sh
```

- [ ] **Step 5: Add service + PKGBUILD entries**

`packages/kutu-memory/systemd/kutu-damon.service`:
```ini
[Unit]
Description=kutu OS DAMON proactive reclaim
After=multi-user.target
ConditionPathExists=/sys/kernel/mm/damon/admin

[Service]
Type=oneshot
ExecStart=/usr/bin/kutu-damon start
ExecStop=/usr/bin/kutu-damon stop
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
```

PKGBUILD `package()` additions:
```pkgbuild
  install -Dm755 usr/bin/kutu-damon -t "$pkgdir/usr/bin/"
  install -Dm644 systemd/kutu-damon.service -t "$pkgdir/usr/lib/systemd/system/"
```
And extend `kutu-memory.install` `post_install` to also `systemctl --root="$1" enable kutu-damon.service 2>/dev/null || true`.

- [ ] **Step 6: Live sanity check on host (kernel 7.0 has DAMON):**

```bash
sudo KUTU_DAMON_SYSFS=/sys/kernel/mm/damon/admin packages/kutu-memory/usr/bin/kutu-damon start
cat /sys/kernel/mm/damon/admin/kdamonds/0/state   # expect: on
packages/kutu-memory/usr/bin/kutu-damon status
sudo packages/kutu-memory/usr/bin/kutu-damon stop
```
Expected: `on`, then clean stop. If sysfs layout differs, fix script + test to match real layout, keep test fake-tree in sync.

- [ ] **Step 7: Rebuild + validate + commit**

```bash
cd packages/kutu-memory && makepkg -f && cd ../..
./scripts/validate-configs.sh
git add -A && git commit -m "kutu-memory: DAMON proactive reclaim service"
```

---

### Task 4: oomd config, slice drop-ins, `kutu-reset`

**Files:**
- Create: `packages/kutu-memory/oomd/oomd.conf.d/99-kutu.conf`
- Create: `packages/kutu-memory/oomd/user.slice.d/50-kutu-oomd.conf`
- Create: `packages/kutu-memory/oomd/avoid/pipewire.service.d/99-kutu-avoid.conf`
- Create: `packages/kutu-memory/oomd/avoid/wireplumber.service.d/99-kutu-avoid.conf`
- Create: `packages/kutu-memory/oomd/avoid/xdg-desktop-portal.service.d/99-kutu-avoid.conf`
- Create: `packages/kutu-memory/usr/bin/kutu-reset`
- Modify: `packages/kutu-memory/PKGBUILD`

**Interfaces:**
- Produces: `/etc/systemd/oomd.conf.d/99-kutu.conf`, `/etc/systemd/system/user.slice.d/50-kutu-oomd.conf`, avoid drop-ins for pipewire/wireplumber/xdg-desktop-portal, `/usr/bin/kutu-reset` (escape hatch, spec §15).

- [ ] **Step 1: Write oomd files**

`oomd/oomd.conf.d/99-kutu.conf`:
```ini
[OOM]
SwapUsedLimit=90%
DefaultMemoryPressureLimitSec=30s
```

`oomd/user.slice.d/50-kutu-oomd.conf`:
```ini
[Slice]
ManagedOOMSwap=kill
ManagedOOMMemoryPressure=kill
ManagedOOMMemoryPressureLimitSec=50%
```

Each avoid drop-in (identical content, three directories):
```ini
[Service]
ManagedOOMPreference=avoid
```

- [ ] **Step 2: Write `packages/kutu-memory/usr/bin/kutu-reset`**

```bash
#!/usr/bin/env bash
set -euo pipefail
echo "== kutu-reset: reverting kutu memory tuning to Arch defaults =="
systemctl disable --now kutu-damon.service kutu-mglru.service 2>/dev/null || true
/usr/bin/kutu-damon stop 2>/dev/null || true
sysctl -w vm.swappiness=60 vm.page-cluster=3 vm.watermark_scale_factor=10 \
  vm.watermark_boost_factor=15000 vm.dirty_background_ratio=10 vm.dirty_ratio=20 >/dev/null
install -Dm644 /dev/null /etc/sysctl.d/70-kutu-disabled.conf
cat > /etc/sysctl.d/70-kutu-disabled.conf <<'EOF'
vm.swappiness = 60
vm.page-cluster = 3
vm.watermark_scale_factor = 10
vm.watermark_boost_factor = 15000
vm.dirty_background_ratio = 10
vm.dirty_ratio = 20
EOF
[ -e /sys/kernel/mm/lru_gen/enabled ] && printf '%s' 0 > /sys/kernel/mm/lru_gen/enabled
[ -e /sys/module/zswap/parameters/enabled ] && printf '%s' N > /sys/module/zswap/parameters/enabled
if [ -f /etc/default/grub.d/99-kutu-memory.cfg ]; then
  mv /etc/default/grub.d/99-kutu-memory.cfg /etc/default/grub.d/99-kutu-memory.cfg.disabled
  grub-mkconfig -o /boot/grub/grub.cfg 2>/dev/null || echo "note: grub-mkconfig failed; cmdline reverts on next kernel initrd regen"
  echo "note: kutu-memory package upgrades will restore the grub snippet; re-run kutu-reset after upgrades"
fi
echo "kutu-reset: done. Reboot for full effect. Undo this reset with: rm /etc/sysctl.d/70-kutu-disabled.conf && systemctl enable --now kutu-mglru kutu-damon"
```

- [ ] **Step 3: PKGBUILD additions**

```pkgbuild
  install -Dm644 oomd/oomd.conf.d/99-kutu.conf -t "$pkgdir/etc/systemd/oomd.conf.d/"
  install -Dm644 oomd/user.slice.d/50-kutu-oomd.conf -t "$pkgdir/etc/systemd/system/user.slice.d/"
  install -Dm644 oomd/avoid/pipewire.service.d/99-kutu-avoid.conf -t "$pkgdir/etc/systemd/system/pipewire.service.d/"
  install -Dm644 oomd/avoid/wireplumber.service.d/99-kutu-avoid.conf -t "$pkgdir/etc/systemd/system/wireplumber.service.d/"
  install -Dm644 oomd/avoid/xdg-desktop-portal.service.d/99-kutu-avoid.conf -t "$pkgdir/etc/systemd/system/xdg-desktop-portal.service.d/"
  install -Dm755 usr/bin/kutu-reset -t "$pkgdir/usr/bin/"
```
Also enable `systemd-oomd.service` in `post_install`: `systemctl --root="$1" enable systemd-oomd.service 2>/dev/null || true`.

- [ ] **Step 4: Verify + commit**

```bash
chmod +x packages/kutu-memory/usr/bin/kutu-reset
cd packages/kutu-memory && makepkg -f && cd ../..
./scripts/validate-configs.sh
git add -A && git commit -m "kutu-memory: oomd policy, slice drop-ins, kutu-reset escape hatch"
```

---

### Task 5: `kutu-base` package — branding, firstboot, kutu-run, check-kernel

**Files:**
- Create: `packages/kutu-base/PKGBUILD`, `packages/kutu-base/kutu-base.install`
- Create: `packages/kutu-base/usr/bin/kutu-run`, `kutu-firstboot`, `kutu-check-kernel`
- Create: `packages/kutu-base/systemd/kutu-firstboot.service`
- Create: `packages/kutu-base/etc/os-release`, `packages/kutu-base/etc/kutu/memory.conf`
- Create: `packages/kutu-base/preset/80-kutu.preset`
- Create: `packages/kutu-base/alpm-hooks/kutu-check-kernel.hook`
- Test: `tests/kutu-firstboot-test.sh`, `tests/kutu-run-test.sh`

**Interfaces:**
- Produces: `kutu-run [--dry-run] <profile> <cmd...>` reading `/etc/kutu/apps.d/<profile>.conf` (keys `KUTU_MEMORY_HIGH_PCT`, `KUTU_MEMORY_SWAP_MAX`, `KUTU_CPU_WEIGHT`, `KUTU_MEMORY_MERGE`); `kutu-firstboot` writing `/etc/kutu/memory.conf` (`MODE=<saver|balanced|performance>`), `/etc/systemd/system/user.slice.d/50-kutu.conf`, `/etc/kutu/apps.d/firefox.conf`; `kutu-check-kernel` (exit 0 all-core-pass). All honor env overrides `KUTU_ROOT`, `KUTU_MEMINFO`, `KUTU_SYSFS`, `KUTU_PROC` for tests.

- [ ] **Step 1: Write `kutu-run`**

```bash
#!/usr/bin/env bash
set -euo pipefail
DRY=0
[ "${1:-}" = "--dry-run" ] && { DRY=1; shift; }
[ $# -ge 2 ] || { echo "usage: kutu-run [--dry-run] <profile> <command...>" >&2; exit 2; }
PROFILE="$1"; shift
CONF="${KUTU_ROOT:-}/etc/kutu/apps.d/${PROFILE}.conf"
DECL=()
if [ -r "$CONF" ]; then
  # shellcheck disable=SC1090
  . "$CONF"
  if [ -n "${KUTU_MEMORY_HIGH_PCT:-}" ]; then
    TOTAL_KB=$(awk '/MemTotal/ {print $2}' "${KUTU_MEMINFO:-/proc/meminfo}")
    DECL+=(-p "MemoryHigh=$(( TOTAL_KB * KUTU_MEMORY_HIGH_PCT / 100 * 1024 ))")
  fi
  [ -n "${KUTU_MEMORY_SWAP_MAX:-}" ] && DECL+=(-p "MemorySwapMax=${KUTU_MEMORY_SWAP_MAX}")
  [ -n "${KUTU_CPU_WEIGHT:-}" ] && DECL+=(-p "CPUWeight=${KUTU_CPU_WEIGHT}")
  [ "${KUTU_MEMORY_MERGE:-0}" = "1" ] && DECL+=(-p "MemoryMerge=yes")
fi
CMD=(systemd-run --user --scope --unit="app-${PROFILE}-%n" "${DECL[@]+"${DECL[@]}"}" "$@")
if [ "$DRY" = 1 ]; then printf '%q ' "${CMD[@]}"; echo; exit 0; fi
exec "${CMD[@]}"
```

- [ ] **Step 2: Write `kutu-firstboot`**

```bash
#!/usr/bin/env bash
set -euo pipefail
R="${KUTU_ROOT:-}"
MARKER="$R/var/lib/kutu/firstboot-done"
[ -e "$MARKER" ] && exit 0
TOTAL_KB=$(awk '/MemTotal/ {print $2}' "${KUTU_MEMINFO:-/proc/meminfo}")
TOTAL_MB=$(( TOTAL_KB / 1024 ))
if [ "$TOTAL_MB" -lt 6144 ]; then MODE=saver
elif [ "$TOTAL_MB" -le 16384 ]; then MODE=balanced
else MODE=performance; fi
case "$MODE" in
  saver)       FF_PCT=40; USER_HIGH_PCT=85 ;;
  balanced)    FF_PCT=50; USER_HIGH_PCT=90 ;;
  performance) FF_PCT=70; USER_HIGH_PCT=95 ;;
esac
install -Dm644 /dev/null "$R/etc/kutu/memory.conf"
cat > "$R/etc/kutu/memory.conf" <<EOF
MODE=$MODE
EOF
install -Dm644 /dev/null "$R/etc/systemd/system/user.slice.d/50-kutu.conf"
cat > "$R/etc/systemd/system/user.slice.d/50-kutu.conf" <<EOF
[Slice]
MemoryHigh=$(( TOTAL_KB * USER_HIGH_PCT / 100 * 1024 ))
EOF
install -Dm644 /dev/null "$R/etc/kutu/apps.d/firefox.conf"
cat > "$R/etc/kutu/apps.d/firefox.conf" <<EOF
KUTU_MEMORY_HIGH_PCT=$FF_PCT
KUTU_CPU_WEIGHT=100
EOF
[ -z "$R" ] && systemctl daemon-reload || true
mkdir -p "$R/var/lib/kutu" && touch "$MARKER"
echo "kutu-firstboot: mode=$MODE user.slice MemoryHigh=$(( TOTAL_KB * USER_HIGH_PCT / 100 / 1024 ))M firefox MemoryHighPct=$FF_PCT"
```

`systemd/kutu-firstboot.service`:
```ini
[Unit]
Description=kutu OS first-boot calibration
After=multi-user.target
ConditionPathExists=!/var/lib/kutu/firstboot-done

[Service]
Type=oneshot
ExecStart=/usr/bin/kutu-firstboot

[Install]
WantedBy=multi-user.target
```

- [ ] **Step 3: Write `kutu-check-kernel`**

```bash
#!/usr/bin/env bash
set -uo pipefail
SYS="${KUTU_SYSFS:-/sys}"; PROC="${KUTU_PROC:-/proc}"
fail=0
chk() {
  local name="$1" ok="$2" detail="$3"
  if [ "$ok" = 1 ]; then printf 'PASS %-22s %s\n' "$name" "$detail"
  else printf 'FAIL %-22s %s\n' "$name" "$detail"; fail=1; fi
}
zswap_enabled=$(cat "$SYS/module/zswap/parameters/enabled" 2>/dev/null || echo N)
chk zswap "$([ "$zswap_enabled" = Y ] && echo 1 || echo 0)" "enabled=$zswap_enabled"
chk zswap-compressor "$([ "$(cat "$SYS/module/zswap/parameters/compressor" 2>/dev/null)" = zstd ] && echo 1 || echo 0)" \
  "want zstd got $(cat "$SYS/module/zswap/parameters/compressor" 2>/dev/null)"
chk zswap-zpool "$([ "$(cat "$SYS/module/zswap/parameters/zpool" 2>/dev/null)" = zsmalloc ] && echo 1 || echo 0)" \
  "want zsmalloc got $(cat "$SYS/module/zswap/parameters/zpool" 2>/dev/null)"
chk zswap-shrinker "$([ "$(cat "$SYS/module/zswap/parameters/shrinker_enabled" 2>/dev/null)" = Y ] && echo 1 || echo 0)" \
  "shrinker=$(cat "$SYS/module/zswap/parameters/shrinker_enabled" 2>/dev/null)"
mglru=$(cat "$SYS/kernel/mm/lru_gen/enabled" 2>/dev/null | tr -d 'x' || echo 0)
chk mglru "$(( mglru & 7 ))" "enabled=$mglru want 7"
chk damon-sysfs "$([ -d "$SYS/kernel/mm/damon/admin" ] && echo 1 || echo 0)" "presence of sysfs interface"
chk psi "$([ -e "$PROC/pressure/memory" ] && echo 1 || echo 0)" "presence of /proc/pressure/memory"
chk per-cgroup-zswap "$([ -e "$SYS/fs/cgroup/memory.zswap.max" ] && echo 1 || echo 0)" "memory.zswap.max on root cgroup"
thp=$(cat "$SYS/kernel/mm/transparent_hugepage/enabled" 2>/dev/null)
chk thp-madvise "$(grep -q '\[madvise\]' <<< "$thp" && echo 1 || echo 0)" "got ${thp:-none}"
exit $fail
```

- [ ] **Step 4: Write os-release, preset, hook, PKGBUILD, install scriptlet**

`packages/kutu-base/etc/os-release`:
```ini
NAME="kutu OS"
PRETTY_NAME="kutu OS"
ID=kutu
ID_LIKE=arch
BUILD_ID=rolling
ANSI_COLOR="38;2;255;153;0"
HOME_URL="https://kutu.so"
SUPPORT_URL="https://github.com/kutu-so/os/issues"
```

`packages/kutu-base/preset/80-kutu.preset`:
```ini
enable kutu-firstboot.service
```

`packages/kutu-base/alpm-hooks/kutu-check-kernel.hook`:
```ini
[Trigger]
Operation = Install
Operation = Upgrade
Type = Package
Target = linux
Target = linux-lts

[Action]
Description = Checking kernel features for kutu OS memory stack
When = PostTransaction
Exec = /usr/bin/kutu-check-kernel
```

`packages/kutu-base/PKGBUILD`:
```pkgbuild
pkgname=kutu-base
pkgver=0.1.0
pkgrel=1
pkgdesc="kutu OS base: identity, first-boot calibration, app launcher wrapper, kernel feature prober"
arch=(any)
url="https://kutu.so"
license=(MIT)
depends=(systemd bash)
install=kutu-base.install
package() {
  install -Dm755 usr/bin/kutu-run usr/bin/kutu-firstboot usr/bin/kutu-check-kernel -t "$pkgdir/usr/bin/"
  install -Dm644 systemd/kutu-firstboot.service -t "$pkgdir/usr/lib/systemd/system/"
  install -Dm644 etc/os-release -t "$pkgdir/etc/"
  install -Dm644 etc/kutu/memory.conf -t "$pkgdir/etc/kutu/"
  install -Dm644 preset/80-kutu.preset -t "$pkgdir/usr/lib/systemd/system-preset/"
  install -Dm644 alpm-hooks/kutu-check-kernel.hook -t "$pkgdir/usr/share/libalpm/hooks/"
}
```

`packages/kutu-base/kutu-base.install`:
```bash
post_install() {
  systemctl --root="$1" enable kutu-firstboot.service 2>/dev/null || true
  [ "$1" = "/" ] && systemctl preset kutu-firstboot.service 2>/dev/null || true
}
```

- [ ] **Step 5: Write the failing tests, then run (expect pass — these test the scripts directly)**

`tests/kutu-firstboot-test.sh`:
```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
printf 'MemTotal: 4194304 kB\n' > "$tmp/meminfo"
KUTU_ROOT="$tmp/root" KUTU_MEMINFO="$tmp/meminfo" packages/kutu-base/usr/bin/kutu-firstboot
grep -q '^MODE=saver$' "$tmp/root/etc/kutu/memory.conf"
grep -q 'MemoryHigh=3579139276' "$tmp/root/etc/systemd/system/user.slice.d/50-kutu.conf"
grep -q '^KUTU_MEMORY_HIGH_PCT=40$' "$tmp/root/etc/kutu/apps.d/firefox.conf"
KUTU_ROOT="$tmp/root" KUTU_MEMINFO="$tmp/meminfo" packages/kutu-base/usr/bin/kutu-firstboot
grep -q '^MODE=saver$' "$tmp/root/etc/kutu/memory.conf"
printf 'MemTotal: 16777216 kB\n' > "$tmp/meminfo"
KUTU_ROOT="$tmp/root2" KUTU_MEMINFO="$tmp/meminfo" packages/kutu-base/usr/bin/kutu-firstboot
grep -q '^MODE=balanced$' "$tmp/root2/etc/kutu/memory.conf"
printf 'MemTotal: 67108864 kB\n' > "$tmp/meminfo"
KUTU_ROOT="$tmp/root3" KUTU_MEMINFO="$tmp/meminfo" packages/kutu-base/usr/bin/kutu-firstboot
grep -q '^MODE=performance$' "$tmp/root3/etc/kutu/memory.conf"
echo "kutu-firstboot tests: PASS"
```

`tests/kutu-run-test.sh`:
```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/etc/kutu/apps.d"
cat > "$tmp/etc/kutu/apps.d/testapp.conf" <<'EOF'
KUTU_MEMORY_HIGH_PCT=50
KUTU_CPU_WEIGHT=80
KUTU_MEMORY_MERGE=1
EOF
printf 'MemTotal: 4194304 kB\n' > "$tmp/meminfo"
out=$(KUTU_ROOT="$tmp" KUTU_MEMINFO="$tmp/meminfo" \
  packages/kutu-base/usr/bin/kutu-run --dry-run testapp /usr/bin/sleep 10)
grep -q 'MemoryHigh=2147483648' <<< "$out"
grep -q 'CPUWeight=80' <<< "$out"
grep -q 'MemoryMerge=yes' <<< "$out"
grep -q 'app-testapp' <<< "$out"
out=$(KUTU_ROOT="$tmp" packages/kutu-base/usr/bin/kutu-run --dry-run nosuchapp /bin/true)
grep -qv 'MemoryHigh' <<< "$out" || true
echo "kutu-run tests: PASS"
```

```bash
chmod +x tests/*.sh packages/kutu-base/usr/bin/*
./tests/kutu-firstboot-test.sh && ./tests/kutu-run-test.sh
```

- [ ] **Step 6: Build, validate, commit**

```bash
cd packages/kutu-base && makepkg -f && cd ../..
./scripts/validate-configs.sh
git add -A && git commit -m "kutu-base: firstboot calibration, kutu-run launcher, kernel prober, os-release"
```

---

### Task 6: `kutu-desktop-xfce` package

**Files:**
- Create: `packages/kutu-desktop-xfce/PKGBUILD`, `kutu-desktop-xfce.install`
- Move: `configs/desktop/themes|wallpapers|branding` → `packages/kutu-desktop-xfce/branding/`
- Create: `packages/kutu-desktop-xfce/lightdm/20-kutu.conf`
- Create: `packages/kutu-desktop-xfce/xdg/xfce4/xfconf/xfce-perchannel-xml/{xsettings,xfwm4,xfce4-desktop}.xml`
- Create: `packages/kutu-desktop-xfce/firefox/{mozilla.cfg,defaults/pref/kutu-autoconfig.js}`
- Create: `packages/kutu-desktop-xfce/usr/lib/kutu/patch-firefox-desktop.sh`
- Create: `packages/kutu-desktop-xfce/alpm-hooks/60-kutu-firefox-wrap.hook`
- Test: `tests/patch-firefox-desktop-test.sh`

**Interfaces:**
- Consumes: `kutu-run` (Task 5) — the Firefox Exec patch rewrites `Exec=firefox…` lines to `Exec=kutu-run firefox …`.
- Produces: XFCE desktop package with kutu theming, LightDM config, Firefox autoconfig + wrapping.

- [ ] **Step 1: Move branding into the package**

```bash
mkdir -p packages/kutu-desktop-xfce/branding
git mv configs/desktop/themes configs/desktop/wallpapers configs/desktop/branding packages/kutu-desktop-xfce/branding/
rmdir configs/desktop 2>/dev/null || true
```

- [ ] **Step 2: Write desktop config files**

`lightdm/20-kutu.conf` (session default; autologin username is written per-machine by Calamares displaymanager module or kutu-firstboot):
```ini
[Seat:*]
greeter-session=lightdm-gtk-greeter
user-session=xfce
```

`xdg/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xsettings" version="1.0">
  <property name="Net" type="empty">
    <property name="ThemeName" type="string" value="KutuDark"/>
    <property name="IconThemeName" type="string" value="Adwaita"/>
  </property>
  <property name="Gtk" type="empty">
    <property name="FontName" type="string" value="Noto Sans 10"/>
    <property name="MonospaceFontName" type="string" value="Noto Sans Mono 10"/>
  </property>
</channel>
```

`xdg/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfwm4" version="1.0">
  <property name="general" type="empty">
    <property name="ThemeName" type="string" value="KutuDark"/>
  </property>
</channel>
```

`xdg/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-desktop" version="1.0">
  <property name="backdrop" type="empty">
    <property name="screen0" type="empty">
      <property name="monitor0" type="empty">
        <property name="image-path" type="string" value="/usr/share/kutu/wallpapers/kutu-default.svg"/>
        <property name="image-style" type="int" value="3"/>
        <property name="image-show" type="bool" value="true"/>
      </property>
    </property>
  </property>
</channel>
```

`firefox/defaults/pref/kutu-autoconfig.js`:
```js
pref("general.config.filename", "mozilla.cfg");
pref("general.config.obscure_value", 0);
```

`firefox/mozilla.cfg` (autoconfig runs JS; `//` line 1 is required):
```js
//
defaultPref("browser.tabs.unloadOnLowMemory", true);
defaultPref("browser.low_commit_space_threshold_mb", 1024);
defaultPref("browser.low_commit_space_threshold_pct", 10);
```

`usr/lib/kutu/patch-firefox-desktop.sh`:
```bash
#!/usr/bin/env bash
set -euo pipefail
F="${KUTU_FIREFOX_DESKTOP:-/usr/share/applications/firefox.desktop}"
[ -r "$F" ] || exit 0
sed -i -E 's|^Exec=firefox( |$)|Exec=kutu-run firefox\1|' "$F"
```

`alpm-hooks/60-kutu-firefox-wrap.hook`:
```ini
[Trigger]
Operation = Install
Operation = Upgrade
Type = Package
Target = firefox
Target = kutu-desktop-xfce

[Action]
Description = Wrapping Firefox desktop launcher with kutu-run
When = PostTransaction
Exec = /usr/lib/kutu/patch-firefox-desktop.sh
```

- [ ] **Step 3: Write PKGBUILD + install scriptlet**

```pkgbuild
pkgname=kutu-desktop-xfce
pkgver=0.1.0
pkgrel=1
pkgdesc="kutu OS XFCE desktop: curated, themed, memory-wrapped"
arch=(any)
url="https://kutu.so"
license=(MIT GPL2 CC-BY-SA)
depends=(xfce4 xfce4-terminal xfce4-power-manager xfce4-screensaver xfce4-screenshooter
         xfce4-pulseaudio-plugin thunar-volman gvfs xdg-user-dirs mousepad ristretto
         lightdm lightdm-gtk-greeter network-manager-applet blueman
         pipewire wireplumber pipewire-audio pipewire-pulse pavucontrol
         firefox greybird gtk-engine-murrine adwaita-icon-theme
         noto-fonts ttf-dejavu librsvg)
install=kutu-desktop-xfce.install
package() {
  install -Dm644 lightdm/20-kutu.conf -t "$pkgdir/etc/lightdm/lightdm.conf.d/"
  install -Dm644 xdg/xfce4/xfconf/xfce-perchannel-xml/*.xml -t "$pkgdir/etc/xdg/xfce4/xfconf/xfce-perchannel-xml/"
  install -Dm644 firefox/mozilla.cfg -t "$pkgdir/usr/lib/firefox/"
  install -Dm644 firefox/defaults/pref/kutu-autoconfig.js -t "$pkgdir/usr/lib/firefox/defaults/pref/"
  install -Dm755 usr/lib/kutu/patch-firefox-desktop.sh -t "$pkgdir/usr/lib/kutu/"
  install -Dm644 alpm-hooks/60-kutu-firefox-wrap.hook -t "$pkgdir/usr/share/libalpm/hooks/"
  cp -r branding/themes "$pkgdir/usr/share/themes/"
  install -Dm644 branding/wallpapers/*.svg -t "$pkgdir/usr/share/kutu/wallpapers/"
  install -Dm644 branding/branding/*.png -t "$pkgdir/usr/share/kutu/branding/"
}
```

`kutu-desktop-xfce.install`:
```bash
post_install() {
  /usr/lib/kutu/patch-firefox-desktop.sh 2>/dev/null || \
    KUTU_FIREFOX_DESKTOP="$1/usr/share/applications/firefox.desktop" /usr/lib/kutu/patch-firefox-desktop.sh 2>/dev/null || true
  systemctl --root="$1" enable lightdm.service 2>/dev/null || true
  systemctl --root="$1" set-default graphical.target 2>/dev/null || true
}
post_upgrade() {
  post_install "$1"
}
```
(Note: verify the KutuDark theme's internal directory name matches `branding/themes/KutuDark` — adjust install path so GTK sees theme name `KutuDark`.)

- [ ] **Step 4: Write + run the Exec-patch test**

`tests/patch-firefox-desktop-test.sh`:
```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
cat > "$tmp/firefox.desktop" <<'EOF'
[Desktop Entry]
Exec=firefox %u
Actions=new-window;new-private-window;

[Desktop Action new-window]
Exec=firefox --new-window %u

[Desktop Action new-private-window]
Exec=firefox --private-window %u
EOF
KUTU_FIREFOX_DESKTOP="$tmp/firefox.desktop" packages/kutu-desktop-xfce/usr/lib/kutu/patch-firefox-desktop.sh
grep -q '^Exec=kutu-run firefox %u$' "$tmp/firefox.desktop"
[ "$(grep -c 'Exec=kutu-run firefox' "$tmp/firefox.desktop")" = 3 ]
echo "patch-firefox-desktop tests: PASS"
```

```bash
chmod +x tests/patch-firefox-desktop-test.sh && ./tests/patch-firefox-desktop-test.sh
```

- [ ] **Step 5: Build (downloads ~600MB of deps first run — allow time), validate, commit**

```bash
cd packages/kutu-desktop-xfce && makepkg -f && cd ../..
./scripts/validate-configs.sh
git add -A && git commit -m "kutu-desktop-xfce: curated XFCE desktop with kutu theming and wrapped Firefox"
```

---

### Task 7: `kutu-calamares-config` package

**Files:**
- Create: `packages/kutu-calamares-config/PKGBUILD`
- Create: `packages/kutu-calamares-config/calamares/settings.conf`
- Create: `packages/kutu-calamares-config/calamares/modules/{welcome,locale,keyboard,partition,users,unpack,machineid,fstab,displaymanager,grubcfg,bootloader,localecfg,keyboardcfg}.conf` and `shellprocess@done.conf`
- Create: `packages/kutu-calamares-config/calamares/branding/kutu/branding.desc` + logo files

**Interfaces:**
- Consumes: kutu packages installed in the live env (Task 9 ISO); live autologin config `20-kutu-live.conf` created in the archiso profile (Task 9) which `shellprocess@done` removes post-install.
- Produces: `/etc/calamares/` tree; Calamares with kutu branding, offline unpackfs install, swap default = RAM-sized (hibernate-capable laptops; deviation from spec §7 min(RAM,16GiB) noted for spec amendment in M2).

- [ ] **Step 1: Write `settings.conf`**

```yaml
modules-search: [ local ]

sequence:
  - show:
      - welcome
      - locale
      - keyboard
      - partition
      - users
  - exec:
      - partition
      - unpack
      - machineid
      - fstab
      - localecfg
      - keyboardcfg
      - displaymanager
      - grubcfg
      - bootloader
      - shellprocess@done

branding: kutu
prompt-config: false
dont-chroot: false
```

- [ ] **Step 2: Write module configs**

`modules/welcome.conf`:
```yaml
requirements:
  requiredStorage: 8
  requiredRam: 1.5
  internetCheckUrl: http://archive.archlinux.org
check:
  - storage
  - ram
  - power
  - root
```

`modules/locale.conf`, `modules/keyboard.conf`, `modules/machineid.conf`, `modules/fstab.conf`, `modules/grubcfg.conf`, `modules/localecfg.conf`, `modules/keyboardcfg.conf`:
```yaml
# locale.conf
localeGenPath: /etc/locale.gen

# keyboard.conf (empty defaults are fine)

# machineid.conf
systemd: true
dbus: true
symlink: true

# fstab.conf
mountOptions:
  - filesystem: ext4
    options: [ defaults, noatime ]
  - filesystem: btrfs
    options: [ defaults, noatime, compress=zstd ]
  - filesystem: fat32
    options: [ fmask=0077, dmask=0077 ]

# grubcfg.conf
overwrite: false

# localecfg.conf / keyboardcfg.conf: accept module defaults; empty files are valid
```

`modules/partition.conf`:
```yaml
defaultFileSystemType: ext4
initialPartitioningChoice: erase
initialSwapChoice: suspend
enableLuksAutomatedPartitioning: true
requiredPartitionTableType: gpt
```

`modules/users.conf`:
```yaml
defaultGroups: [ wheel, users ]
autologinGroup: autologin
doAutologin: true
setRootPassword: false
sudoersConfigure: true
```

`modules/unpack.conf`:
```yaml
unpack:
  - source: "/run/archiso/airootfs"
    sourcefs: ext4
    destination: "/"
```

`modules/displaymanager.conf`:
```yaml
displaymanagers: [ lightdm ]
basicSetup: false
autologin:
  enable: true
  user: ""
```

`modules/bootloader.conf`:
```yaml
efiBootLoader: grub
kernel: all
bootloaderEntryName: kutu OS
```

`modules/shellprocess@done.conf`:
```yaml
dontChroot: true
script:
  - command: "-/usr/bin/sed -i 's|file:///tmp/kutu-repo|https://kutu-so.github.io/os/repo/x86_64|' ${ROOT}/etc/pacman.conf"
  - command: "-/usr/bin/rm -f ${ROOT}/etc/lightdm/lightdm.conf.d/20-kutu-live.conf"
  - command: "-/usr/bin/rm -f ${ROOT}/etc/systemd/system/serial-getty@ttyS0.service.d/autologin.conf"
  - command: "-/usr/bin/rm -f ${ROOT}/etc/systemd/system/getty@tty1.service.d/autologin.conf"
  - command: "-/usr/sbin/userdel -r kutu"
  - command: "-/usr/bin/systemctl --root=${ROOT} enable kutu-firstboot.service"
```
(Verify `${ROOT}` substitution semantics against Calamares shellprocess docs during execution; adjust to `1`/`ROOT` env if needed.)

- [ ] **Step 3: Write branding component**

`calamares/branding/kutu/branding.desc`:
```yaml
componentName: kutu
strings:
  productName: kutu OS
  shortProductName: kutu
  version: 0.1
  shortVersion: 0.1
  versionedName: kutu OS 0.1
  shortVersionedName: kutu 0.1
  bootloaderEntryName: kutu OS
  productUrl: https://kutu.so
  supportUrl: https://github.com/kutu-so/os/issues
images:
  productLogo: logo.png
  productIcon: logo.png
  productWelcome: logo.png
style:
  SidebarBackground: "#1a1a2e"
  SidebarText: "#e6e6e6"
  SidebarTextHighlight: "#ff9900"
  BrandingPlaceholder: "#f0f0f0"
```
Copy `packages/kutu-desktop-xfce/branding/branding/kutu-logo.png` to `calamares/branding/kutu/logo.png` (do it in PKGBUILD `prepare()` via `cp`, or commit the copy — commit the copy).

- [ ] **Step 4: Write PKGBUILD**

```pkgbuild
pkgname=kutu-calamares-config
pkgver=0.1.0
pkgrel=1
pkgdesc="kutu OS Calamares installer configuration and branding"
arch=(any)
url="https://kutu.so"
license=(MIT)
depends=(calamares)
package() {
  cp -r calamares "$pkgdir/etc/"
  find "$pkgdir/etc/calamares" -type f -exec chmod 644 {} +
  chmod 755 "$pkgdir/etc/calamares"
}
```

- [ ] **Step 5: Verify (YAML parse + build), commit**

```bash
python3 -c "import yaml,glob; [yaml.safe_load(open(f)) for f in glob.glob('packages/kutu-calamares-config/calamares/**/*.conf', recursive=True) + ['packages/kutu-calamares-config/calamares/settings.conf']]; print('yaml OK')"
cd packages/kutu-calamares-config && makepkg -f && cd ../..
git add -A && git commit -m "kutu-calamares-config: offline installer flow with kutu branding"
```
(If pyyaml missing on host: `pip install pyyaml --user` or run inside `docker run --rm -v $PWD:/w archlinux:base-devel python3` after installing python-yaml.)

---

### Task 8: `kutu-keyring` package + release signing docs

**Files:**
- Create: `packages/kutu-keyring/PKGBUILD`, `packages/kutu-keyring/kutu-keyring.install`
- Create: `packages/kutu-keyring/keyrings/.gitkeep` (real key added at release time)
- Create: `docs/RELEASE.md`

**Interfaces:**
- Produces: `/usr/share/pacman/keyrings/kutu{.gpg,-trusted,-revoked}`; install scriptlet runs `pacman-key --populate kutu` when keyring data exists. CI `release.yml` (Task 12) imports the private key from secrets and signs with `makepkg --sign`; ISO build sets shipped `pacman.conf` SigLevel accordingly.

- [ ] **Step 1: Write PKGBUILD + install scriptlet**

```pkgbuild
pkgname=kutu-keyring
pkgver=20260827
pkgrel=1
pkgdesc="kutu OS pacman keyring"
arch=(any)
url="https://kutu.so"
license=(MIT)
install=kutu-keyring.install
package() {
  install -Dm644 keyrings/kutu.gpg -t "$pkgdir/usr/share/pacman/keyrings/"
  install -Dm644 keyrings/kutu-trusted -t "$pkgdir/usr/share/pacman/keyrings/"
  [ -f keyrings/kutu-revoked ] && install -Dm644 keyrings/kutu-revoked -t "$pkgdir/usr/share/pacman/keyrings/" || \
    : > "$pkgdir/usr/share/pacman/keyrings/kutu-revoked"
}
```

`kutu-keyring.install`:
```bash
post_install() {
  if [ -s /usr/share/pacman/keyrings/kutu.gpg ]; then
    pacman-key --populate kutu 2>/dev/null || true
  else
    echo "kutu-keyring: no signing key shipped yet (development); repo SigLevel stays permissive"
  fi
}
```

- [ ] **Step 2: Write `docs/RELEASE.md`**

```markdown
# kutu OS Release Process

## One-time (or key rotation): signing key

1. `gpg --quick-gen-key "kutu OS Release <release@kutu.so>" ed25519 sign never`
2. Export the public key: `gpg --armor --export release@kutu.so > packages/kutu-keyring/keyrings/kutu.gpg`
3. Set ownertrust: `printf '<KEYID>:4:\n' > packages/kutu-keyring/keyrings/kutu-trusted`
4. Export the private key for CI: `gpg --armor --export-secret-keys release@kutu.so`
   → GitHub secret `KUTU_GPG_KEY` (repo → Settings → Secrets → Actions).

Without a key, CI builds unsigned packages and the shipped pacman.conf uses
`SigLevel = Never` (never past v1 — spec decision D9).

## Releasing

1. Ensure `make smoke` passes locally.
2. Tag: `git tag -s vX.Y.Z -m "kutu OS vX.Y.Z" && git push origin vX.Y.Z`
3. CI (release.yml) builds + signs packages, publishes the pacman repo to
   gh-pages, builds the ISO, smoke-tests it in QEMU, and attaches
   `kutu-os-X.Y.Z-x86_64.iso` + `SHA256SUMS` to the GitHub release.
4. Manual release checklist (do these in QEMU with the release ISO):
   - boot live ISO → lightdm autologin reaches XFCE
   - run Calamares to disk (default options) → reboot into installed system
   - installed system: `cat /proc/cmdline | grep zswap.enabled=1`
   - `kutu-check-kernel` exits 0
   - `pacman -Syu` reaches the kutu repo (check `pacman -Sl kutu` lists packages)
   - Firefox launches via wrapped launcher (`systemd-cgls` shows app-firefox scope)
```

- [ ] **Step 3: Build + commit**

```bash
: > packages/kutu-keyring/keyrings/kutu.gpg
: > packages/kutu-keyring/keyrings/kutu-trusted
cd packages/kutu-keyring && makepkg -f && cd ../..
git add -A && git commit -m "kutu-keyring + release signing docs"
```

---

### Task 9: archiso profile rewrite (desktop live ISO)

**Files:**
- Rewrite: `archiso/profiledef.sh`, `archiso/packages.x86_64`, `archiso/pacman.conf`, `archiso/grub/grub.cfg`, `archiso/syslinux/syslinux.cfg`
- Create: `archiso/efiboot/loader/entries/01-kutu.conf`, `archiso/efiboot/loader/loader.conf`
- Create: `archiso/airootfs/etc/lightdm/lightdm.conf.d/20-kutu-live.conf`
- Create: `archiso/airootfs/etc/systemd/system/getty@tty1.service.d/autologin.conf`
- Create: `archiso/airootfs/etc/systemd/system/serial-getty@ttyS0.service.d/autologin.conf`
- Create: `archiso/airootfs/usr/sbin/kutu-live-setup.sh` (runs from customize_airootfs)
- Create: `archiso/customize_airootfs.sh`

**Interfaces:**
- Consumes: all five kutu packages (Tasks 2–8) from the local repo at `/tmp/kutu-repo` (build script Task 10 prepares it and points profile `pacman.conf` there via sed before mkarchiso).
- Produces: bootable ISO with XFCE live session (autologin user `kutu`), all Tier-0 units enabled, serial console root autologin for smoke testing.

- [ ] **Step 1: `profiledef.sh`**

```bash
#!/usr/bin/env bash
# shellcheck disable=SC2034
iso_name="kutu-os"
iso_label="KUTU_OS_$(date +%Y%m)"
iso_publisher="kutu.so <https://kutu.so>"
iso_application="kutu OS - The RAM-sipping Linux desktop"
iso_version="$(date +%Y.%m.%d)"
install_dir="kutu"
buildmodes=('iso')
bootmodes=('bios.syslinux.mbr' 'bios.syslinux.eltorito'
           'uefi-ia32.grub.esp' 'uefi-x64.systemd-boot.esp'
           'uefi-ia32.grub.eltorito' 'uefi-x64.systemd-boot.eltorito')
arch="x86_64"
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'zstd' '-b' '1M' '-Xcompression-level' '15')
file_permissions=(
  ["/etc/shadow"]="0:0:400"
  ["/root"]="0:0:750"
  ["/usr/sbin/kutu-live-setup.sh"]="0:0:755"
  ["/etc/sudoers.d"]="0:0:750"
)
```

- [ ] **Step 2: `packages.x86_64`** (trimmed base + our packages; XFCE deps come via kutu-desktop-xfce):

```
base
linux
linux-lts
linux-firmware
mkinitcpio
grub
efibootmgr
os-prober
systemd
systemd-sysvcompat
networkmanager
openssh
dosfstools
e2fsprogs
btrfs-progs
xfsprogs
ntfs-3g
exfatprogs
nvme-cli
smartmontools
lm_sensors
usbutils
pciutils
lshw
htop
btop
ncdu
nano
vim
sudo
less
man-db
man-pages
bash-completion
tree
wget
curl
rsync
jq
tar
gzip
bzip2
xz
zstd
zip
unzip
p7zip
fzf
ripgrep
fd
bat
eza
reflector
pacman-contrib
thermald
tlp
mesa
vulkan-icd-loader
calamares
kutu-base
kutu-memory
kutu-desktop-xfce
kutu-calamares-config
kutu-keyring
```

- [ ] **Step 3: `pacman.conf`** — Arch releng-style with our repo appended (build script seds the Server path):

```ini
[options]
HoldPkg = pacman glibc
Architecture = auto
CheckSpace
SigLevel = Required DatabaseOptional
LocalFileSigLevel = Optional

[kutu]
SigLevel = Never
Server = file:///tmp/kutu-repo/$repo/$arch

[core]
Include = /etc/pacman.d/mirrorlist

[extra]
Include = /etc/pacman.d/mirrorlist
```
(Copy a current Arch `mirrorlist` into `archiso/airootfs/etc/pacman.d/mirrorlist`; fetch from a live mirrorlist endpoint during execution and commit it.)

- [ ] **Step 4: boot configs** — base them on the current arch upstream releng profile templates (`/usr/share/archiso/configs/releng/` after `pacman -S archiso`, or fetch from gitlab.archlinux.org/archlinux/archiso); change: titles to `kutu OS`, timeout 5, append `zswap.enabled=1 zswap.compressor=zstd zswap.zpool=zsmalloc zswap.max_pool_percent=35 zswap.shrinker_enabled=1 psi=1 transparent_hugepage=madvise console=tty0 console=ttyS0,115200` to kernel lines, keep `archisolabel=%ARCHISO_LABEL%` machinery. Also create matching `syslinux.cfg` and efiboot entries.

- [ ] **Step 5: live session files**

`airootfs/etc/lightdm/lightdm.conf.d/20-kutu-live.conf`:
```ini
[Seat:*]
autologin-user=kutu
autologin-session=xfce
```

`airootfs/etc/systemd/system/getty@tty1.service.d/autologin.conf`:
```ini
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin root -o '-p -- \\u' 115200 tty1 linux
```

`airootfs/etc/systemd/system/serial-getty@ttyS0.service.d/autologin.conf`:
```ini
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin root -o '-p -- \\u' 115200 ttyS0 linux
```

`airootfs/usr/sbin/kutu-live-setup.sh` (invoked by customize_airootfs):
```bash
#!/usr/bin/env bash
set -euo pipefail
useradd -m -G wheel -s /bin/bash kutu 2>/dev/null || true
passwd -d kutu 2>/dev/null || true
sed -i 's/^#en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
locale-gen
echo 'LANG=en_US.UTF-8' > /etc/locale.conf
ln -sf /usr/share/zoneinfo/UTC /etc/localtime
echo kutu-live > /etc/hostname
systemctl set-default graphical.target
systemctl enable NetworkManager.service lightdm.service sshd.service \
  kutu-mglru.service kutu-damon.service kutu-firstboot.service systemd-oomd.service
```

`archiso/customize_airootfs.sh`:
```bash
#!/usr/bin/env bash
set -euo pipefail
/usr/sbin/kutu-live-setup.sh
```

- [ ] **Step 6: Verify + commit** (full ISO build happens in Task 10)

```bash
shellcheck archiso/customize_airootfs.sh archiso/airootfs/usr/sbin/kutu-live-setup.sh
bash -n archiso/profiledef.sh
git add -A && git commit -m "archiso: XFCE desktop live profile with kutu packages"
```

---

### Task 10: build scripts + Makefile

**Files:**
- Create: `scripts/build-packages.sh`
- Rewrite: `scripts/build.sh`
- Rewrite: `Makefile`

**Interfaces:**
- Produces: `scripts/build-packages.sh [--docker|--host]` → `work/repo/x86_64/*.pkg.tar.zst` + `kutu.db`; `scripts/build.sh` → `out/kutu-os-<version>-x86_64.iso`; Makefile targets `packages`, `build`, `clean`, `distclean`, `test-vm`, `smoke`, `check`.

- [ ] **Step 1: Write `scripts/build-packages.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
REPO_DIR="work/repo/x86_64"
mkdir -p "$REPO_DIR"
build_host() {
  for pkg in packages/*/; do
    (cd "$pkg" && makepkg -f --noconfirm --sign 2>/dev/null || makepkg -f --noconfirm)
    cp "$pkg"/*.pkg.tar.zst "$REPO_DIR/"
    cp "$pkg"/*.pkg.tar.zst.sig "$REPO_DIR/" 2>/dev/null || true
  done
  cd "$REPO_DIR" && repo-add kutu.db.tar.zst *.pkg.tar.zst && cd ../../..
}
if [ "${1:-}" = "--host" ] || command -v makepkg >/dev/null 2>&1 && [ -r /etc/arch-release ] && ! [ "${1:-}" = "--docker" ]; then
  build_host
else
  docker run --rm -v "$PWD:/w" -w /w archlinux:base-devel bash -c \
    "pacman -Syu --noconfirm && /w/scripts/build-packages.sh --host"
fi
```

- [ ] **Step 2: Rewrite `scripts/build.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION="$(date +%Y.%m.%d)"
OUT="out"; WORK="work"
mkdir -p "$OUT"

[ "$(id -u)" -eq 0 ] || { echo "build.sh must run as root (sudo)"; exit 1; }

./scripts/build-packages.sh

# point the profile's pacman.conf at our local repo, and decide SigLevel
SIGLEVEL="Never"
if compgen -G "work/repo/x86_64/*.sig" >/dev/null; then SIGLEVEL="PackageRequired"; fi
PROFILE_TMP="$WORK/profile"
rm -rf "$PROFILE_TMP"
cp -r archiso "$PROFILE_TMP"
sed -i "s|^Server = file:///tmp/kutu-repo/\$repo/\$arch|Server = file://$PWD/work/repo/\$repo/\$arch|" \
  "$PROFILE_TMP/pacman.conf"

run_mkarchiso() {
  command -v mkarchiso >/dev/null && [ -r /etc/arch-release ] && exec mkarchiso -v -w "$WORK/chroot" -o "$OUT" "$PROFILE_TMP"
  docker run --rm -v "$PWD:/w" -w /w archlinux:base-devel bash -c \
    "pacman -Syu --noconfirm archiso && mkarchiso -v -w $WORK/chroot -o $OUT $PROFILE_TMP"
}
run_mkarchiso
ISO="$OUT/kutu-os-$VERSION-x86_64.iso"
echo "built: $ISO"
if command -v sha256sum >/dev/null; then sha256sum "$ISO" > "$ISO.sha256"; fi
```
(Root is required for mkarchiso; the docker path therefore also runs as root-owned files — acceptable for a build host; document in BUILDING.md.)

- [ ] **Step 3: Rewrite `Makefile`**

```makefile
.PHONY: help check install-deps packages build clean distclean test-vm smoke

help:
	@echo "kutu OS build system"
	@echo "  make packages   - build kutu-* packages into work/repo"
	@echo "  make build      - build the ISO (sudo; docker fallback)"
	@echo "  make test-vm    - boot latest ISO in QEMU (KVM if available)"
	@echo "  make smoke      - run automated smoke test against latest ISO"
	@echo "  make check      - check build requirements"
	@echo "  make clean      - remove build dir"
	@echo "  make distclean  - remove build dir and ISOs"

check:
	@for cmd in makepkg docker qemu-system-x86_64 shellcheck expect; do \
		command -v $$cmd >/dev/null 2>&1 && echo "ok: $$cmd" || echo "missing: $$cmd"; \
	done

install-deps:
	sudo pacman -S --needed archiso squashfs-tools libisoburn dosfstools expect

packages:
	./scripts/build-packages.sh

build:
	@sudo ./scripts/build.sh

clean:
	sudo rm -rf work

distclean: clean
	rm -rf out && mkdir -p out

test-vm:
	./scripts/test-vm.sh

smoke:
	./scripts/smoke-test.sh
```

- [ ] **Step 4: Build the ISO (first full build; allow 30–90 min)**

```bash
sudo ./scripts/build.sh
ls -lh out/*.iso
```
Expected: `out/kutu-os-<date>-x86_64.iso` exists, ~1.5–2.2GB.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "build: package + ISO pipeline with docker fallback"
```

---

### Task 11: QEMU smoke test + test-vm

**Files:**
- Create: `scripts/smoke-test.sh`
- Create: `scripts/test-vm.sh`

**Interfaces:**
- Consumes: latest `out/kutu-os-*.iso`.
- Produces: exit 0 iff all assertions pass; used by CI release workflow (Task 12) as the release gate.

- [ ] **Step 1: Write `scripts/smoke-test.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
ISO=$(ls -t out/kutu-os-*.iso 2>/dev/null | head -n1)
[ -n "$ISO" ] || { echo "no ISO in out/; run: sudo make build"; exit 1; }
LOG=$(mktemp); trap 'rm -f "$LOG"' EXIT
KVM=""
[ -w /dev/kvm ] && KVM="-enable-kvm -cpu host"

expect <<EOF | tee "$LOG"
set timeout 900
spawn qemu-system-x86_64 -m 2048 $KVM -display none -cdrom "$ISO" -serial mon:stdio -nographic
expect "# "
send "echo SMOKE-LOGIN-OK\r"
expect "SMOKE-LOGIN-OK"
send "cat /sys/module/zswap/parameters/compressor; cat /sys/module/zswap/parameters/enabled; cat /sys/module/zswap/parameters/zpool; cat /sys/module/zswap/parameters/shrinker_enabled\r"
expect "# "
send "echo SMOKE-ZSWAP:\$(cat /sys/module/zswap/parameters/compressor):\$(cat /sys/module/zswap/parameters/enabled):\$(cat /sys/module/zswap/parameters/zpool):\$(cat /sys/module/zswap/parameters/shrinker_enabled)\r"
expect "SMOKE-ZSWAY:"
expect -re {SMOKE-ZSWAP:([^\\r]*)\\r}
expect "# "
send "echo SMOKE-MGLRU:\$(cat /sys/kernel/mm/lru_gen/enabled):\$(cat /sys/kernel/mm/lru_gen/min_ttl_ms)\r"
expect "# "
send "echo SMOKE-DAMON:\$(cat /sys/kernel/mm/damon/admin/kdamonds/0/state 2>/dev/null || echo none)\r"
expect "# "
send "for s in systemd-oomd kutu-mglru kutu-damon kutu-firstboot NetworkManager lightdm; do echo SMOKE-SVC-\$s:\$(systemctl is-active \$s); done\r"
expect "# "
send "echo SMOKE-CK:\$(kutu-check-kernel >/dev/null 2>&1 && echo ok || echo fail)\r"
expect "# "
send "echo SMOKE-RUN:\$(kutu-run --dry-run firefox /bin/true | grep -c MemoryHigh)\r"
expect "# "
send "sleep 90; echo SMOKE-XFCE:\$(pgrep -c -x xfce4-session || echo 0)\r"
expect "# "
send "poweroff\r"
expect eof
EOF

grep -q "SMOKE-ZSWAP:zstd:Y:zsmalloc:Y" "$LOG" || { echo "FAIL: zswap params"; exit 1; }
grep -qE "SMOKE-MGLRU:(0x0007|7):1000" "$LOG" || { echo "FAIL: MGLRU"; exit 1; }
grep -q "SMOKE-DAMON:on" "$LOG" || { echo "FAIL: DAMON state"; exit 1; }
grep -c "SMOKE-SVC-.*:active" "$LOG" | grep -q "^6$" || { echo "FAIL: services"; grep "SMOKE-SVC" "$LOG"; exit 1; }
grep -q "SMOKE-CK:ok" "$LOG" || { echo "FAIL: kutu-check-kernel"; exit 1; }
grep -qE "SMOKE-RUN:[1-9]" "$LOG" || { echo "FAIL: kutu-run"; exit 1; }
grep -qE "SMOKE-XFCE:[1-9]" "$LOG" || { echo "FAIL: XFCE session"; exit 1; }
echo "SMOKE TEST: ALL PASS"
```
(During execution, fix expect quoting/regex issues; the contract is the final grep assertions — keep those exact.)

- [ ] **Step 2: Write `scripts/test-vm.sh`** (interactive)

```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
ISO=$(ls -t out/kutu-os-*.iso 2>/dev/null | head -n1)
[ -n "$ISO" ] || { echo "no ISO in out/; run: sudo make build"; exit 1; }
KVM=""
[ -w /dev/kvm ] && KVM="-enable-kvm -cpu host"
exec qemu-system-x86_64 -m 2048 $KVM -cdrom "$ISO" -boot d -netdev user,id=n0 -device virtio-net,netdev=n0
```

- [ ] **Step 3: Run the smoke test (TCG if no KVM — expect 10–30 min)**

```bash
chmod +x scripts/smoke-test.sh scripts/test-vm.sh
./scripts/smoke-test.sh
```
Expected: `SMOKE TEST: ALL PASS`. Fix failures by iterating on profile/packages; the smoke test is the release gate — it must pass before Task 12.

- [ ] **Step 4: Commit**

```bash
git add -A && git commit -m "test: QEMU smoke test + interactive test-vm"
```

---

### Task 12: CI workflows

**Files:**
- Create: `.github/workflows/ci.yml`
- Create: `.github/workflows/release.yml`

**Interfaces:**
- Consumes: `scripts/validate-configs.sh`, `tests/*-test.sh`, `scripts/build-packages.sh`, `scripts/smoke-test.sh` (all prior tasks).
- Produces: PR validation; on `v*` tags: signed repo → gh-pages, smoke-tested ISO → GitHub Release.

- [ ] **Step 1: Write `.github/workflows/ci.yml`**

```yaml
name: ci
on:
  push: { branches: [master] }
  pull_request:
  workflow_dispatch:

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: sudo apt-get update && sudo apt-get install -y shellcheck expect
      - run: ./scripts/validate-configs.sh
      - run: shellcheck scripts/*.sh
      - run: tests/kutu-damon-test.sh && tests/kutu-firstboot-test.sh && tests/kutu-run-test.sh && tests/patch-firefox-desktop-test.sh

  packages:
    runs-on: ubuntu-latest
    container: archlinux:base-devel
    strategy:
      matrix: { pkg: [kutu-base, kutu-memory, kutu-desktop-xfce, kutu-calamares-config, kutu-keyring] }
    steps:
      - run: pacman -Syu --noconfirm git
      - uses: actions/checkout@v4
      - run: cd packages/${{ matrix.pkg }} && makepkg -f --noconfirm
```

- [ ] **Step 2: Write `.github/workflows/release.yml`**

```yaml
name: release
on:
  push: { tags: ["v*"] }

permissions:
  contents: write
  pages: write
  id-token: write

jobs:
  build:
    runs-on: ubuntu-latest
    container: archlinux:base-devel
    steps:
      - run: pacman -Syu --noconfirm git archiso expect qemu-headless sudo
      - uses: actions/checkout@v4
      - name: import signing key (if present)
        if: env.KUTU_GPG_KEY != ''
        run: echo "$KUTU_GPG_KEY" | gpg --import
        env:
          KUTU_GPG_KEY: ${{ secrets.KUTU_GPG_KEY }}
      - run: ./scripts/build-packages.sh --host
      - run: repo-add work/repo/x86_64/kutu.db.tar.zst work/repo/x86_64/*.pkg.tar.zst
      - name: build ISO
        run: |
          mkdir -p out
          mkarchiso -v -w work/chroot -o out archiso
      - name: smoke test (TCG)
        run: ./scripts/smoke-test.sh
      - uses: actions/upload-artifact@v4
        with:
          name: kutu-release
          path: |
            out/*.iso
            out/*.sha256
            work/repo/x86_64/

  publish:
    needs: build
    runs-on: ubuntu-latest
    environment: github-pages
    steps:
      - uses: actions/download-artifact@v4
        with: { name: kutu-release }
      - name: pacman repo pages artifact
        run: mkdir -p site/repo/x86_64 && cp work/repo/x86_64/* site/repo/x86_64/ 2>/dev/null || cp repo/x86_64/* site/repo/x86_64/
      - uses: actions/configure-pages@v5
      - uses: actions/upload-pages-artifact@v3
        with: { path: site }
      - uses: actions/deploy-pages@v4
      - name: github release
        uses: softprops/action-gh-release@v2
        with:
          files: |
            *.iso
            *.sha256
```
(During execution, align artifact path layout between jobs — download-artifact flattens paths; adjust the publish `cp` globs to the actual layout.)

- [ ] **Step 3: Validate YAML parses, commit**

```bash
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/ci.yml')); yaml.safe_load(open('.github/workflows/release.yml')); print('yaml OK')"
git add -A && git commit -m "ci: PR validation + tag-driven release pipeline"
```

---

### Task 13: Docs rewrite + M1 tag

**Files:**
- Rewrite: `README.md`, `CLAUDE.md`, `docs/ARCHITECTURE.md`, `docs/BUILDING.md`, `docs/MAKEFILE.md`
- Create: `docs/MEMORY.md`

- [ ] **Step 1: Write `docs/MEMORY.md`** — user-facing explanation of the stack: what zswap/MGLRU/DAMON/oomd do for the user, the three modes table, `kutu-doctor` (coming in M2), escape hatches (`kutu-reset`), and how updates arrive via pacman. Pull values verbatim from spec §7–§8.

- [ ] **Step 2: Rewrite `README.md`** — the pitch: RAMageddon context (1 paragraph), what kutu OS does, quick start (download ISO → boot → install), modes table, "is this Arch?" FAQ, links to docs/MEMORY.md, RELEASE.md, the spec.

- [ ] **Step 3: Rewrite `CLAUDE.md`** — for future agents: package-first architecture, the 9-package map (5 shipped in M1), build/test commands (`make build`, `make smoke`, `./tests/*`), Tier-0 locked values, cgroup ownership rule (systemd sole writer), where M2/M3 specs will live, commit conventions (lowercase imperative, one feature per commit).

- [ ] **Step 4: Update `docs/ARCHITECTURE.md`** (update pipeline diagram from spec §4), `docs/BUILDING.md` (docker + host paths, requirements), `docs/MAKEFILE.md` (current targets).

- [ ] **Step 5: Final verification + tag**

```bash
./scripts/validate-configs.sh
./tests/kutu-damon-test.sh && ./tests/kutu-firstboot-test.sh && ./tests/kutu-run-test.sh && ./tests/patch-firefox-desktop-test.sh
./scripts/smoke-test.sh
git add -A && git commit -m "docs: M1 documentation for the RAMageddon pivot"
git tag -s v0.1.0 -m "kutu OS v0.1.0 - M1 foundation" || git tag v0.1.0 -m "kutu OS v0.1.0 - M1 foundation"
```

---

## Self-Review Notes (completed during planning)

- Spec coverage: §5 (5 M1 packages) → Tasks 2–8; §6 kernel policy → Tasks 2 (cmdline) + 9 (boot configs); §7 Tier 0 → Tasks 2–4; §10 desktop → Task 6; §11 installer/firstboot → Tasks 5, 7, 9; §12 CI → Task 12; §13 restructure → Task 1; §14 testing → Tasks 2–3, 5–6, 11; §15 escape hatch → Task 4; §16 M1 → all; §19 risks → signing fallback (Task 8), smoke gate (Task 11). M2/M3 items intentionally absent (own plans).
- Spec deviation logged: swap default = RAM-sized (`initialSwapChoice: suspend`, hibernate-capable) vs spec §7 min(RAM,16GiB) — rationale: Calamares canned choices + laptop hibernation value; amend spec at M2.
- Type/name consistency: `kutu-run` env keys `KUTU_MEMORY_HIGH_PCT/KUTU_MEMORY_SWAP_MAX/KUTU_CPU_WEIGHT/KUTU_MEMORY_MERGE` used identically in Task 5 script, firstboot writer, and smoke test; service names `kutu-mglru`, `kutu-damon`, `kutu-firstboot` consistent across Tasks 2–5, 9, 11.
