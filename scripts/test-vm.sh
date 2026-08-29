#!/usr/bin/env bash
# Interactive: boot the latest ISO in a QEMU window on the host.
set -euo pipefail
cd "$(dirname "$0")/.."
ISO=$(find out -name 'kutu-os-*.iso' -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-)
[ -n "$ISO" ] || { echo "no ISO in out/; run: make build"; exit 1; }
RAM="${KUTU_VM_RAM:-2048}"
XRES="${KUTU_VM_XRES:-2560}"
YRES="${KUTU_VM_YRES:-1440}"
KVM=()
[ -w /dev/kvm ] && KVM=(-enable-kvm -cpu host)
exec qemu-system-x86_64 -m "$RAM" "${KVM[@]+"${KVM[@]}"}" \
  -device "VGA,edid=on,xres=$XRES,yres=$YRES" \
  -cdrom "$ISO" -boot d \
  -netdev user,id=n0 -device virtio-net-pci,netdev=n0