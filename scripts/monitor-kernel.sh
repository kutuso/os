#!/bin/bash
# kutu OS Kernel Performance Monitoring Script
# Real-time monitoring of kernel parameters and system performance
# Usage: ./scripts/monitor-kernel.sh [interval_seconds]

INTERVAL=${1:-2}

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Function to format bytes
format_bytes() {
    local bytes=$1
    if [ "$bytes" -lt 1024 ]; then
        echo "${bytes}B"
    elif [ "$bytes" -lt 1048576 ]; then
        echo "$((bytes / 1024))KB"
    elif [ "$bytes" -lt 1073741824 ]; then
        echo "$((bytes / 1048576))MB"
    else
        echo "$((bytes / 1073741824))GB"
    fi
}

# Function to get thermal status
get_thermal_color() {
    local temp=$1
    if [ "${temp%.*}" -lt 70 ]; then
        echo "$GREEN"
    elif [ "${temp%.*}" -lt 85 ]; then
        echo "$YELLOW"
    else
        echo "$RED"
    fi
}

echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}kutu OS Kernel Monitor${NC}"
echo -e "${BLUE}Press Ctrl+C to exit${NC}"
echo -e "${BLUE}================================${NC}"
echo ""

# Main monitoring loop
while true; do
    clear

    # Header
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}  ${CYAN}kutu OS Kernel Performance Monitor${NC}                           ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}  $(date '+%Y-%m-%d %H:%M:%S')                                       ${BLUE}║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    # ═══════════════════════════════════════════════════════════════════
    # CPU Information
    # ═══════════════════════════════════════════════════════════════════
    echo -e "${MAGENTA}[CPU]${NC}"

    # CPU frequency and governor
    CPU_FREQ=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq 2>/dev/null || echo "0")
    CPU_FREQ_MHZ=$((CPU_FREQ / 1000))
    CPU_GOV=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo "unknown")

    # CPU load
    CPU_LOAD=$(uptime | awk -F'load average:' '{print $2}' | cut -d, -f1-3)

    # CPU usage per core (first 16 cores)
    echo -ne "  Frequencies: "
    for i in {0..15}; do
        if [ -f "/sys/devices/system/cpu/cpu$i/cpufreq/scaling_cur_freq" ]; then
            FREQ=$(cat /sys/devices/system/cpu/cpu$i/cpufreq/scaling_cur_freq 2>/dev/null || echo "0")
            FREQ_GHZ=$(echo "scale=2; $FREQ / 1000000" | bc 2>/dev/null || echo "0")
            echo -ne "${GREEN}${FREQ_GHZ}${NC} "
        fi
    done
    echo ""

    echo -e "  Governor: ${CYAN}${CPU_GOV}${NC}"
    echo -e "  Load Average: ${YELLOW}${CPU_LOAD}${NC}"

    # CPU temperature
    if command -v sensors >/dev/null 2>&1; then
        TEMP=$(sensors 2>/dev/null | grep -i "package id 0" | awk '{print $4}' | tr -d '+°C' || echo "0")
        if [ -n "$TEMP" ] && [ "$TEMP" != "0" ]; then
            TEMP_COLOR=$(get_thermal_color "$TEMP")
            echo -e "  Temperature: ${TEMP_COLOR}${TEMP}°C${NC}"
        fi

        # Core temperatures
        CORE_TEMPS=$(sensors 2>/dev/null | grep "Core" | head -8 | awk '{print $3}' | tr -d '+°C')
        if [ -n "$CORE_TEMPS" ]; then
            echo -ne "  Core Temps: "
            for TEMP in $CORE_TEMPS; do
                TEMP_COLOR=$(get_thermal_color "$TEMP")
                echo -ne "${TEMP_COLOR}${TEMP}°${NC} "
            done
            echo ""
        fi
    fi

    # Check for throttling
    if [ -f /sys/devices/system/cpu/cpu0/thermal_throttle/core_throttle_count ]; then
        THROTTLE=$(cat /sys/devices/system/cpu/cpu0/thermal_throttle/core_throttle_count 2>/dev/null || echo "0")
        if [ "$THROTTLE" -gt 0 ]; then
            echo -e "  ${RED}⚠ Thermal throttling detected: ${THROTTLE} events${NC}"
        fi
    fi

    echo ""

    # ═══════════════════════════════════════════════════════════════════
    # Memory Information
    # ═══════════════════════════════════════════════════════════════════
    echo -e "${MAGENTA}[Memory]${NC}"

    # Parse /proc/meminfo
    MEM_TOTAL=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    MEM_FREE=$(grep MemFree /proc/meminfo | awk '{print $2}')
    MEM_AVAILABLE=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
    MEM_CACHED=$(grep "^Cached:" /proc/meminfo | awk '{print $2}')
    MEM_BUFFERS=$(grep Buffers /proc/meminfo | awk '{print $2}')
    MEM_USED=$((MEM_TOTAL - MEM_FREE - MEM_CACHED - MEM_BUFFERS))
    MEM_PERCENT=$((MEM_USED * 100 / MEM_TOTAL))

    echo -e "  Total: $(format_bytes $((MEM_TOTAL * 1024)))"
    echo -e "  Used:  ${YELLOW}$(format_bytes $((MEM_USED * 1024)))${NC} (${MEM_PERCENT}%)"
    echo -e "  Free:  ${GREEN}$(format_bytes $((MEM_AVAILABLE * 1024)))${NC}"

    # Huge pages
    HP_TOTAL=$(grep HugePages_Total /proc/meminfo | awk '{print $2}')
    HP_FREE=$(grep HugePages_Free /proc/meminfo | awk '{print $2}')
    if [ "$HP_TOTAL" -gt 0 ]; then
        HP_USED=$((HP_TOTAL - HP_FREE))
        HP_SIZE=$(grep Hugepagesize /proc/meminfo | awk '{print $2}')
        HP_TOTAL_MB=$((HP_TOTAL * HP_SIZE / 1024))
        HP_USED_MB=$((HP_USED * HP_SIZE / 1024))
        echo -e "  HugePages: ${CYAN}${HP_USED}${NC}/${HP_TOTAL} (${HP_USED_MB}MB / ${HP_TOTAL_MB}MB)"
    fi

    # Transparent Huge Pages
    THP_ANON=$(grep AnonHugePages /proc/meminfo | awk '{print $2}')
    if [ "$THP_ANON" -gt 0 ]; then
        echo -e "  THP (Anonymous): ${CYAN}$(format_bytes $((THP_ANON * 1024)))${NC}"
    fi

    # Swap
    SWAP_TOTAL=$(grep SwapTotal /proc/meminfo | awk '{print $2}')
    SWAP_FREE=$(grep SwapFree /proc/meminfo | awk '{print $2}')
    if [ "$SWAP_TOTAL" -gt 0 ]; then
        SWAP_USED=$((SWAP_TOTAL - SWAP_FREE))
        SWAP_PERCENT=$((SWAP_USED * 100 / SWAP_TOTAL))
        if [ "$SWAP_USED" -gt 0 ]; then
            echo -e "  Swap: ${RED}$(format_bytes $((SWAP_USED * 1024)))${NC} / $(format_bytes $((SWAP_TOTAL * 1024))) (${SWAP_PERCENT}%)"
        else
            echo -e "  Swap: ${GREEN}Not used${NC}"
        fi
    fi

    echo ""

    # ═══════════════════════════════════════════════════════════════════
    # GPU Information
    # ═══════════════════════════════════════════════════════════════════
    echo -e "${MAGENTA}[GPU]${NC}"

    GPU_FOUND=0

    # AMD GPU
    if command -v rocm-smi >/dev/null 2>&1; then
        GPU_TEMP=$(rocm-smi --showtemp 2>/dev/null | grep -oP "\d+\.\d+c" | head -1 | tr -d 'c')
        GPU_UTIL=$(rocm-smi --showuse 2>/dev/null | grep -oP "\d+%" | head -1 | tr -d '%')
        GPU_MEM=$(rocm-smi --showmeminfo vram 2>/dev/null | grep -oP "\d+ MB" | head -1)

        if [ -n "$GPU_TEMP" ]; then
            TEMP_COLOR=$(get_thermal_color "$GPU_TEMP")
            echo -e "  AMD GPU Temperature: ${TEMP_COLOR}${GPU_TEMP}°C${NC}"
            GPU_FOUND=1
        fi
        if [ -n "$GPU_UTIL" ]; then
            echo -e "  AMD GPU Utilization: ${CYAN}${GPU_UTIL}%${NC}"
        fi
        if [ -n "$GPU_MEM" ]; then
            echo -e "  AMD GPU Memory: ${YELLOW}${GPU_MEM}${NC}"
        fi
    fi

    # NVIDIA GPU
    if command -v nvidia-smi >/dev/null 2>&1; then
        GPU_INFO=$(nvidia-smi --query-gpu=temperature.gpu,utilization.gpu,memory.used,memory.total --format=csv,noheader,nounits 2>/dev/null | head -1)
        if [ -n "$GPU_INFO" ]; then
            GPU_TEMP=$(echo "$GPU_INFO" | cut -d, -f1)
            GPU_UTIL=$(echo "$GPU_INFO" | cut -d, -f2)
            GPU_MEM_USED=$(echo "$GPU_INFO" | cut -d, -f3)
            GPU_MEM_TOTAL=$(echo "$GPU_INFO" | cut -d, -f4)

            TEMP_COLOR=$(get_thermal_color "$GPU_TEMP")
            echo -e "  NVIDIA GPU Temperature: ${TEMP_COLOR}${GPU_TEMP}°C${NC}"
            echo -e "  NVIDIA GPU Utilization: ${CYAN}${GPU_UTIL}%${NC}"
            echo -e "  NVIDIA GPU Memory: ${YELLOW}${GPU_MEM_USED}MB${NC} / ${GPU_MEM_TOTAL}MB"
            GPU_FOUND=1
        fi
    fi

    # Intel GPU
    if command -v intel_gpu_top >/dev/null 2>&1; then
        # intel_gpu_top requires root and JSON output parsing
        echo -e "  Intel GPU: ${CYAN}Use 'sudo intel_gpu_top' for detailed stats${NC}"
        GPU_FOUND=1
    elif [ -d /sys/class/drm/card0 ]; then
        echo -e "  Intel GPU: ${CYAN}Detected${NC}"
        GPU_FOUND=1
    fi

    if [ $GPU_FOUND -eq 0 ]; then
        echo -e "  ${YELLOW}No GPU monitoring tools available${NC}"
    fi

    echo ""

    # ═══════════════════════════════════════════════════════════════════
    # Storage I/O
    # ═══════════════════════════════════════════════════════════════════
    echo -e "${MAGENTA}[Storage I/O]${NC}"

    # NVMe stats
    for nvme in /sys/block/nvme*/stat; do
        if [ -f "$nvme" ]; then
            DEV=$(echo "$nvme" | cut -d/ -f4)
            STATS=$(cat "$nvme")
            READS=$(echo "$STATS" | awk '{print $1}')
            WRITES=$(echo "$STATS" | awk '{print $5}')
            echo -e "  ${DEV}: ${GREEN}${READS}${NC} reads, ${YELLOW}${WRITES}${NC} writes"
        fi
    done

    echo ""

    # ═══════════════════════════════════════════════════════════════════
    # Network Statistics
    # ═══════════════════════════════════════════════════════════════════
    echo -e "${MAGENTA}[Network]${NC}"

    # Find active network interface
    NET_IF=$(ip route get 1.1.1.1 2>/dev/null | grep -oP "dev \K\S+" || echo "")

    if [ -n "$NET_IF" ]; then
        RX_BYTES=$(cat /sys/class/net/$NET_IF/statistics/rx_bytes 2>/dev/null || echo "0")
        TX_BYTES=$(cat /sys/class/net/$NET_IF/statistics/tx_bytes 2>/dev/null || echo "0")
        RX_PACKETS=$(cat /sys/class/net/$NET_IF/statistics/rx_packets 2>/dev/null || echo "0")
        TX_PACKETS=$(cat /sys/class/net/$NET_IF/statistics/tx_packets 2>/dev/null || echo "0")

        echo -e "  Interface: ${CYAN}${NET_IF}${NC}"
        echo -e "  RX: ${GREEN}$(format_bytes $RX_BYTES)${NC} (${RX_PACKETS} packets)"
        echo -e "  TX: ${YELLOW}$(format_bytes $TX_BYTES)${NC} (${TX_PACKETS} packets)"

        # TCP congestion control
        TCP_CC=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo "unknown")
        echo -e "  TCP Congestion: ${CYAN}${TCP_CC}${NC}"
    else
        echo -e "  ${YELLOW}No active network interface${NC}"
    fi

    echo ""

    # ═══════════════════════════════════════════════════════════════════
    # Kernel Parameters
    # ═══════════════════════════════════════════════════════════════════
    echo -e "${MAGENTA}[Kernel Parameters]${NC}"

    SWAPPINESS=$(sysctl -n vm.swappiness 2>/dev/null || echo "60")
    THP_MODE=$(cat /sys/kernel/mm/transparent_hugepage/enabled | grep -o "\[.*\]" | tr -d '[]')
    COMPACTION=$(sysctl -n vm.compaction_proactiveness 2>/dev/null || echo "20")

    echo -e "  Swappiness: ${CYAN}${SWAPPINESS}${NC}"
    echo -e "  THP Mode: ${CYAN}${THP_MODE}${NC}"
    echo -e "  Compaction: ${CYAN}${COMPACTION}${NC}"

    # NUMA
    if [ -d /sys/devices/system/node/node0 ]; then
        NUMA_NODES=$(ls -d /sys/devices/system/node/node* 2>/dev/null | wc -l)
        echo -e "  NUMA Nodes: ${CYAN}${NUMA_NODES}${NC}"
    fi

    echo ""

    # ═══════════════════════════════════════════════════════════════════
    # System Load
    # ═══════════════════════════════════════════════════════════════════
    echo -e "${MAGENTA}[System]${NC}"

    UPTIME=$(uptime -p)
    PROCS=$(ps aux | wc -l)

    echo -e "  Uptime: ${CYAN}${UPTIME}${NC}"
    echo -e "  Processes: ${CYAN}${PROCS}${NC}"

    echo ""
    echo -e "${BLUE}────────────────────────────────────────────────────────────────────${NC}"
    echo -e "Refreshing in ${INTERVAL}s... (Press Ctrl+C to exit)"

    sleep "$INTERVAL"
done
