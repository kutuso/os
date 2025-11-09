# kutu OS Kernel Configuration Guide

This document describes the comprehensive kernel customizations in kutu OS, optimized for distributed AI inference workloads on modern mini PC hardware (AMD Strix Halo, Intel Lunar Lake).

## Table of Contents

1. [Overview](#overview)
2. [Kernel Requirements](#kernel-requirements)
3. [Configuration Files](#configuration-files)
4. [Key Optimizations](#key-optimizations)
5. [Hardware-Specific Tuning](#hardware-specific-tuning)
6. [Validation and Monitoring](#validation-and-monitoring)
7. [Performance Expectations](#performance-expectations)
8. [Troubleshooting](#troubleshooting)

## Overview

kutu OS uses a heavily customized kernel configuration designed for 24/7 AI inference workloads. The optimizations focus on:

- **Low latency** - Sub-100μs scheduling latency for real-time inference
- **Memory bandwidth** - Huge pages, optimized compaction, NUMA emulation
- **GPU efficiency** - Unified memory, optimal scheduling, firmware-based management
- **Network performance** - BBR congestion control, busy polling, large buffers
- **Thermal stability** - Sustained performance without throttling

### Design Philosophy

Unlike server configurations that chase peak performance, kutu OS prioritizes **sustained performance within thermal constraints**. The configuration prevents thermal throttling while maintaining consistent, predictable behavior for 24/7 operation.

## Kernel Requirements

### Minimum Version

- **Intel Lunar Lake**: Linux 6.12.x (production-ready Xe driver)
- **AMD Strix Halo**: Linux 6.12.x minimum, **6.14+ strongly recommended**

### Why These Versions?

**Linux 6.12** marks the inflection point where:
- Intel Xe2 graphics driver reached production status
- Intel NPU (IVPU) driver matured significantly
- AMD RDNA 3.5 support stabilized
- PREEMPT_RT merged into mainline

**Linux 6.14+** for AMD provides:
- Improved RDNA 3.5 compute performance
- Better firmware support
- Enhanced memory management

## Configuration Files

### Kernel Config Fragment

**Location**: `configs/kernel/config-ai-optimized`

This is a kernel configuration fragment containing all AI/ML optimizations. Merge it with the base Arch kernel config:

```bash
cd /usr/src/linux
scripts/kconfig/merge_config.sh .config /path/to/kutu-os/configs/kernel/config-ai-optimized
make olddefconfig
```

**Key sections**:
- Hardware Support (DRM, GPU drivers, NPU)
- Memory Management (huge pages, HMM, NUMA)
- Low Latency (preemption, tickless, IRQ threading)
- Power Management (balanced for sustained performance)
- Network Optimization (busy polling, large buffers)

### Boot Parameters

**Base parameters**: `configs/kernel/cmdline`

Common parameters for all systems. Key settings:

```
# CPU isolation for dedicated inference
nohz_full=1-31
rcu_nocbs=1-31
isolcpus=managed_irq,domain,1-31
irqaffinity=0
threadirqs

# Memory optimization
transparent_hugepage=madvise
hugepages=2048
numa=fake=4
numa_balancing=enable

# Low latency
preempt=full

# Security tradeoff (isolated systems only)
mitigations=off
```

**AMD-specific**: `configs/kernel/cmdline.amd`

```
amdgpu.gttsize=131072          # 128GB unified memory
ttm.pages_limit=33554432
amd_iommu=on
iommu=pt
amdgpu.sched_policy=0          # Hardware scheduler with over-subscription
amdgpu.cwsr_enable=1           # Compute wave save/restore
amdgpu.mcbp=-1                 # Mid-command buffer preemption
amd_pstate=active              # CPPC for Zen 2+
```

**Intel-specific**: `configs/kernel/cmdline.intel`

```
intel_iommu=on
iommu=pt
i915.enable_guc=3              # GuC submission + HuC firmware
i915.enable_rc6=1              # Render C-states
intel_pstate=active            # Hardware-managed P-states
```

### Runtime Configuration

**Location**: `configs/systemd/sysctl.d/99-kutu-performance.conf`

Applied at boot via systemd. Key parameters:

```bash
# Memory
vm.swappiness=10                      # Strongly prefer RAM
vm.min_free_kbytes=1048576           # 1GB minimum free
vm.compaction_proactiveness=10       # Low to prevent latency spikes

# Network
net.core.busy_poll=50                # Sub-10μs receive latency
net.ipv4.tcp_congestion_control=bbr  # Better throughput
net.core.rmem_max=16777216           # 16MB socket buffers

# NUMA
kernel.numa_balancing_scan_period_min_ms=1000
kernel.numa_balancing_scan_size_mb=256
```

## Key Optimizations

### 1. Memory Management

#### Transparent Huge Pages (THP)

**Mode**: `madvise` (application-controlled)

Why not `always`? The `always` mode causes multi-millisecond stalls during compaction. With `madvise`, only memory regions explicitly marked by ML frameworks get promoted to huge pages.

**Benefits**:
- 512x reduction in TLB entries (4KB → 2MB pages)
- Eliminates address translation overhead
- Critical for multi-GB model weights

**Configuration**:
```bash
# Kernel cmdline
transparent_hugepage=madvise

# Runtime
echo madvise > /sys/kernel/mm/transparent_hugepage/enabled
echo madvise > /sys/kernel/mm/transparent_hugepage/defrag
```

#### NUMA Emulation

**Enabled even on single-socket systems** via `numa=fake=4`

**Benefits**:
- Partitions memory for better cache locality
- Enables testing of NUMA-aware applications
- Can improve performance by reducing cross-die memory access

**Configuration**:
```bash
# Kernel config
CONFIG_NUMA=y
CONFIG_NUMA_BALANCING=y
CONFIG_NUMA_EMU=y

# Kernel cmdline
numa=fake=4
numa_balancing=enable
```

#### Memory Compaction

**Low proactiveness** to prevent latency spikes:

```bash
vm.compaction_proactiveness=10  # Scale 0-100, low = less aggressive
```

Compaction runs only when explicitly needed for huge page allocations, not continuously.

### 2. CPU Optimization

#### Core Isolation

**Reserve CPU 0 for system, isolate others for inference**:

```bash
isolcpus=managed_irq,domain,1-31  # Adjust for your core count
irqaffinity=0                      # IRQs on CPU 0 only
nohz_full=1-31                     # Tickless on isolated CPUs
rcu_nocbs=1-31                     # Offload RCU callbacks
```

**Result**: Isolated CPUs run inference with minimal interruptions.

#### Preemption Model

**CONFIG_PREEMPT=y** for sub-100μs latency

Alternative: **CONFIG_PREEMPT_RT=y** for hard real-time (<50μs) with 5-10% throughput cost.

#### Timer Frequency

**CONFIG_HZ_1000=y** provides 1ms scheduling granularity vs 4ms with default CONFIG_HZ_250.

**Cost**: ~1% CPU overhead from 4x more timer interrupts.
**Benefit**: 4x better scheduling resolution for latency-sensitive tasks.

### 3. GPU Optimization

#### AMD RDNA 3.5 (Strix Halo)

**Unified Memory**: 128GB Graphics Translation Table

```bash
amdgpu.gttsize=131072  # 128GB in MB
```

Without this, allocations limited to 2-8GB.

**Hardware Scheduler**: Over-subscription enabled

```bash
amdgpu.sched_policy=0  # 0=HW scheduler, 1=no oversub, 2=SW (never use)
```

Multiple models can submit work simultaneously; GPU firmware manages execution.

**Compute Wave Save/Restore**: Mid-wave preemption

```bash
amdgpu.cwsr_enable=1
```

Allows hardware scheduler to pause shader execution for fairness.

#### Intel Arc/Xe2 (Lunar Lake)

**GuC Firmware Scheduling**: Offloads to GPU microcontrollers

```bash
i915.enable_guc=3  # GuC submission + HuC firmware
```

Reduces CPU overhead by 15-25% vs CPU-driven polling.

**VM_BIND Architecture**: Modern Xe driver replaces legacy i915 for Arc GPUs.

#### Intel NPU

**Acceleration Framework**: DRM_ACCEL exposes NPU as `/dev/accel/accel0`

```bash
CONFIG_DRM_ACCEL=y
CONFIG_DRM_ACCEL_IVPU=m
```

Best for specific quantized models optimized for NPU architecture.

### 4. Network Optimization

#### BBR Congestion Control

**TCP BBR** for high throughput and low latency:

```bash
net.ipv4.tcp_congestion_control=bbr
net.core.default_qdisc=fq
```

Superior to CUBIC for sustained high-bandwidth P2P communication.

#### Busy Polling

**Sub-10μs receive latency** via direct NIC polling:

```bash
net.core.busy_poll=50      # Poll for 50μs before interrupt
net.core.busy_read=50
```

Burns CPU cycles but eliminates interrupt latency.

#### Large Socket Buffers

**16MB buffers** for high-bandwidth P2P:

```bash
net.core.rmem_max=16777216
net.core.wmem_max=16777216
```

Prevents packet drops during bursty traffic patterns.

### 5. Power Management

#### Schedutil Governor

**Dynamic frequency scaling** based on scheduler load:

```bash
CONFIG_CPU_FREQ_DEFAULT_GOV_SCHEDUTIL=y
```

Ramps to max frequency within 1-2ms when AI inference starts, scales down during idle.

#### Turbo Boost Management

**Disable if thermal throttling occurs** under sustained load:

```bash
# Intel
echo 0 > /sys/devices/system/cpu/intel_pstate/no_turbo

# AMD
echo 0 > /sys/devices/system/cpu/cpufreq/boost
```

**Paradox**: Consistent 3.5GHz often beats 4.5GHz → 2.8GHz throttling.

#### C-State Management

**Limit to C1/C1E** for low-latency response:

```bash
intel_idle.max_cstate=2  # C1/C1E only
```

Deeper C-states (C6/C7) save more power but require 50-100μs to resume.

## Hardware-Specific Tuning

### AMD Strix Halo

**Optimal Configuration**:

```bash
# Kernel cmdline
amdgpu.gttsize=131072
ttm.pages_limit=33554432
amd_iommu=on
iommu=pt
amdgpu.dpm=1
amdgpu.ppfeaturemask=0xffffffff
amd_pstate=active
processor.max_cstate=2

# Runtime (if needed)
echo high > /sys/class/drm/card0/device/power_dpm_force_performance_level
```

**Expected Performance**: 6.14+ kernel provides 10-15% better compute vs 6.12.

### Intel Lunar Lake

**Optimal Configuration**:

```bash
# Kernel cmdline
intel_iommu=on
iommu=pt
i915.enable_guc=3
i915.enable_rc6=1
intel_pstate=active
intel_idle.max_cstate=2
```

**NPU Utilization**: Profile whether your models benefit from NPU offload vs Arc iGPU.

### NVIDIA (If Installed)

**Basic Configuration**:

```bash
# Kernel cmdline
nvidia-drm.modeset=1
nvidia.NVreg_PreserveVideoMemoryAllocations=1

# Persistence daemon
systemctl enable nvidia-persistenced
```

## Validation and Monitoring

### Validation Script

**Location**: `scripts/validate-kernel.sh`

Checks all kernel optimizations:

```bash
sudo ./scripts/validate-kernel.sh
```

**Validates**:
- Kernel version (6.12+)
- Preemption model (CONFIG_PREEMPT)
- Timer frequency (1000 Hz)
- CPU isolation (isolcpus, nohz_full)
- Memory (huge pages, swappiness)
- GPU (drivers, GTT size, GuC)
- IOMMU (enabled, passthrough)
- Network (BBR, busy polling)
- Thermal (temperatures, throttling)

**Exit codes**:
- 0: All checks passed
- 1: Critical failures detected

### Monitoring Script

**Location**: `scripts/monitor-kernel.sh`

Real-time performance monitoring:

```bash
./scripts/monitor-kernel.sh [interval_seconds]
```

**Displays**:
- CPU frequencies, temperatures, load
- Memory usage, huge pages, swap
- GPU temperature, utilization, memory
- Storage I/O statistics
- Network throughput
- Kernel parameters (swappiness, THP mode)

**Refresh interval**: Default 2 seconds

### Latency Testing

**Use cyclictest** for latency validation:

```bash
# Install rt-tests
sudo pacman -S rt-tests

# Measure latency on isolated CPUs
cyclictest -p 95 -m -n -i 1000 -l 100000 -a 1-23

# Expected worst-case latency:
# CONFIG_PREEMPT: <100μs
# CONFIG_PREEMPT_RT: <50μs
```

Higher latencies indicate configuration problems or thermal throttling.

### Thermal Monitoring

**Monitor under representative load** for 1-4 hours:

```bash
# Watch temperatures and frequencies
watch -n1 'sensors && cat /proc/cpuinfo | grep MHz'

# Or use monitoring script
./scripts/monitor-kernel.sh
```

**Decision points**:
- Temps <80°C: Keep turbo boost enabled
- Temps 80-90°C: Consider disabling turbo
- Temps >90°C: Disable turbo, check cooling

## Performance Expectations

### Compared to Stock Arch Linux

**Inference Performance**:
- 10-15% lower latency
- 10-20% higher throughput (tokens/second)
- 5-10% better GPU utilization
- 15-25% faster NVMe I/O

**Consistency**:
- More predictable latency (reduced variance)
- Sustained performance without throttling
- Better multi-model concurrency

### Power Consumption (24/7 Operation)

**Expected ranges** for mini PC:
- Idle: 20-35W
- Light inference: 35-60W
- Peak inference: 60-90W
- Multi-model sustained: 70-85W

**vs Stock**: Slightly higher idle power (~5W) due to limited C-states, but better sustained performance.

## Troubleshooting

### System Won't Boot

**Symptom**: Kernel panic or boot failure

**Solutions**:

1. **Boot with fallback kernel**: Select previous kernel in GRUB
2. **Remove problematic parameters**:
   - Remove `mitigations=off` if suspected
   - Remove `isolcpus=` parameters
   - Change `numa=fake=4` to `numa=off`
3. **Reset to default grub config**:
   ```bash
   # Edit /etc/default/grub
   GRUB_CMDLINE_LINUX_DEFAULT="quiet"
   sudo grub-mkconfig -o /boot/grub/grub.cfg
   ```

### GPU Not Detected

**AMD**:

```bash
# Check module loaded
lsmod | grep amdgpu

# Check dmesg for errors
dmesg | grep amdgpu

# Verify kernel parameters
cat /proc/cmdline | grep amdgpu

# Check firmware
ls /lib/firmware/amdgpu/
```

**Intel**:

```bash
# Check module (i915 or xe)
lsmod | grep -E 'i915|xe'

# Check GuC firmware
dmesg | grep -i guc

# Verify kernel parameters
cat /proc/cmdline | grep i915
```

### High Latency

**Possible causes**:

1. **Thermal throttling**: Check temperatures with `sensors`
2. **Wrong governor**: Should be `schedutil` or `performance`
3. **IRQs on isolated CPUs**: Check `/proc/interrupts`
4. **Swap being used**: Check `free -h`, increase `vm.swappiness`

**Debug**:

```bash
# Run validation
sudo ./scripts/validate-kernel.sh

# Check CPU frequency scaling
cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor

# Check for throttling
sudo turbostat --interval 1

# Measure actual latency
cyclictest -p 95 -m -n -i 1000 -l 10000 -a 1
```

### Memory Allocation Failures

**Symptom**: `ENOMEM` despite available memory

**Causes**:
- Memory fragmentation preventing huge page allocation
- Insufficient `vm.min_free_kbytes`

**Solutions**:

```bash
# Increase min free memory
sudo sysctl vm.min_free_kbytes=2097152  # 2GB

# Trigger compaction
echo 1 | sudo tee /proc/sys/vm/compact_memory

# Check huge pages
grep -i huge /proc/meminfo

# Reduce THP aggressiveness
echo defer > /sys/kernel/mm/transparent_hugepage/defrag
```

### Network Latency Spikes

**Check**:

```bash
# Verify BBR enabled
sysctl net.ipv4.tcp_congestion_control

# Check busy polling
sysctl net.core.busy_poll

# Monitor network IRQs
watch -n1 'cat /proc/interrupts | grep eth0'
```

**Solutions**:

```bash
# Enable busy polling
sudo sysctl net.core.busy_poll=50
sudo sysctl net.core.busy_read=50

# Pin network IRQs to specific CPUs
sudo sh -c 'echo 1 > /proc/irq/130/smp_affinity_list'  # Adjust IRQ number
```

### Thermal Throttling

**Symptom**: Performance drops after sustained load

**Verification**:

```bash
# Check throttle events
cat /sys/devices/system/cpu/cpu0/thermal_throttle/core_throttle_count

# Monitor frequencies under load
watch -n1 'grep MHz /proc/cpuinfo'
```

**Solutions**:

1. **Disable turbo boost**:
   ```bash
   # Intel
   echo 0 | sudo tee /sys/devices/system/cpu/intel_pstate/no_turbo

   # AMD
   echo 0 | sudo tee /sys/devices/system/cpu/cpufreq/boost
   ```

2. **Improve cooling**: Clean fans, improve airflow, reduce ambient temperature

3. **Undervolt** (if BIOS supports): Reduce voltage by 50-100mV

## Advanced Topics

### Custom Kernel Compilation

**Build with optimizations**:

```bash
cd /usr/src/linux
cp /path/to/kutu-os/configs/kernel/config-ai-optimized .
make olddefconfig
make -j$(nproc)
sudo make modules_install
sudo make install
```

**Additional optimizations** (edit .config):

```
CONFIG_GENERIC_CPU=n
CONFIG_MZEN4=y           # AMD Zen 4
CONFIG_MALDERLAKE=y      # Intel Alder/Raptor Lake

CONFIG_CC_OPTIMIZE_FOR_PERFORMANCE=y
CONFIG_LTO_CLANG_THIN=y  # Link-time optimization
```

### RT Kernel Variant

For **hard real-time requirements** (<50μs guaranteed):

```bash
# Enable in kernel config
CONFIG_PREEMPT_RT=y

# Adjust kernel cmdline
isolcpus=1-31 nohz_full=1-31 rcu_nocbs=1-31
threadirqs

# Use SCHED_DEADLINE for inference tasks
chrt -d --sched-runtime 5000000 --sched-deadline 10000000 --sched-period 16666666 0 ./inference
```

**Cost**: 5-10% throughput reduction for deterministic latency.

### RDMA Configuration

For **high-performance clustering** (1-5μs latency):

```bash
# Enable in kernel
CONFIG_INFINIBAND=y
CONFIG_MLX5_CORE=y

# Load modules
modprobe mlx5_core
modprobe mlx5_ib
modprobe ib_umad
modprobe rdma_ucm

# Configure IPoIB
ip link set ib0 up
ip addr add 192.168.100.1/24 dev ib0
```

## References

- [Arch Linux Kernel Documentation](https://wiki.archlinux.org/title/Kernel)
- [Linux Kernel PREEMPT_RT](https://wiki.linuxfoundation.org/realtime/start)
- [AMD GPU Documentation](https://www.kernel.org/doc/html/latest/gpu/amdgpu/)
- [Intel i915 Documentation](https://www.kernel.org/doc/html/latest/gpu/i915.html)
- [NUMA Configuration](https://www.kernel.org/doc/html/latest/vm/numa.html)
- [TCP BBR](https://github.com/google/bbr)

---

**Last Updated**: 2025-01-09
**Kernel Version**: 6.12+ (6.14+ recommended for AMD)
**Status**: Production Ready
