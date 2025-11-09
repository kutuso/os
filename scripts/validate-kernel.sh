#!/bin/bash
# kutu OS Kernel Configuration Validation Script
# Validates that all kernel optimizations are properly applied
# Usage: sudo ./scripts/validate-kernel.sh

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
PASSED=0
FAILED=0
WARNINGS=0

echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}kutu OS Kernel Validation${NC}"
echo -e "${BLUE}================================${NC}"
echo ""

# Helper functions
check_pass() {
    echo -e "${GREEN}✓ PASS${NC}: $1"
    ((PASSED++))
}

check_fail() {
    echo -e "${RED}✗ FAIL${NC}: $1"
    echo -e "  ${RED}→${NC} $2"
    ((FAILED++))
}

check_warn() {
    echo -e "${YELLOW}⚠ WARN${NC}: $1"
    echo -e "  ${YELLOW}→${NC} $2"
    ((WARNINGS++))
}

check_value() {
    local name=$1
    local expected=$2
    local actual=$3

    if [ "$actual" = "$expected" ]; then
        check_pass "$name = $actual"
    else
        check_fail "$name check" "Expected: $expected, Got: $actual"
    fi
}

check_range() {
    local name=$1
    local min=$2
    local max=$3
    local actual=$4

    if [ "$actual" -ge "$min" ] && [ "$actual" -le "$max" ]; then
        check_pass "$name = $actual (within range $min-$max)"
    else
        check_fail "$name check" "Expected: $min-$max, Got: $actual"
    fi
}

# 1. Check Kernel Version
echo -e "\n${BLUE}[1/10] Kernel Version${NC}"
KERNEL_VERSION=$(uname -r)
KERNEL_MAJOR=$(echo $KERNEL_VERSION | cut -d. -f1)
KERNEL_MINOR=$(echo $KERNEL_VERSION | cut -d. -f2)

echo "Kernel: $KERNEL_VERSION"

if [ "$KERNEL_MAJOR" -gt 6 ] || ([ "$KERNEL_MAJOR" -eq 6 ] && [ "$KERNEL_MINOR" -ge 12 ]); then
    check_pass "Kernel version >= 6.12 (required)"
else
    check_fail "Kernel version check" "Minimum kernel 6.12 required, found $KERNEL_VERSION"
fi

# 2. Check CPU Configuration
echo -e "\n${BLUE}[2/10] CPU Configuration${NC}"

# Check preemption model
PREEMPT=$(grep -o "PREEMPT[_A-Z]*" /boot/config-$(uname -r) | head -1 || echo "UNKNOWN")
echo "Preemption model: $PREEMPT"

if echo "$PREEMPT" | grep -qE "PREEMPT$|PREEMPT_RT"; then
    check_pass "Low-latency preemption enabled"
else
    check_warn "Preemption model" "CONFIG_PREEMPT or CONFIG_PREEMPT_RT recommended for low latency"
fi

# Check timer frequency
HZ=$(grep "CONFIG_HZ=" /boot/config-$(uname -r) | cut -d= -f2)
if [ "$HZ" = "1000" ]; then
    check_pass "Timer frequency = 1000 Hz"
else
    check_warn "Timer frequency" "CONFIG_HZ=1000 recommended, found $HZ"
fi

# Check CPU isolation
if grep -q "isolcpus=" /proc/cmdline; then
    ISOLCPUS=$(grep -o "isolcpus=[^ ]*" /proc/cmdline | cut -d= -f2)
    check_pass "CPU isolation configured: $ISOLCPUS"
else
    check_warn "CPU isolation" "No isolcpus parameter found"
fi

# Check nohz_full
if grep -q "nohz_full=" /proc/cmdline; then
    NOHZ_FULL=$(grep -o "nohz_full=[^ ]*" /proc/cmdline | cut -d= -f2)
    check_pass "Tickless operation on CPUs: $NOHZ_FULL"
else
    check_warn "Tickless operation" "nohz_full parameter not found"
fi

# 3. Check Memory Configuration
echo -e "\n${BLUE}[3/10] Memory Configuration${NC}"

# Check huge pages
THP_ENABLED=$(cat /sys/kernel/mm/transparent_hugepage/enabled)
if echo "$THP_ENABLED" | grep -q "\[madvise\]"; then
    check_pass "Transparent Huge Pages = madvise (optimal)"
elif echo "$THP_ENABLED" | grep -q "\[always\]"; then
    check_warn "Transparent Huge Pages" "madvise mode preferred over always"
else
    check_fail "Transparent Huge Pages" "THP should be enabled"
fi

# Check swappiness
SWAPPINESS=$(sysctl -n vm.swappiness 2>/dev/null || echo "60")
check_range "vm.swappiness" 1 10 "$SWAPPINESS"

