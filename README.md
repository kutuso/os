# kutu OS

**The Arch-based Linux distribution optimized for ML inference workloads**

kutu OS is a custom Arch Linux distribution designed from the ground up to provide optimal performance for running machine learning models locally. This is the OS layer only - applications run on top.

## Features

### 🚀 Performance Optimizations

- **Custom Kernel**: Linux kernel with ML inference optimizations
  - Low-latency preemption settings
  - Optimized scheduler for sustained compute workloads
  - CPU frequency governor tuned for consistent performance
  - Memory management optimized for large model loading
  - I/O scheduler configured for NVMe Gen 5 storage

### 🎮 GPU Driver Support (Pre-installed)

- **NVIDIA**: CUDA 12.x toolkit with cuDNN, TensorRT
- **AMD**: ROCm 6.x with MIOpen
- **Intel**: oneAPI with oneDNN

### ⚡ System-Level Optimizations

- **CPU**: Performance governor, core parking disabled
- **Memory**: Huge pages enabled, swappiness tuned
- **Storage**: NVMe optimizations, fstrim enabled
- **Networking**: High-performance stack, mDNS auto-discovery
- **Power**: Optimized for sustained 24/7 operation

### 🎨 The Bling

- Custom desktop environment (KDE Plasma/GNOME - TBD)
- kutu branding and theme
- System monitoring widgets showing GPU/CPU/Memory
- Boot splash and animations
- Custom terminal theme

### 🔧 System Software

- **Container Runtime**: Docker pre-installed
- **Monitoring**: htop, nvtop, rocm-smi, intel-gpu-tools
- **Development**: GCC, Python, Rust toolchains
- **Network**: mDNS responder for kutu.local discovery
- **Security**: Firewall configured, auto-updates enabled

## Directory Structure

```
kutu-os/
├── archiso/              # Main build configuration
│   ├── airootfs/         # Root filesystem overlay
│   │   ├── etc/          # System configurations
│   │   ├── usr/          # User binaries and libraries
│   │   └── opt/          # Optional software
│   ├── efiboot/          # EFI boot configuration
│   ├── syslinux/         # BIOS boot configuration
│   └── grub/             # GRUB configuration
├── configs/              # System configuration files
│   ├── kernel/           # Kernel config and patches
│   ├── drivers/          # Driver installation configs
│   ├── systemd/          # Systemd unit files
│   └── desktop/          # Desktop environment configs
├── scripts/              # Build and installation scripts
│   ├── build.sh          # Main build script
│   ├── drivers/          # Driver installation scripts
│   └── optimize/         # System optimization scripts
├── docs/                 # Documentation
└── README.md            # This file
```

## Building kutu OS

### Prerequisites

- Arch Linux host system (or Arch-based distro)
- `archiso` package installed
- At least 20GB free disk space
- Root/sudo access

### Build Instructions

```bash
# Install dependencies
sudo pacman -S archiso

# Clone repository
git clone https://github.com/kutu-so/os.git kutu-os
cd kutu-os

# Build the ISO
sudo ./scripts/build.sh

# Output will be in out/
```

### Installation

```bash
# Write to USB drive (replace /dev/sdX with your device)
sudo dd if=out/kutu-os-*.iso of=/dev/sdX bs=4M status=progress

# Boot from USB and follow installer
```

## System Requirements

### Minimum

- CPU: 16-core x86_64 processor
- RAM: 128GB DDR5/DDR6
- GPU: NVIDIA RTX 40-series (20GB+), AMD RX 7000-series (16GB+), or Intel Arc
- Storage: 500GB NVMe Gen 4+
- Network: 1GbE

### Recommended (Professional/Industrial)

- CPU: 32+ core AMD Threadripper or Intel Xeon
- RAM: 256GB+ DDR5/DDR6 ECC
- GPU: NVIDIA RTX 60-series (64GB+) or dual GPU
- Storage: 2TB+ NVMe Gen 5 RAID
- Network: 10GbE

## Architecture

### Boot Process

1. **Bootloader (GRUB/systemd-boot)**: Optimized boot parameters
2. **Kernel**: Custom kernel with inference optimizations
3. **Init (systemd)**: Parallel service startup
4. **Driver Loading**: Automatic GPU driver detection and loading
5. **Display Manager**: Auto-login to kutu user
6. **Desktop Environment**: Launch with system monitor

### Key Components

- **Kernel**: Linux 6.12+ with custom config
- **Init**: systemd with custom units
- **Package Manager**: pacman with custom repos
- **Display Server**: Wayland/X11
- **Desktop**: KDE Plasma or GNOME
- **GPU Drivers**: Pre-compiled and configured

## Configuration

### Kernel Parameters

Located in `configs/kernel/cmdline`:

- `mitigations=off` - Disable CPU vulnerability mitigations for performance
- `intel_pstate=passive` or `amd_pstate=active` - CPU frequency scaling
- `transparent_hugepage=always` - Large page support
- `nvme_core.default_ps_max_latency_us=0` - Disable NVMe power saving

### System Tuning

Located in `configs/systemd/`:

- CPU governor: performance
- I/O scheduler: mq-deadline for NVMe
- Swappiness: 10
- Huge pages: Enabled with dynamic allocation

### GPU Configuration

Located in `configs/drivers/`:

- NVIDIA: Persistence mode enabled, power management optimized
- AMD: ROCm device permissions, GPU clocks
- Intel: Compute runtime configured

## Customization

### Adding Packages

Edit `archiso/packages.x86_64`:

```
# Add your packages here
package-name
another-package
```

### Custom Configurations

Add files to `archiso/airootfs/` matching the root filesystem structure:

```
archiso/airootfs/etc/myconfig.conf  -> /etc/myconfig.conf
```

### Branding

- Logos: `configs/desktop/branding/`
- Themes: `configs/desktop/themes/`
- Wallpapers: `configs/desktop/wallpapers/`

## Testing

```bash
# Test in QEMU
./scripts/test-qemu.sh

# Test in VirtualBox
./scripts/test-vbox.sh
```

### Areas for Contribution

- Kernel optimizations for specific hardware
- Driver automation and detection
- Desktop environment customization
- Boot time optimization
- Power management tuning
- Security hardening

## License

MIT License - See LICENSE file

## Links

- Website: https://kutu.so
- Concept Doc: ../concept/README.md
- Issue Tracker: https://github.com/kutu-so/os/issues

---

**kutu OS**: Built for 24/7 ML inference workloads. Ship it.
