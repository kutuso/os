#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

CONF="packages/kutu-calamares-config/calamares/settings.conf"
CAL_PKG=$(find work/repo packages/calamares -maxdepth 1 -name 'calamares-*.pkg.tar.zst' -print 2>/dev/null | sort | head -1)
[ -n "$CAL_PKG" ] || { echo "FAIL: no built calamares package found; run: make packages"; exit 1; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
tar -tf "$CAL_PKG" > "$tmp/files"

mapfile -t seq < <(awk '/^ *- show:/ {mode="show"; next} /^ *- exec:/ {mode="exec"; next} /^ *- [a-z]/ {gsub(/^ *- /, ""); print mode":"$0}' "$CONF")

show=()
execphase=()
for entry in "${seq[@]}"; do
  phase=${entry%%:*}
  mod=${entry#*:}
  mod=${mod%%@*}
  [ "$phase" = "show" ] && show+=("$mod") || execphase+=("$mod")
done

has_module() {
  grep -q "^usr/lib/calamares/modules/$1/" "$tmp/files"
}

fail=0
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