# Check memory overcommit
OVERCOMMIT=$(sysctl -n vm.overcommit_memory 2>/dev/null || echo "1")
check_value "vm.overcommit_memory" "0" "$OVERCOMMIT"

# Check huge pages allocation
HUGEPAGES_TOTAL=$(grep HugePages_Total /proc/meminfo | awk '{print $2}')
HUGEPAGES_FREE=$(grep HugePages_Free /proc/meminfo | awk '{print $2}')
echo "HugePages: $HUGEPAGES_FREE / $HUGEPAGES_TOTAL free"

if [ "$HUGEPAGES_TOTAL" -gt 0 ]; then
    check_pass "Static huge pages allocated: $HUGEPAGES_TOTAL"
fi

# Check NUMA
if [ -d /sys/devices/system/node/node0 ]; then
    NUMA_NODES=$(ls -d /sys/devices/system/node/node* 2>/dev/null | wc -l)
    echo "NUMA nodes: $NUMA_NODES"
    if [ "$NUMA_NODES" -gt 1 ]; then
        check_pass "NUMA enabled with $NUMA_NODES nodes"

        # Check if NUMA balancing is enabled
        if grep -q "numa_balancing" /proc/cmdline || [ -f /proc/sys/kernel/numa_balancing ]; then
            NUMA_BALANCING=$(cat /proc/sys/kernel/numa_balancing 2>/dev/null || echo "0")
            if [ "$NUMA_BALANCING" = "1" ]; then
                check_pass "NUMA balancing enabled"
            fi
        fi
    fi
fi

# 4. Check GPU Configuration
echo -e "\n${BLUE}[4/10] GPU Configuration${NC}"

# Detect GPU vendor
GPU_VENDOR=$(lspci | grep -i vga | head -1)
echo "GPU: $GPU_VENDOR"

if echo "$GPU_VENDOR" | grep -qi "amd"; then
    echo "AMD GPU detected"

    # Check amdgpu module
    if lsmod | grep -q amdgpu; then
        check_pass "amdgpu module loaded"

        # Check GTT size
        if grep -q "amdgpu.gttsize=" /proc/cmdline; then
            GTT_SIZE=$(grep -o "amdgpu.gttsize=[^ ]*" /proc/cmdline | cut -d= -f2)
            if [ "$GTT_SIZE" = "131072" ]; then
                check_pass "amdgpu GTT size = 128GB"
            else
                check_warn "amdgpu GTT size" "131072 (128GB) recommended, found $GTT_SIZE"
            fi
        else
            check_warn "amdgpu GTT size" "amdgpu.gttsize=131072 recommended"
        fi
    fi

elif echo "$GPU_VENDOR" | grep -qi "intel"; then
    echo "Intel GPU detected"

    # Check for i915 or xe module
    if lsmod | grep -qE "i915|xe"; then
        check_pass "Intel graphics module loaded"

        # Check GuC
        if grep -q "enable_guc=3" /proc/cmdline; then
            check_pass "Intel GuC/HuC firmware enabled"
        else
            check_warn "Intel GuC" "i915.enable_guc=3 recommended"
        fi
    fi

elif echo "$GPU_VENDOR" | grep -qi "nvidia"; then
    echo "NVIDIA GPU detected"

    if lsmod | grep -q nvidia; then
        check_pass "nvidia module loaded"
    fi
fi

# 5. Check IOMMU
echo -e "\n${BLUE}[5/10] IOMMU Configuration${NC}"

if [ -d /sys/kernel/iommu_groups ]; then
    IOMMU_GROUPS=$(find /sys/kernel/iommu_groups -maxdepth 1 -mindepth 1 -type d | wc -l)
    if [ "$IOMMU_GROUPS" -gt 0 ]; then
        check_pass "IOMMU enabled with $IOMMU_GROUPS groups"

        # Check passthrough mode
        if grep -q "iommu=pt" /proc/cmdline; then
            check_pass "IOMMU passthrough mode enabled"
        else
            check_warn "IOMMU mode" "iommu=pt recommended for performance"
        fi
    fi
else
    check_warn "IOMMU" "IOMMU not detected or not enabled"
fi

# 6. Check Network Configuration
echo -e "\n${BLUE}[6/10] Network Configuration${NC}"

# Check TCP congestion control
TCP_CONGESTION=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo "cubic")
check_value "TCP congestion control" "bbr" "$TCP_CONGESTION"

# Check busy polling
BUSY_POLL=$(sysctl -n net.core.busy_poll 2>/dev/null || echo "0")
if [ "$BUSY_POLL" -gt 0 ]; then
    check_pass "Network busy polling enabled: ${BUSY_POLL}μs"
else
    check_warn "Network busy polling" "Enable net.core.busy_poll for low latency"
fi

