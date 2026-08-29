#!/usr/bin/env bash
# Interactive: boot the latest ISO in QEMU. On a graphical host it opens
# a window; headless it serves VNC on 127.0.0.1:5900+N (ssh -L from
# another machine to view it).
set -euo pipefail
cd "$(dirname "$0")/.."
ISO=$(find out -name 'kutu-os-*.iso' -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-)
[ -n "$ISO" ] || { echo "no ISO in out/; run: make build"; exit 1; }
RAM="${KUTU_VM_RAM:-2048}"
XRES="${KUTU_VM_XRES:-2560}"
YRES="${KUTU_VM_YRES:-1440}"
DISK="${KUTU_VM_DISK:-32G}"
VNC="${KUTU_VM_VNC:-}"

DRIVE=()
if [ "$DISK" != "0" ] && [ "$DISK" != "none" ]; then
  mkdir -p work
  [ -f work/test-vm-disk.raw ] || truncate -s "$DISK" work/test-vm-disk.raw
  DRIVE=(-drive "file=work/test-vm-disk.raw,format=raw,if=virtio")
fi

if [ -z "$VNC" ] && [ -z "${DISPLAY:-}" ] && [ -z "${WAYLAND_DISPLAY:-}" ]; then
  VNC=0
fi

DISPLAY_ARGS=()
if [ -n "$VNC" ] && [ "$VNC" != "window" ]; then
  case "$VNC" in *[!0-9]*) VNC=0 ;; esac
  DISPLAY_ARGS=(-vnc "127.0.0.1:$VNC")
  port=$((5900 + VNC))
  echo "vnc: 127.0.0.1:$port"
  echo "from another machine: ssh -L $port:localhost:$port <this-host>, then point a vnc viewer at localhost:$port"
fi

KVM=()
[ -w /dev/kvm ] && KVM=(-enable-kvm -cpu host)
exec qemu-system-x86_64 -m "$RAM" "${KVM[@]+"${KVM[@]}"}" "${DRIVE[@]+"${DRIVE[@]}"}" \
  -device "VGA,edid=on,xres=$XRES,yres=$YRES" "${DISPLAY_ARGS[@]+"${DISPLAY_ARGS[@]}"}" \
  -cdrom "$ISO" -boot d \
  -netdev user,id=n0 -device virtio-net-pci,netdev=n0