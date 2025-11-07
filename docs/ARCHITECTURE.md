# kutu OS Architecture

This document explains the technical architecture and design decisions of kutu OS.

## Overview

kutu OS is a specialized Arch Linux distribution optimized for 24/7 ML inference workloads. It provides:

- Pre-configured GPU drivers (NVIDIA, AMD, Intel)
- Kernel and system optimizations for sustained compute
- Minimal overhead for maximum inference performance
- Desktop environment with ML monitoring tools

## System Architecture

```
┌─────────────────────────────────────────────────┐
│          User Space / Applications              │
│    (Inference Engines - Separate Repo)          │
├─────────────────────────────────────────────────┤
│              Desktop Environment                │
│         KDE Plasma + Monitoring Tools           │
├─────────────────────────────────────────────────┤
│           System Services Layer                 │
│  NetworkManager │ Docker │ Avahi │ SDDM        │
├─────────────────────────────────────────────────┤
│            GPU Runtime Layer                    │
│  CUDA 12.x  │  ROCm 6.x  │  oneAPI             │
├─────────────────────────────────────────────────┤
│             Driver Layer                        │
│   NVIDIA    │    AMD      │   Intel             │
├─────────────────────────────────────────────────┤
│         Linux Kernel (Optimized)                │
│  - Performance scheduler                        │
│  - Huge pages enabled                           │
│  - NVMe optimizations                           │
│  - Low-latency preemption                       │
├─────────────────────────────────────────────────┤
│              Hardware                           │
│  CPU │ GPU │ Memory │ NVMe │ Network           │
└─────────────────────────────────────────────────┘
```

## Key Components

### 1. Bootloader (GRUB/Syslinux)

**Location:** `archiso/grub/` and `archiso/syslinux/`

**Purpose:** Boot the system with optimized kernel parameters

**Key Parameters:**
- `mitigations=off` - Disable CPU vulnerability mitigations for performance
- `transparent_hugepage=always` - Enable huge pages for large memory allocations
- `nvme_core.default_ps_max_latency_us=0` - Disable NVMe power saving
- `intel_pstate=passive` / `amd_pstate=active` - CPU frequency scaling

### 2. Linux Kernel

**Configuration:** `configs/kernel/`

**Optimizations:**
- **Scheduler:** Voluntary preemption for sustained compute
- **Memory:** Huge pages enabled, swappiness reduced to 10
- **I/O:** mq-deadline scheduler for NVMe, none for raw NVMe
- **CPU:** Performance governor, no turbo boost throttling

**Key Tweaks:**
```
# CPU isolation for inference workloads
nohz_full=1-15          # Disable timer ticks on cores 1-15
rcu_nocbs=1-15          # Offload RCU callbacks from cores 1-15
isolcpus=1-15           # Isolate cores 1-15 from kernel scheduler
```

### 3. System Optimizations

**Location:** `configs/systemd/`

#### sysctl Parameters
```
vm.swappiness = 10                    # Prefer RAM over swap
vm.dirty_ratio = 20                   # Dirty page cache threshold
vm.nr_hugepages = 1024                # Pre-allocate huge pages
net.ipv4.tcp_congestion_control = bbr # BBR congestion control
kernel.sched_latency_ns = 60000000    # Scheduler latency
```

#### udev Rules
```
# NVMe: Use 'none' scheduler (native multiqueue)
KERNEL=="nvme[0-9]*", ATTR{queue/scheduler}="none"

# SSD: Use mq-deadline
KERNEL=="sd[a-z]", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="mq-deadline"
```

### 4. GPU Driver Stack

**Location:** `scripts/drivers/`

#### NVIDIA Stack
```
nvidia-driver
  ├── CUDA Toolkit 12.x
  ├── cuDNN (Deep Learning Library)
  ├── TensorRT (Inference Optimizer)
  └── nvidia-persistenced (Keep GPU initialized)
```

#### AMD Stack
```
amdgpu-driver
  ├── ROCm 6.x Runtime
  ├── MIOpen (Deep Learning Library)
  ├── rocm-smi (System Management)
  └── HIP (CUDA Alternative)
```

#### Intel Stack
```
i915-driver
  ├── oneAPI Base Toolkit
  ├── Level Zero (Compute API)
  ├── oneDNN (Deep Learning Library)
  └── intel-gpu-tools (Monitoring)
```

**Auto-Detection:**
First boot script (`scripts/first-boot-setup.sh`) detects GPU via lspci and installs appropriate drivers.

### 5. Network Configuration

**Location:** `configs/network/`

**Features:**
- **mDNS (Avahi):** Auto-discovery as `kutu.local`
- **NetworkManager:** Automatic network configuration
- **SSH:** Remote access enabled by default
- **Firewall (ufw):** Configured with safe defaults

**mDNS Resolution:**
```
/etc/nsswitch.conf:
  hosts: ... mdns_minimal [NOTFOUND=return] ...
```

This allows accessing the system via `http://kutu.local` on the local network.

### 6. Desktop Environment