# Check socket buffers
RMEM_MAX=$(sysctl -n net.core.rmem_max 2>/dev/null || echo "0")
if [ "$RMEM_MAX" -ge 16777216 ]; then
    check_pass "Socket receive buffer = ${RMEM_MAX} (16MB+)"
else
    check_warn "Socket buffers" "net.core.rmem_max=16777216 recommended"
fi

# 7. Check Storage Configuration
echo -e "\n${BLUE}[7/10] Storage Configuration${NC}"

# Check for NVMe devices
if ls /dev/nvme* >/dev/null 2>&1; then
    NVME_COUNT=$(ls /dev/nvme*n* 2>/dev/null | grep -E "nvme[0-9]+n[0-9]+$" | wc -l)
    echo "NVMe devices found: $NVME_COUNT"

    # Check scheduler
    for nvme in /sys/block/nvme*/queue/scheduler; do
        if [ -f "$nvme" ]; then
            SCHED=$(cat "$nvme" | grep -o "\[.*\]" | tr -d '[]')
            if [ "$SCHED" = "none" ]; then
                check_pass "NVMe scheduler: none (optimal)"
            else
                check_warn "NVMe scheduler" "none recommended, found $SCHED"
            fi
            break
        fi
    done

    # Check power management
    if grep -q "nvme_core.default_ps_max_latency_us=0" /proc/cmdline; then
        check_pass "NVMe power saving disabled"
    else
        check_warn "NVMe power management" "nvme_core.default_ps_max_latency_us=0 recommended"
    fi
fi

# 8. Check Thermal Management
echo -e "\n${BLUE}[8/10] Thermal Management${NC}"

# Check CPU temperature
if command -v sensors >/dev/null 2>&1; then
    TEMP=$(sensors 2>/dev/null | grep -i "package id 0" | awk '{print $4}' | tr -d '+°C' || echo "0")
    if [ -n "$TEMP" ] && [ "$TEMP" != "0" ]; then
        if [ "${TEMP%.*}" -lt 80 ]; then
            check_pass "CPU temperature: ${TEMP}°C (healthy)"
        elif [ "${TEMP%.*}" -lt 90 ]; then
            check_warn "CPU temperature" "${TEMP}°C (warm, monitor for throttling)"
        else
            check_fail "CPU temperature" "${TEMP}°C (hot, likely throttling)"
        fi
    fi
fi

# Check CPU frequency
CPU_FREQ=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq 2>/dev/null || echo "0")
if [ "$CPU_FREQ" != "0" ]; then
    CPU_FREQ_MHZ=$((CPU_FREQ / 1000))
    echo "Current CPU frequency: ${CPU_FREQ_MHZ} MHz"
fi

# Check governor
CPU_GOV=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo "unknown")
echo "CPU governor: $CPU_GOV"
if [ "$CPU_GOV" = "schedutil" ] || [ "$CPU_GOV" = "performance" ]; then
    check_pass "CPU governor: $CPU_GOV (good for AI workloads)"
else
    check_warn "CPU governor" "schedutil or performance recommended, found $CPU_GOV"
fi

# 9. Check Security Mitigations
echo -e "\n${BLUE}[9/10] Security Mitigations${NC}"

if grep -q "mitigations=off" /proc/cmdline; then
    check_warn "Security mitigations" "DISABLED for performance (use only on isolated systems)"
else
    echo "Security mitigations: ENABLED (secure but slower)"
fi

# 10. Check Real-Time Capabilities
echo -e "\n${BLUE}[10/10] Real-Time Capabilities${NC}"

# Check for cyclictest
if command -v cyclictest >/dev/null 2>&1; then
    echo "cyclictest available for latency testing"
    check_pass "Real-time testing tools installed"
else
    check_warn "Real-time testing" "Install rt-tests package for latency measurement"
fi

# Check real-time priority limits
RT_LIMIT=$(ulimit -r 2>/dev/null || echo "0")
if [ "$RT_LIMIT" != "0" ]; then
    check_pass "Real-time priority limit: $RT_LIMIT"
fi

# Summary
echo ""
echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}Validation Summary${NC}"
echo -e "${BLUE}================================${NC}"
echo -e "${GREEN}Passed:${NC}   $PASSED"
echo -e "${YELLOW}Warnings:${NC} $WARNINGS"
echo -e "${RED}Failed:${NC}   $FAILED"
echo ""

if [ $FAILED -eq 0 ]; then
    if [ $WARNINGS -eq 0 ]; then
        echo -e "${GREEN}✓ All checks passed! System is optimally configured.${NC}"
        exit 0
    else
        echo -e "${YELLOW}⚠ System is functional but has some non-optimal settings.${NC}"
        echo -e "${YELLOW}  Review warnings above for potential improvements.${NC}"
        exit 0
    fi
else
    echo -e "${RED}✗ Some critical checks failed.${NC}"
    echo -e "${RED}  Review failures above and fix configuration issues.${NC}"
    exit 1
fi
