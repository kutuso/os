#!/usr/bin/env bash
# Automated smoke test: boots the latest ISO in QEMU (inside docker, KVM
# passthrough when available) and asserts the memory-conservation stack is
# live. Exit 0 = all assertions pass.
set -euo pipefail
cd "$(dirname "$0")/.."

latest_iso() { find out -name 'kutu-os-*.iso' -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-; }

if [ "${KUTU_IN_DOCKER:-0}" != 1 ]; then
  ISO=$(latest_iso)
  [ -n "$ISO" ] || { echo "no ISO in out/; run: make build"; exit 1; }
  KVM_FLAGS=()
  [ -w /dev/kvm ] && KVM_FLAGS=(--device /dev/kvm)
  exec docker run --rm "${KVM_FLAGS[@]+"${KVM_FLAGS[@]}"}" \
    -v "$PWD:/w" -w /w -e KUTU_IN_DOCKER=1 -e EXPECT_ISO="/w/$ISO" \
    archlinux:base-devel bash scripts/smoke-test.sh
fi

ISO="${EXPECT_ISO:-$(latest_iso)}"
[ -n "$ISO" ] || { echo "no ISO found"; exit 1; }
pacman -Sy --noconfirm --needed qemu-system-x86 qemu-system-x86-firmware expect >/dev/null 2>&1

KVM_ARGS=""
if [ -w /dev/kvm ]; then KVM_ARGS="-enable-kvm -cpu host"; fi
export KVM_ARGS
mkdir -p work
export SMOKE_LOG=/w/work/smoke.log

expect <<'EOF'
set timeout 1800
log_file -noappend $env(SMOKE_LOG)
spawn qemu-system-x86_64 -m 2048 -display none -serial mon:stdio -nographic {*}$env(KVM_ARGS) -cdrom $env(EXPECT_ISO) -boot d
expect {
  -re {\]# $} {}
  timeout { puts "TIMEOUT waiting for serial root shell"; exit 1 }
}
send -- {echo SMOKE:zswap:$(cat /sys/module/zswap/parameters/compressor):$(cat /sys/module/zswap/parameters/enabled):$(cat /sys/module/zswap/parameters/shrinker_enabled):$(cat /sys/module/zswap/parameters/zpool 2>/dev/null || echo default)}
send "\r"
expect {\]# $}
send -- {echo SMOKE:mglru:$(cat /sys/kernel/mm/lru_gen/enabled):$(cat /sys/kernel/mm/lru_gen/min_ttl_ms)}
send "\r"
expect {\]# $}
send -- {echo SMOKE:damon:$(cat /sys/kernel/mm/damon/admin/kdamonds/0/state 2>/dev/null || echo none)}
send "\r"
expect {\]# $}
send -- {for s in systemd-oomd kutu-memory-early kutu-damon kutu-firstboot NetworkManager lightdm; do echo SMOKE:svc:$s:$(systemctl is-active $s); done}
send "\r"
expect {\]# $}
send -- {kutu-check-kernel; echo SMOKE:ck:$?}
send "\r"
expect {\]# $}
send -- {echo SMOKE:run:$(kutu-run --dry-run firefox /bin/true | grep -c MemoryHigh)}
send "\r"
expect {\]# $}
send -- {echo SMOKE:sessions:$(loginctl --no-legend | wc -l); loginctl --no-legend}
send "\r"
expect {\]# $}
send -- {ls -la /sys/kernel/mm/damon/admin/ /sys/module/zswap/parameters/ | head -25}
send "\r"
expect {\]# $}
send -- {echo 1 > /sys/kernel/mm/damon/admin/nr_kdamonds; echo SMOKE:damon-write:$?; dmesg | tail -3}
send "\r"
expect {\]# $}
send -- {printf zsmalloc > /sys/module/zswap/parameters/zpool 2>&1; echo SMOKE:zpool-write:$?; cat /sys/module/zswap/parameters/zpool}
send "\r"
expect {\]# $}
send -- {bash -x /usr/bin/kutu-damon start 2>&1 | tail -6; echo SMOKE:damon-dbg-done}
send "\r"
expect {\]# $}
send -- {[ -f /home/kutu/Desktop/install-kutu-os.desktop ] && echo SMOKE:launcher:ok || echo SMOKE:launcher:fail; [ -f /usr/share/backgrounds/xfce/kutu-default.svg ] && echo SMOKE:wallpaper:ok || echo SMOKE:wallpaper:fail}
send "\r"
expect {\]# $}
send -- {sleep 90; echo SMOKE:xfce:$(pgrep -c -x xfce4-session || echo 0)}
send "\r"
expect {\]# $}
send -- {[ -f /home/kutu/.config/kutu/wallpaper-applied ] && echo SMOKE:wallpaper-marked:ok || echo SMOKE:wallpaper-marked:fail; grep -q "backgrounds/xfce/kutu-default.svg" /home/kutu/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml && echo SMOKE:wallpaper-set:ok || echo SMOKE:wallpaper-set:fail}
send "\r"
expect {\]# $}
send -- {poweroff}
send "\r"
expect {
  eof {}
  timeout { puts "TIMEOUT waiting for poweroff"; exit 1 }
}
EOF

fail=0
ck() {
  if grep -q "$2" "$SMOKE_LOG"; then echo "PASS: $1"
  else echo "FAIL: $1 (wanted: $2)"; fail=1; fi
}
ckc() {
  n=$(grep -Ec "$2" "$SMOKE_LOG")
  if [ "$n" = "$3" ]; then echo "PASS: $1"
  else echo "FAIL: $1 ($n != $3)"; fail=1; fi
}
ckr() {
  if grep -Eq "$2" "$SMOKE_LOG"; then echo "PASS: $1"
  else echo "FAIL: $1"; fail=1; fi
}

ck "zswap params" "SMOKE:zswap:zstd:Y:Y"
ckr "MGLRU" "SMOKE:mglru:(0x0007|7):1000"
ck "DAMON state" "SMOKE:damon:on"
for s in systemd-oomd kutu-memory-early kutu-damon kutu-firstboot NetworkManager lightdm; do
  ck "service $s" "SMOKE:svc:$s:active"
done
ck "kutu-check-kernel" "SMOKE:ck:0"
ckr "kutu-run" "SMOKE:run:[1-9]"
ckr "XFCE session" "SMOKE:xfce:[1-9]"
ck "desktop installer launcher" "SMOKE:launcher:ok"
ck "default wallpaper installed" "SMOKE:wallpaper:ok"
ck "wallpaper marker set" "SMOKE:wallpaper-marked:ok"
ck "wallpaper set in session config" "SMOKE:wallpaper-set:ok"

if [ "$fail" = 1 ]; then
  echo "SMOKE TEST: FAIL (log: $SMOKE_LOG)"
  exit 1
fi
echo "SMOKE TEST: ALL PASS"
