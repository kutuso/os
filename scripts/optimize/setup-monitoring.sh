#!/bin/bash
# kutu OS - System Monitoring Setup
# Installs and configures monitoring tools

set -e

LOG_FILE="/var/log/kutu-monitoring-setup.log"

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

log "Setting up system monitoring tools..."

# Install monitoring packages from AUR (if needed)
MONITORING_PKGS=(
    "nvtop"          # NVIDIA GPU monitor
    "intel-gpu-top"  # Intel GPU monitor (part of intel-gpu-tools)
    "btop"           # Better htop alternative
    "iotop"          # I/O monitor
    "nethogs"        # Network monitor
)

for pkg in "${MONITORING_PKGS[@]}"; do
    if ! pacman -Q "$pkg" &>/dev/null; then
        log "Installing $pkg..."
        pacman -S --noconfirm --needed "$pkg" 2>&1 | tee -a "$LOG_FILE" || log "Warning: Could not install $pkg"
    fi
done

# Create desktop shortcuts for monitoring tools
DESKTOP_DIR="/usr/share/applications"
mkdir -p "$DESKTOP_DIR"

# GPU Monitor shortcut
cat > "$DESKTOP_DIR/gpu-monitor.desktop" << 'EOF'
[Desktop Entry]
Name=GPU Monitor
Comment=Real-time GPU monitoring
Exec=konsole -e bash -c "if command -v nvtop &> /dev/null; then nvtop; elif command -v radeontop &> /dev/null; then radeontop; elif command -v intel_gpu_top &> /dev/null; then intel_gpu_top; else echo 'No GPU monitor found'; read; fi"
Icon=utilities-system-monitor
Terminal=false
Type=Application
Categories=System;Monitor;
EOF

# System Monitor shortcut
cat > "$DESKTOP_DIR/system-monitor.desktop" << 'EOF'
[Desktop Entry]
Name=System Monitor
Comment=Real-time system monitoring
Exec=konsole -e btop
Icon=utilities-system-monitor
Terminal=false
Type=Application
Categories=System;Monitor;
EOF

log "Monitoring tools configured successfully."
