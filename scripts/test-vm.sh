#!/usr/bin/env bash
# Interactive: boot the latest ISO in a QEMU window on the host.
set -euo pipefail
cd "$(dirname "$0")/.."
ISO=$(find out -name 'kutu-os-*.iso' -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-)
[ -n "$ISO" ] || { echo "no ISO in out/; run: make build"; exit 1; }
RAM="${KUTU_VM_RAM:-2048}"
XRES="${KUTU_VM_XRES:-2560}"
YRES="${KUTU_VM_YRES:-1440}"
DISK="${KUTU_VM_DISK:-32G}"
DRIVE=()
if [ "$DISK" != "0" ] && [ "$DISK" != "none" ]; then
  mkdir -p work
  [ -f work/test-vm-disk.raw ] || truncate -s "$DISK" work/test-vm-disk.raw
  DRIVE=(-drive "file=work/test-vm-disk.raw,format=raw,if=virtio")
fi
KVM=()
[ -w /dev/kvm ] && KVM=(-enable-kvm -cpu host)
exec qemu-system-x86_64 -m "$RAM" "${KVM[@]+"${KVM[@]}"}" "${DRIVE[@]+"${DRIVE[@]}"}" \
  -device "VGA,edid=on,xres=$XRES,yres=$YRES" \
  -cdrom "$ISO" -boot d \
  -netdev user,id=n0 -device virtio-net-pci,netdev=n0