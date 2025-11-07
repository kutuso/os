#!/bin/bash
# kutu OS - QEMU Test Script
# Test the built ISO in QEMU

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
OUT_DIR="$PROJECT_ROOT/out"

# Find the most recent ISO
ISO_FILE=$(ls -t "$OUT_DIR/"kutu-os-*.iso 2>/dev/null | head -n1)

if [[ -z "$ISO_FILE" ]]; then
    echo "Error: No ISO file found in $OUT_DIR"
    echo "Build the ISO first with: sudo ./scripts/build.sh"
    exit 1
fi

echo "Testing ISO: $ISO_FILE"
echo ""
echo "QEMU will start with:"
echo "  - 8GB RAM"
echo "  - 4 CPU cores"
echo "  - UEFI boot"
echo "  - GPU passthrough (if available)"
echo ""

# Check if QEMU is installed
if ! command -v qemu-system-x86_64 &> /dev/null; then
    echo "Error: QEMU not found. Install with:"
    echo "  sudo pacman -S qemu-full"
    exit 1
fi

# QEMU options
QEMU_OPTS=(
    -machine type=q35,accel=kvm
    -cpu host
    -smp 4
    -m 8G
    -cdrom "$ISO_FILE"
    -boot order=d
    -vga virtio
    -display sdl,gl=on
    -device virtio-net-pci,netdev=net0
    -netdev user,id=net0,hostfwd=tcp::2222-:22
    -bios /usr/share/edk2-ovmf/x64/OVMF.fd
)

# Check if KVM is available
if [[ ! -w /dev/kvm ]]; then
    echo "Warning: KVM not available, using slower emulation"
    QEMU_OPTS=("${QEMU_OPTS[@]//-machine type=q35,accel=kvm/-machine type=q35}")
fi

echo "Starting QEMU..."
qemu-system-x86_64 "${QEMU_OPTS[@]}"
