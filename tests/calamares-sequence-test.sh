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
  grep -q 'mkinitcpio.conf.d/archiso.conf' "$kconf" || { echo "FAIL: shellprocess@kernel.conf must remove the archiso mkinitcpio drop-in; it overrides HOOKS and rebuilds a live-only initramfs"; fail=1; }
  if grep -q 'HOOKS=' "$kconf"; then
    echo "FAIL: shellprocess@kernel.conf hand-writes HOOKS; initcpiocfg must derive them from the actual partitions (a hand-written list missing block/filesystems/encrypt breaks installed boot)"
    fail=1
  fi
fi

icfgpos=-1; ibuildpos=-1
for i in "${!execraw[@]}"; do
  [ "${execraw[$i]}" = "initcpiocfg" ] && icfgpos=$i
  [ "${execraw[$i]}" = "initcpio" ] && ibuildpos=$i
done
[ "$icfgpos" -ge 0 ] || { echo "FAIL: initcpiocfg missing from exec sequence"; fail=1; }
[ "$ibuildpos" -ge 0 ] || { echo "FAIL: initcpio missing from exec sequence"; fail=1; }
if [ "$icfgpos" -ge 0 ] && [ "$ibuildpos" -ge 0 ] && [ "$kpos" -ge 0 ]; then
  [ "$icfgpos" -gt "$kpos" ] || { echo "FAIL: initcpiocfg must run after the kernel copy (shellprocess@kernel)"; fail=1; }
  [ "$ibuildpos" -gt "$icfgpos" ] || { echo "FAIL: initcpio must run after initcpiocfg"; fail=1; }
  [ "$ibuildpos" -lt "$bpos" ] || { echo "FAIL: initramfs must be built before the bootloader"; fail=1; }
fi
iconf="$CONF_DIR/modules/initcpio.conf"
[ -f "$iconf" ] || { echo "FAIL: missing $iconf"; fail=1; }
if [ -f "$iconf" ]; then
  grep -q '^kernel: linux' "$iconf" || { echo "FAIL: initcpio.conf must select the linux preset"; fail=1; }
fi

dconf="$CONF_DIR/modules/shellprocess@done.conf"
if [ -f "$dconf" ]; then
  if grep -Eq '^ *- "-' "$dconf"; then
    echo "FAIL: shellprocess@done suppresses command failures with a leading '-'; silent cleanup failure leaves root autologin / passwordless sudo installed"
    fail=1
  fi
  grep -q 'kutuso.github.io/os/repo' "$dconf" || { echo "FAIL: shellprocess@done must write the canonical kutuso repo URL into the target pacman.conf"; fail=1; }
  grep -q 'ssh_host_' "$dconf" || { echo "FAIL: shellprocess@done must remove live-generated SSH host keys from the target"; fail=1; }
  grep -q 'disable sshd' "$dconf" || { echo "FAIL: shellprocess@done must disable sshd in the target"; fail=1; }
  grep -q 'firstboot-done' "$dconf" || { echo "FAIL: shellprocess@done must remove the live firstboot marker so the installed system recalibrates"; fail=1; }
  grep -q 'initramfs-linux.img' "$dconf" || { echo "FAIL: shellprocess@done must verify the target initramfs was built"; fail=1; }
fi

for inst in kernel 'done'
do
  grep -Eq "^ *- module: shellprocess$" "$CONF" || { echo "FAIL: settings.conf has no instances: section; custom instances like shellprocess@$inst silently load without config and no-op"; fail=1; break; }
  grep -Eq "^ *id: $inst\$" "$CONF" || { echo "FAIL: instances: section does not declare shellprocess@$inst"; fail=1; }
  grep -q "config: shellprocess@$inst.conf" "$CONF" || { echo "FAIL: shellprocess@$inst instance does not point at shellprocess@$inst.conf"; fail=1; }
done

uconf="$CONF_DIR/modules/users.conf"
grep -q "^sudoersGroup: wheel" "$uconf" || { echo "FAIL: users.conf must set sudoersGroup: wheel (the users module writes /etc/sudoers.d/10-installer from it; arch ships %wheel commented out, so without it the installed user cannot sudo)"; fail=1; }
grep -q "^doAutologin: false" "$uconf" || { echo "FAIL: users.conf must default autologin off (empty-password autologin admin risk)"; fail=1; }
grep -q "minLength: 8" "$uconf" || { echo "FAIL: users.conf must enforce a minimum password length"; fail=1; }

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