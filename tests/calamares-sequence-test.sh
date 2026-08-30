#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

CONF="packages/kutu-calamares-config/calamares/settings.conf"
CONF_DIR="packages/kutu-calamares-config/calamares"
CAL_PKG=$(find work/repo packages/calamares -maxdepth 1 -name 'calamares-*.pkg.tar.zst' -print 2>/dev/null | sort | head -1)
[ -n "$CAL_PKG" ] || { echo "FAIL: no built calamares package found; run: make packages"; exit 1; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
tar -tf "$CAL_PKG" > "$tmp/files"

mapfile -t seq < <(awk '/^sequence:/ {ins=1; next} ins && /^ *- show:/ {mode="show"; next} ins && /^ *- exec:/ {mode="exec"; next} ins && /^ *- [a-z]/ && !/^ *- (module|id|config):/ {gsub(/^ *- /, ""); print mode":"$0}' "$CONF")

fail=0
show=()
execphase=()
execraw=()
for entry in "${seq[@]}"; do
  phase=${entry%%:*}
  mod=${entry#*:}
  if [ "$phase" = "show" ]; then
    show+=("${mod%%@*}")
  else
    execphase+=("${mod%%@*}")
    execraw+=("$mod")
  fi
done

for key in grubInstall grubMkconfig grubCfg grubProbe efiBootMgr; do
  grep -q "^${key}:" "$CONF_DIR/modules/bootloader.conf" || { echo "FAIL: bootloader.conf missing required key '$key' (main.py indexes it raw; KeyError crashes the job)"; fail=1; }
done

kpos=-1; upos=-1; bpos=-1; donepos=-1
for i in "${!execraw[@]}"; do
  entry=${execraw[$i]}
  [ "$entry" = "shellprocess@kernel" ] && kpos=$i
  [ "$entry" = "unpackfs" ] && upos=$i
  [ "$entry" = "bootloader" ] && bpos=$i
  [ "$entry" = "shellprocess@done" ] && donepos=$i
done
if [ "$kpos" -lt 0 ] || [ "$kpos" -lt "$upos" ] || [ "$kpos" -gt "$bpos" ]; then
  echo "FAIL: shellprocess@kernel must run after unpackfs and before bootloader (archiso strips kernels from airootfs; the target needs them copied from the ISO boot tree)"
  fail=1
fi
if [ "$donepos" -lt "$bpos" ]; then
  echo "FAIL: shellprocess@done must run after bootloader"
  fail=1
fi
if [ "$kpos" -ge 0 ]; then
  kconf="$CONF_DIR/modules/shellprocess@kernel.conf"
  [ -f "$kconf" ] || { echo "FAIL: missing $kconf"; fail=1; }
  grep -q 'archiso/bootmnt' "$kconf" || { echo "FAIL: shellprocess@kernel.conf does not copy from the ISO boot tree"; fail=1; }
  grep -q "\${ROOT}/boot/" "$kconf" || { echo "FAIL: shellprocess@kernel.conf does not copy into the target /boot"; fail=1; }
  grep -q 'vmlinuz-linux' "$kconf" || { echo "FAIL: shellprocess@kernel.conf does not copy the kernel"; fail=1; }
  grep -q 'mkinitcpio' "$kconf" || { echo "FAIL: shellprocess@kernel.conf must build the initramfs in the target; the ISO initramfs is archiso's live image and cannot boot an installed system"; fail=1; }
  grep -q 'mkinitcpio.conf.d/archiso.conf' "$kconf" || { echo "FAIL: shellprocess@kernel.conf must remove the archiso mkinitcpio drop-in; it overrides HOOKS and rebuilds a live-only initramfs"; fail=1; }
  grep -q 'mkinitcpio.d/linux.preset' "$kconf" || { echo "FAIL: shellprocess@kernel.conf must replace the archiso preset; mkinitcpio -P would otherwise build only the live image"; fail=1; }
  grep -q 'HOOKS=' "$kconf" || { echo "FAIL: shellprocess@kernel.conf must set disk-boot HOOKS in the target mkinitcpio.conf"; fail=1; }
  grep -q 'timeout:' "$kconf" || { echo "FAIL: shellprocess@kernel.conf mkinitcpio needs a timeout above the 30s shellprocess default"; fail=1; }
  grep -q 'initramfs-linux.img' "$kconf" || { echo "FAIL: shellprocess@kernel.conf does not verify the initramfs"; fail=1; }
  grep -q 'test -f' "$kconf" || { echo "FAIL: shellprocess@kernel.conf does not verify the copied kernel files"; fail=1; }
fi

for inst in kernel 'done'
do
  grep -Eq "^ *- module: shellprocess$" "$CONF" || { echo "FAIL: settings.conf has no instances: section; custom instances like shellprocess@$inst silently load without config and no-op"; fail=1; break; }
  grep -Eq "^ *id: $inst\$" "$CONF" || { echo "FAIL: instances: section does not declare shellprocess@$inst"; fail=1; }
  grep -q "config: shellprocess@$inst.conf" "$CONF" || { echo "FAIL: shellprocess@$inst instance does not point at shellprocess@$inst.conf"; fail=1; }
done

mountconf="$CONF_DIR/modules/mount.conf"
[ -f "$mountconf" ] || { echo "FAIL: missing mount.conf; the mount module would skip /dev,/proc,/sys binds and grub-install fails in the chroot"; fail=1; }
if [ -f "$mountconf" ]; then
  grep -q 'mountPoint: /dev$' "$mountconf" || { echo "FAIL: mount.conf does not bind /dev into the target"; fail=1; }
  grep -q 'mountPoint: /proc$' "$mountconf" || { echo "FAIL: mount.conf does not mount /proc into the target"; fail=1; }
  grep -q 'mountPoint: /sys$' "$mountconf" || { echo "FAIL: mount.conf does not mount /sys into the target"; fail=1; }
  grep -q 'mountPoint: /run/udev$' "$mountconf" || { echo "FAIL: mount.conf does not bind /run/udev into the target"; fail=1; }
fi

has_module() {
  grep -q "^usr/lib/calamares/modules/$1/" "$tmp/files"
}

KUTU_CONF_PKG=$(find work/repo -maxdepth 1 -name 'kutu-calamares-config-*.pkg.tar.zst' 2>/dev/null | sort | head -1)
if [ -z "$KUTU_CONF_PKG" ]; then
  echo "FAIL: no built kutu-calamares-config in work/repo (run: make packages)"
  fail=1
else
  tar -tf "$KUTU_CONF_PKG" > "$tmp/kutuconf-files"
  tar -xOf "$KUTU_CONF_PKG" etc/calamares/settings.conf > "$tmp/kutuconf-settings" 2>/dev/null || true
  tar -xOf "$KUTU_CONF_PKG" etc/calamares/modules/bootloader.conf > "$tmp/kutuconf-bootloader" 2>/dev/null || true
  grep -q "^grubInstall:" "$tmp/kutuconf-bootloader" || {
    echo "FAIL: built kutu-calamares-config has old bootloader.conf (stale package vs sources?)"
    fail=1
  }
  grep -q "^etc/calamares/modules/shellprocess@kernel.conf$" "$tmp/kutuconf-files" || {
    echo "FAIL: built kutu-calamares-config lacks shellprocess@kernel.conf (stale package vs sources?)"
    fail=1
  }
  grep -q "^instances:" "$tmp/kutuconf-settings" || {
    echo "FAIL: built kutu-calamares-config settings.conf lacks instances: section (stale package vs sources?)"
    fail=1
  }
  grep -q "^etc/calamares/modules/mount.conf$" "$tmp/kutuconf-files" || {
    echo "FAIL: built kutu-calamares-config lacks mount.conf (stale package vs sources?)"
    fail=1
  }
fi

for mod in "${show[@]}" "${execphase[@]}"; do
  if ! has_module "$mod"; then
    echo "FAIL: module '$mod' in settings.conf does not exist in calamares package"
    fail=1
  fi
done

branding=$(sed -n 's/^branding: *//p' "$CONF")
if [ ! -f "packages/kutu-calamares-config/calamares/branding/$branding/branding.desc" ]; then
  echo "FAIL: branding '$branding' has no branding.desc"
  fail=1
fi

for i in "${!execphase[@]}"; do
  mod=${execphase[$i]}
  desc=$(tar -xOf "$CAL_PKG" "usr/lib/calamares/modules/$mod/module.desc" 2>/dev/null || true)
  reqs=$(sed -n 's/^requiredModules: *\[\(.*\)\]/\1/p' <<< "$desc")
  reqs=${reqs//,/ }
  reqs=${reqs//\"/}
  reqs=${reqs//\'/}
  for req in $reqs; do
    found=-1
    for j in "${!execphase[@]}"; do
      [ "${execphase[$j]}" = "$req" ] && found=$j && break
    done
    if [ "$found" -lt 0 ] || [ "$found" -ge "$i" ]; then
      echo "FAIL: exec module '$mod' requires '$req' to run earlier in exec sequence"
      fail=1
    fi
  done
done

for mod in locale keyboard users; do
  if ! printf '%s\n' "${show[@]}" | grep -qx "$mod"; then continue; fi
  if ! printf '%s\n' "${execphase[@]}" | grep -qx "$mod"; then
    echo "FAIL: '$mod' offers jobs from the show phase but is missing from exec; jobs would never run"
    fail=1
  fi
done

[ "$fail" = 0 ] && echo "calamares-sequence tests: PASS"
exit "$fail"