**Location:** `configs/desktop/`

**Choice:** KDE Plasma (can be swapped for GNOME)

**Customizations:**
- Dark theme (kutu-dark)
- System monitor widgets on panel
- GPU/CPU/Memory monitoring
- Custom kutu branding

**Display Manager:** SDDM with Wayland (X11 fallback)

### 7. Monitoring Tools

**Included Tools:**
- `nvtop` - NVIDIA GPU monitor
- `radeontop` / `rocm-smi` - AMD GPU monitor
- `intel_gpu_top` - Intel GPU monitor
- `btop` - System resource monitor
- `iotop` - I/O monitor
- `nethogs` - Network monitor

**Desktop Integration:**
- System monitor widget shows real-time stats
- Desktop shortcuts for monitoring tools
- Konsole quick-launch for terminal monitors

### 8. First Boot Process

**Flow:**
```
Boot → Init (systemd) → kutu-first-boot.service
  ↓
Detect Hardware (lspci)
  ↓
Install GPU Drivers (NVIDIA/AMD/Intel)
  ↓
Configure CPU Governor (performance)
  ↓
Setup Monitoring Tools
  ↓
Enable Services (NetworkManager, Docker, SSH, Avahi)
  ↓
Configure Firewall (ufw)
  ↓
Mark First Boot Complete (/var/lib/kutu/.first-boot-done)
  ↓
Display Welcome Message
```

## Design Decisions

### Why Arch Linux?

1. **Rolling Release:** Always latest kernel, drivers, and packages
2. **Minimal Base:** No bloat, only what we need
3. **AUR Access:** Easy access to ML-specific packages
4. **Documentation:** Excellent Arch Wiki
5. **Customization:** Full control over every aspect

### Why Performance Over Security Mitigations?

For dedicated ML inference appliances in trusted environments:
- Mitigations add 10-30% overhead
- Systems are typically air-gapped or on isolated networks
- Performance is critical for 24/7 workloads

**Configurable:** Users can re-enable mitigations if needed.

### Why Huge Pages?

Large models (70B+) benefit from huge pages:
- Reduced TLB misses
- Faster memory access
- Lower page table overhead
- 5-15% performance improvement for inference

### Why 'none' I/O Scheduler for NVMe?

Modern NVMe drives have native multiqueue support:
- Linux schedulers add overhead
- NVMe firmware handles scheduling better
- Lower latency, higher throughput

### Why CPU Core Isolation?

Isolating cores 1-15 from kernel scheduler:
- Cores dedicated to inference workloads
- Reduced context switching
- Consistent performance (no OS interference)
- Core 0 handles system tasks

**Trade-off:** Slightly reduced performance for system tasks, but much better inference performance.

## Performance Expectations

### Baseline vs kutu OS (Estimated Improvements)

| Metric | Stock Arch | kutu OS | Improvement |
|--------|-----------|---------|-------------|
| Inference Latency | 100ms | 85-90ms | 10-15% |
| Throughput (tokens/s) | 100 | 110-120 | 10-20% |
| GPU Utilization | 85% | 95%+ | +10% |
| Memory Latency | Baseline | -5-10% | Faster |
| Disk I/O (NVMe) | Baseline | +15-25% | Faster |

These improvements compound for 24/7 sustained workloads.

## Customization Points

### For Different Workloads

**Training (Not Recommended - Use Separate OS):**
- Remove core isolation
- Increase swappiness
- Enable CPU boost

**Edge Deployment (Low Power):**
- Use 'schedutil' CPU governor instead of 'performance'
- Reduce huge pages
- Enable power management

**Maximum Performance (High Power):**
- Disable ALL power management
- Lock CPU/GPU frequencies to max
- Disable turbo boost (for consistency)

## Security Considerations

**Hardening Options (Optional):**
- Re-enable kernel mitigations
- Enable SELinux/AppArmor
- Restrict SSH to key-only authentication
- Enable automatic security updates

**Trade-offs:**
- 10-30% performance overhead
- Increased complexity
- Potential compatibility issues

For production deployments, balance security vs performance based on your threat model.

## Future Enhancements

- **Custom Kernel:** Compile kernel with ML-specific optimizations
- **RT Kernel Option:** Real-time kernel for ultra-low latency
- **NixOS Port:** Reproducible builds and declarative configs
- **Immutable Variant:** Read-only root with overlayfs
- **ARM Support:** NVIDIA Jetson, Apple Silicon

## References

- [Arch Linux Wiki](https://wiki.archlinux.org/)
- [Linux Kernel Documentation](https://www.kernel.org/doc/)
- [NVIDIA CUDA Documentation](https://docs.nvidia.com/cuda/)
- [AMD ROCm Documentation](https://rocmdocs.amd.com/)
- [Intel oneAPI Documentation](https://www.intel.com/content/www/us/en/developer/tools/oneapi/overview.html)

## Support

- Technical questions: https://github.com/kutu-so/os/issues
- Community: https://discord.gg/kutu-os
- Documentation: https://kutu.so/docs
