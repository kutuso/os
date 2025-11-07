#!/bin/bash
# kutu OS - First Boot Setup Script
# Runs on first boot to configure the system

set -e

LOG_FILE="/var/log/kutu-first-boot.log"

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

error() {
    log "ERROR: $*"
    exit 1
}

log "=== kutu OS First Boot Setup ==="
log "Starting system configuration..."

# Check if this is the first boot
SETUP_MARKER="/var/lib/kutu/.first-boot-done"
if [[ -f "$SETUP_MARKER" ]]; then
    log "First boot setup already completed. Exiting."
    exit 0
fi

# Detect hardware
log "Detecting hardware..."

# GPU Detection and Driver Installation
if lspci | grep -i nvidia > /dev/null; then
    log "NVIDIA GPU detected, installing drivers..."
    /usr/local/bin/install-nvidia.sh || log "Warning: NVIDIA driver installation had issues"
fi

if lspci | grep -iE "amd|radeon" > /dev/null; then
    log "AMD GPU detected, installing drivers..."
    /usr/local/bin/install-amd.sh || log "Warning: AMD driver installation had issues"
fi

if lspci | grep -i "intel.*graphics\|intel.*display" > /dev/null; then
    log "Intel GPU detected, installing drivers..."
    /usr/local/bin/install-intel.sh || log "Warning: Intel driver installation had issues"
fi

# Setup CPU governor
log "Configuring CPU for performance..."
/usr/local/bin/setup-cpu-governor.sh || log "Warning: CPU governor setup had issues"

# Setup monitoring tools
log "Setting up system monitoring..."
/usr/local/bin/setup-monitoring.sh || log "Warning: Monitoring setup had issues"

# Enable and start essential services
log "Enabling system services..."
systemctl enable --now NetworkManager
systemctl enable --now sshd
systemctl enable --now docker
systemctl enable --now avahi-daemon
systemctl enable --now sddm

# Setup mDNS hostname
log "Configuring mDNS hostname (kutu.local)..."
hostnamectl set-hostname kutu

# Configure firewall
log "Configuring firewall..."
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow 8080/tcp  # For web UI (when installed)
ufw allow 5353/udp  # mDNS
ufw --force enable || log "Warning: Could not enable firewall"

# Set timezone (default to UTC, user can change)
log "Setting timezone to UTC..."
timedatectl set-timezone UTC
timedatectl set-ntp true

# Update package database
log "Updating package database..."
pacman -Sy || log "Warning: Could not update package database"

# Set up Docker for ML workloads
log "Configuring Docker..."
usermod -aG docker kutu || log "Warning: Could not add user to docker group"

# Create kutu directories
mkdir -p /opt/kutu/{models,data,logs}
chown -R kutu:kutu /opt/kutu

# Display system information
log "System Information:"
log "CPU: $(lscpu | grep 'Model name' | cut -d ':' -f2 | xargs)"
log "Memory: $(free -h | awk '/^Mem:/{print $2}')"
log "GPU(s): $(lspci | grep -iE 'vga|3d|display' | cut -d ':' -f3 | xargs)"

# Mark first boot as complete
mkdir -p "$(dirname "$SETUP_MARKER")"
touch "$SETUP_MARKER"
echo "$(date)" > "$SETUP_MARKER"

log "=== First Boot Setup Complete ==="
log "System is ready. Reboot recommended to apply all changes."
log ""
log "Next steps:"
log "  1. Reboot the system: sudo reboot"
log "  2. Install application stack (inference engines, web UI)"
log "  3. Deploy your first model!"
log ""
log "For more information, visit: https://kutu.so/docs"

# Optional: Display message to user
cat << 'EOF' > /etc/motd
  _  ___   _ _____ _   _    ___  ____
 | |/ / | | |_   _| | | |  / _ \/ ___|
 | ' /| | | | | | | | | | | | | \___ \
 | . \| |_| | | | | |_| | | |_| |___) |
 |_|\_\\___/  |_|  \___/   \___/|____/

Welcome to kutu OS - ML Inference Optimized

System configured and ready for inference workloads.
GPU drivers installed. System optimizations applied.

Documentation: https://kutu.so/docs
Support: https://github.com/kutu-so/os/issues

EOF
