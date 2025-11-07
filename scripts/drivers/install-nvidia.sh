#!/bin/bash
# kutu OS - NVIDIA Driver Installation Script
# Installs NVIDIA proprietary drivers, CUDA toolkit, cuDNN, and TensorRT

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/var/log/kutu-nvidia-install.log"

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

error() {
    log "ERROR: $*"
    exit 1
}

log "Starting NVIDIA driver installation..."

# Check if NVIDIA GPU is present
if ! lspci | grep -i nvidia > /dev/null; then
    log "No NVIDIA GPU detected. Skipping installation."
    exit 0
fi

log "NVIDIA GPU detected:"
lspci | grep -i nvidia | tee -a "$LOG_FILE"

# Install base NVIDIA driver
log "Installing NVIDIA driver packages..."
pacman -S --noconfirm --needed \
    nvidia \
    nvidia-utils \
    nvidia-settings \
    lib32-nvidia-utils \
    opencl-nvidia \
    cuda \
    cuda-tools \
    cudnn \
    || error "Failed to install NVIDIA packages"

# Enable nvidia-persistenced for better performance
log "Configuring NVIDIA persistence daemon..."
systemctl enable nvidia-persistenced.service
systemctl start nvidia-persistenced.service || true

# Set GPU performance mode
log "Setting NVIDIA GPU to maximum performance mode..."
nvidia-smi -pm 1 || log "Warning: Could not enable persistence mode"
nvidia-smi -pl 450 || log "Warning: Could not set power limit" # Adjust based on your GPU

# Configure nvidia-uvm for CUDA
log "Loading NVIDIA UVM module..."
modprobe nvidia-uvm || log "Warning: Could not load nvidia-uvm"

# Add nvidia-uvm to load at boot
if ! grep -q "nvidia-uvm" /etc/modules-load.d/nvidia.conf 2>/dev/null; then
    echo "nvidia-uvm" >> /etc/modules-load.d/nvidia.conf
fi

# Set kernel parameters for optimal NVIDIA performance
log "Configuring kernel parameters..."
cat > /etc/modprobe.d/nvidia.conf << 'EOF'
# kutu OS NVIDIA optimizations
options nvidia-drm modeset=1
options nvidia NVreg_UsePageAttributeTable=1
options nvidia NVreg_InitializeSystemMemoryAllocations=0
options nvidia NVreg_DynamicPowerManagement=0x00
EOF

# Update initramfs
log "Updating initramfs..."
mkinitcpio -P || log "Warning: Could not update initramfs"

# Verify installation
log "Verifying NVIDIA driver installation..."
if command -v nvidia-smi &> /dev/null; then
    nvidia-smi | tee -a "$LOG_FILE"
    log "NVIDIA driver installed successfully!"
else
    error "NVIDIA driver installation failed - nvidia-smi not found"
fi

# Check CUDA installation
if command -v nvcc &> /dev/null; then
    nvcc --version | tee -a "$LOG_FILE"
    log "CUDA toolkit installed successfully!"
else
    log "Warning: CUDA toolkit not found"
fi

log "NVIDIA installation complete. Reboot recommended."
