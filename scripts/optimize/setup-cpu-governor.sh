#!/bin/bash
# kutu OS - CPU Governor Setup
# Sets CPU to performance mode for sustained inference workloads

set -e

LOG_FILE="/var/log/kutu-cpu-setup.log"

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

log "Configuring CPU governor for performance..."

# Install cpupower if not present
if ! command -v cpupower &> /dev/null; then
    log "Installing cpupower..."
    pacman -S --noconfirm --needed linux-tools || log "Warning: Could not install cpupower"
fi

# Detect CPU vendor
CPU_VENDOR=$(lscpu | grep "Vendor ID" | awk '{print $3}')
log "CPU Vendor: $CPU_VENDOR"

# Set appropriate CPU frequency driver
if [[ "$CPU_VENDOR" == "GenuineIntel" ]]; then
    log "Intel CPU detected - using intel_pstate"
    # Intel CPUs use intel_pstate driver
    cpupower frequency-set -g performance || log "Warning: Could not set governor"

elif [[ "$CPU_VENDOR" == "AuthenticAMD" ]]; then
    log "AMD CPU detected - using amd-pstate or acpi-cpufreq"
    # AMD CPUs may use amd-pstate (Zen 2+) or acpi-cpufreq
    cpupower frequency-set -g performance || log "Warning: Could not set governor"
else
    log "Unknown CPU vendor, attempting to set performance governor..."
    cpupower frequency-set -g performance || log "Warning: Could not set governor"
fi

# Disable CPU turbo boost to ensure consistent performance (optional)
# Uncomment if you want consistent clocks without turbo variation
# if [[ "$CPU_VENDOR" == "GenuineIntel" ]]; then
#     echo 1 > /sys/devices/system/cpu/intel_pstate/no_turbo
# elif [[ "$CPU_VENDOR" == "AuthenticAMD" ]]; then
#     echo 0 > /sys/devices/system/cpu/cpufreq/boost
# fi

# Set minimum CPU frequency to maximum (no throttling)
log "Setting CPU frequency scaling..."
cpupower frequency-set -d $(cpupower frequency-info -l | awk '{print $2}')MHz || log "Warning: Could not set min frequency"

# Disable CPU idle states for lowest latency (high power usage)
# cpupower idle-set -D 0

# Show current settings
log "Current CPU frequency settings:"
cpupower frequency-info | tee -a "$LOG_FILE"

log "CPU governor configuration complete."
