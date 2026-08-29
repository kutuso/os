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

mapfile -t seq < <(awk '/^ *- show:/ {mode="show"; next} /^ *- exec:/ {mode="exec"; next} /^ *- [a-z]/ {gsub(/^ *- /, ""); print mode":"$0}' "$CONF")

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
  grep -q 'initramfs-linux.img' "$kconf" || { echo "FAIL: shellprocess@kernel.conf does not copy the initramfs"; fail=1; }
fi

has_module() {
  grep -q "^usr/lib/calamares/modules/$1/" "$tmp/files"
}

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