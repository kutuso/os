#!/bin/bash
# kutu OS - AMD Driver Installation Script
# Installs AMD open-source drivers, ROCm, and MIOpen

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/var/log/kutu-amd-install.log"

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

error() {
    log "ERROR: $*"
    exit 1
}

log "Starting AMD driver installation..."

# Check if AMD GPU is present
if ! lspci | grep -iE "amd|radeon" > /dev/null; then
    log "No AMD GPU detected. Skipping installation."
    exit 0
fi

log "AMD GPU detected:"
lspci | grep -iE "amd|radeon" | tee -a "$LOG_FILE"

# Install base AMD driver (AMDGPU)
log "Installing AMD driver packages..."
pacman -S --noconfirm --needed \
    mesa \
    lib32-mesa \
    xf86-video-amdgpu \
    vulkan-radeon \
    lib32-vulkan-radeon \
    libva-mesa-driver \
    lib32-libva-mesa-driver \
    mesa-vdpau \
    lib32-mesa-vdpau \
    rocm-hip-sdk \
    rocm-opencl-sdk \
    rocm-smi-lib \
    || error "Failed to install AMD packages"

# Note: ROCm full installation from AUR might be needed
# For now, we install what's available in official repos
log "Note: Full ROCm stack may require AUR packages (rocm-hip-runtime, miopen-hip, etc.)"

# Add user to video and render groups for GPU access
log "Configuring GPU access..."
usermod -aG video,render $(logname) || log "Warning: Could not add user to groups"

# Set up ROCm environment
log "Configuring ROCm environment..."
cat > /etc/profile.d/rocm.sh << 'EOF'
# kutu OS ROCm environment
export ROCM_PATH=/opt/rocm
export PATH=$PATH:/opt/rocm/bin:/opt/rocm/opencl/bin
export LD_LIBRARY_PATH=/opt/rocm/lib:/opt/rocm/lib64${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}
EOF

# Configure GPU for compute workloads
log "Setting AMD GPU performance parameters..."
cat > /etc/modprobe.d/amdgpu.conf << 'EOF'
# kutu OS AMD GPU optimizations
options amdgpu ppfeaturemask=0xffffffff
options amdgpu gpu_recovery=1
options amdgpu vm_update_mode=3
options amdgpu dpm=1
EOF

# Set GPU power profile to compute
log "Creating systemd service for AMD GPU power profile..."
cat > /etc/systemd/system/amdgpu-power-profile.service << 'EOF'
[Unit]
Description=Set AMD GPU power profile to compute
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'for gpu in /sys/class/drm/card*/device/power_dpm_force_performance_level; do echo high > "$gpu"; done'
ExecStart=/bin/bash -c 'for gpu in /sys/class/drm/card*/device/pp_power_profile_mode; do echo 1 > "$gpu"; done'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable amdgpu-power-profile.service
systemctl start amdgpu-power-profile.service || log "Warning: Could not set GPU power profile"

# Update initramfs
log "Updating initramfs..."
mkinitcpio -P || log "Warning: Could not update initramfs"

# Verify installation
log "Verifying AMD driver installation..."
if command -v rocminfo &> /dev/null; then
    rocminfo | head -n 20 | tee -a "$LOG_FILE"
    log "ROCm installed successfully!"
else
    log "Warning: rocminfo not found, ROCm may not be fully installed"
fi

if command -v rocm-smi &> /dev/null; then
    rocm-smi | tee -a "$LOG_FILE"
    log "rocm-smi available"
else
    log "Warning: rocm-smi not found"
fi

log "AMD installation complete. Reboot recommended."
