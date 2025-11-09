#!/bin/bash
# kutu OS - Build Script
# Builds the bootable ISO image using archiso

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_ROOT/work"
OUT_DIR="$PROJECT_ROOT/out"
ARCHISO_DIR="$PROJECT_ROOT/archiso"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[BUILD]${NC} $*"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

error() {
    echo -e "${RED}[ERROR]${NC} $*"
    exit 1
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root. Use: sudo $0"
    fi
}

check_dependencies() {
    log "Checking dependencies..."

    local deps=("archiso" "mksquashfs" "xorriso" "mkfs.fat")
    local missing=()

    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing+=("$dep")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        warn "Missing dependencies: ${missing[*]}"
        log "Installing missing dependencies..."
        pacman -S --noconfirm --needed archiso squashfs-tools libisoburn dosfstools || error "Failed to install dependencies"
    fi

    log "All dependencies satisfied."
}

prepare_build_env() {
    log "Preparing build environment..."

    # Clean previous build
    if [[ -d "$BUILD_DIR" ]]; then
        log "Cleaning previous build..."
        rm -rf "$BUILD_DIR"
    fi

    # Create output directory
    mkdir -p "$OUT_DIR"

    # Copy archiso profile
    cp -r "$ARCHISO_DIR" "$BUILD_DIR"

    # Copy configurations into airootfs
    log "Copying system configurations..."

    # Kernel configs
    mkdir -p "$BUILD_DIR/airootfs/etc/default"
    # Note: cmdline goes into grub/syslinux configs, not a file

    # Systemd configs
    mkdir -p "$BUILD_DIR/airootfs/etc/systemd/system.conf.d"
    cp "$PROJECT_ROOT/configs/systemd/system.conf.d/"*.conf \
       "$BUILD_DIR/airootfs/etc/systemd/system.conf.d/" 2>/dev/null || true

    # Sysctl configs
    mkdir -p "$BUILD_DIR/airootfs/etc/sysctl.d"
    cp "$PROJECT_ROOT/configs/systemd/sysctl.d/"*.conf \
       "$BUILD_DIR/airootfs/etc/sysctl.d/" 2>/dev/null || true

    # Udev rules
    mkdir -p "$BUILD_DIR/airootfs/etc/udev/rules.d"
    cp "$PROJECT_ROOT/configs/systemd/udev.d/"*.rules \
       "$BUILD_DIR/airootfs/etc/udev/rules.d/" 2>/dev/null || true

    # Network configs
    cp "$PROJECT_ROOT/configs/network/nsswitch.conf" \
       "$BUILD_DIR/airootfs/etc/nsswitch.conf" 2>/dev/null || true
    mkdir -p "$BUILD_DIR/airootfs/etc/avahi"
    cp "$PROJECT_ROOT/configs/network/avahi-daemon.conf" \
       "$BUILD_DIR/airootfs/etc/avahi/avahi-daemon.conf" 2>/dev/null || true

    # Copy scripts
    log "Installing system scripts..."
    mkdir -p "$BUILD_DIR/airootfs/usr/local/bin"

    cp "$PROJECT_ROOT/scripts/drivers/"*.sh \
       "$BUILD_DIR/airootfs/usr/local/bin/" 2>/dev/null || true
    cp "$PROJECT_ROOT/scripts/optimize/"*.sh \
       "$BUILD_DIR/airootfs/usr/local/bin/" 2>/dev/null || true
    cp "$PROJECT_ROOT/scripts/first-boot-setup.sh" \
       "$BUILD_DIR/airootfs/usr/local/bin/" 2>/dev/null || true
    cp "$PROJECT_ROOT/scripts/validate-kernel.sh" \
       "$BUILD_DIR/airootfs/usr/local/bin/" 2>/dev/null || true
    cp "$PROJECT_ROOT/scripts/monitor-kernel.sh" \
       "$BUILD_DIR/airootfs/usr/local/bin/" 2>/dev/null || true
    cp "$PROJECT_ROOT/scripts/generate-kernel-params.sh" \
       "$BUILD_DIR/airootfs/usr/local/bin/" 2>/dev/null || true
    cp "$PROJECT_ROOT/scripts/install-kernel-optimizations.sh" \
       "$BUILD_DIR/airootfs/usr/local/bin/" 2>/dev/null || true

    chmod +x "$BUILD_DIR/airootfs/usr/local/bin/"*.sh

    # Copy kernel configuration files for reference
    log "Installing kernel configuration files..."
    mkdir -p "$BUILD_DIR/airootfs/usr/share/kutu/kernel"
    cp "$PROJECT_ROOT/configs/kernel/"* \
       "$BUILD_DIR/airootfs/usr/share/kutu/kernel/" 2>/dev/null || true

    # Copy documentation
    log "Installing documentation..."
    mkdir -p "$BUILD_DIR/airootfs/usr/share/doc/kutu"
    cp "$PROJECT_ROOT/docs/"*.md \
       "$BUILD_DIR/airootfs/usr/share/doc/kutu/" 2>/dev/null || true

    # Create first-boot service
    log "Creating first-boot systemd service..."
    mkdir -p "$BUILD_DIR/airootfs/etc/systemd/system"
    cat > "$BUILD_DIR/airootfs/etc/systemd/system/kutu-first-boot.service" << 'EOF'
[Unit]
Description=kutu OS First Boot Setup
After=multi-user.target
ConditionPathExists=!/var/lib/kutu/.first-boot-done

[Service]
Type=oneshot
ExecStart=/usr/local/bin/first-boot-setup.sh
RemainAfterExit=yes
StandardOutput=journal+console
StandardError=journal+console

[Install]
WantedBy=multi-user.target
EOF

    # Enable first-boot service
    mkdir -p "$BUILD_DIR/airootfs/etc/systemd/system/multi-user.target.wants"
    ln -sf /etc/systemd/system/kutu-first-boot.service \
           "$BUILD_DIR/airootfs/etc/systemd/system/multi-user.target.wants/"

    log "Build environment prepared."
}

