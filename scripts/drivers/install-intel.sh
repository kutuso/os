#!/bin/bash
# kutu OS - Intel GPU Driver Installation Script
# Installs Intel GPU drivers, oneAPI, and compute runtime

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/var/log/kutu-intel-install.log"

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

error() {
    log "ERROR: $*"
    exit 1
}

log "Starting Intel GPU driver installation..."

# Check if Intel GPU is present
if ! lspci | grep -i "intel.*graphics\|intel.*display" > /dev/null; then
    log "No Intel GPU detected. Skipping installation."
    exit 0
fi

log "Intel GPU detected:"
lspci | grep -i "intel.*graphics\|intel.*display" | tee -a "$LOG_FILE"

# Install base Intel graphics driver
log "Installing Intel driver packages..."
pacman -S --noconfirm --needed \
    mesa \
    lib32-mesa \
    vulkan-intel \
    lib32-vulkan-intel \
    intel-media-driver \
    libva-intel-driver \
    lib32-libva-intel-driver \
    intel-compute-runtime \
    intel-gpu-tools \
    level-zero-loader \
    || error "Failed to install Intel packages"

# Note: Intel oneAPI requires manual installation or AUR
log "Note: Intel oneAPI toolkit should be installed separately from intel.com"
log "      or from AUR (intel-oneapi-basekit, intel-oneapi-hpckit)"

# Add user to video and render groups for GPU access
log "Configuring GPU access..."
usermod -aG video,render $(logname) || log "Warning: Could not add user to groups"

# Configure Intel GPU parameters
log "Setting Intel GPU parameters..."
cat > /etc/modprobe.d/i915.conf << 'EOF'
# kutu OS Intel GPU optimizations
options i915 enable_guc=3
options i915 enable_fbc=1
options i915 fastboot=1
EOF

# Set up Level Zero environment
cat > /etc/profile.d/level-zero.sh << 'EOF'
# kutu OS Level Zero environment
export ZE_ENABLE_ALT_DRIVERS=libze_intel_gpu.so
EOF

# Create systemd service for Intel GPU power management
log "Creating systemd service for Intel GPU configuration..."
cat > /etc/systemd/system/intel-gpu-config.service << 'EOF'
[Unit]
Description=Configure Intel GPU for compute workloads
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'echo 0 > /sys/class/drm/card0/gt_boost_freq_mhz || true'
ExecStart=/bin/bash -c 'echo performance > /sys/class/drm/card0/power/rc6_enable || true'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable intel-gpu-config.service
systemctl start intel-gpu-config.service || log "Warning: Could not configure GPU settings"

# Update initramfs
log "Updating initramfs..."
mkinitcpio -P || log "Warning: Could not update initramfs"

# Verify installation
log "Verifying Intel driver installation..."
if command -v intel_gpu_top &> /dev/null; then
    log "intel_gpu_top available"
    intel_gpu_frequency | tee -a "$LOG_FILE" || log "Could not query GPU frequency"
else
    log "Warning: intel_gpu_top not found"
fi

# Check OpenCL
if command -v clinfo &> /dev/null; then
    clinfo | grep -i "intel" | tee -a "$LOG_FILE" || log "OpenCL info not available"
else
    log "Note: Install clinfo package to verify OpenCL"
fi

log "Intel installation complete. Reboot recommended."