install_ml_software() {
    log "Installing ML software into ISO..."
    log "This will take 30-60 minutes and significantly increase ISO size..."

    # Run software installation in chroot
    bash "$SCRIPT_DIR/build-time-install-software.sh" "$BUILD_DIR/airootfs" || warn "Software installation had issues"

    log "ML software installation complete!"
}

build_iso() {
    log "Building ISO image..."
    log "This may take 10-30 minutes depending on your system..."

    cd "$BUILD_DIR"

    # Run mkarchiso
    mkarchiso -v -w work -o "$OUT_DIR" "$BUILD_DIR" || error "ISO build failed"

    log "ISO build complete!"
}

show_results() {
    log "==================================="
    log "kutu OS Build Complete!"
    log "==================================="
    log ""
    log "ISO image location:"
    ls -lh "$OUT_DIR/"*.iso
    log ""
    log "To write to USB:"
    log "  sudo dd if=$OUT_DIR/kutu-os-*.iso of=/dev/sdX bs=4M status=progress"
    log ""
    log "To test in QEMU:"
    log "  $SCRIPT_DIR/test-qemu.sh"
    log ""
}

# Main build process
main() {
    log "==================================="
    log "kutu OS Build System"
    log "==================================="
    log ""

    # Check for --with-software flag
    WITH_SOFTWARE=false
    if [[ "$1" == "--with-software" ]]; then
        WITH_SOFTWARE=true
        log "Building with ML software pre-installed"
    fi

    check_root
    check_dependencies
    prepare_build_env

    # Install ML software if requested
    if [ "$WITH_SOFTWARE" = true ]; then
        install_ml_software
    else
        log "Skipping ML software installation (use --with-software to include)"
    fi

    build_iso
    show_results

    log "Build completed successfully!"
}

main "$@"
