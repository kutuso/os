# Building kutu OS

This guide explains how to build the kutu OS ISO image from source.

## Prerequisites

### System Requirements
- Arch Linux or Arch-based distribution (Manjaro, EndeavourOS, etc.)
- At least 20GB free disk space
- Root/sudo access
- Internet connection

### Required Packages
The build script will install these automatically, but you can install them manually:

```bash
sudo pacman -S archiso squashfs-tools libisoburn dosfstools
```

## Build Process

### Quick Start (Recommended)

```bash
# Clone the repository
git clone https://github.com/kutu-so/os.git kutu-os
cd kutu-os

# Check system and install dependencies
make check
make install-deps

# Build the ISO
sudo make build

# Test it
make test
```

### Method 1: Using Makefile (Recommended)

The Makefile provides a convenient interface to all build operations:

```bash
# Show all available commands
make help

# Check if your system meets requirements
make check

# Install required packages
make install-deps

# Validate configuration files
make validate

# Build the ISO
sudo make build

# Clean build artifacts
sudo make clean

# Test in QEMU
make test

# Write to USB interactively
sudo make install-usb
```

### Method 2: Using Build Script Directly

```bash
sudo ./scripts/build.sh
```

### Build Process Details

The build process will:
1. Check dependencies and install if missing
2. Prepare the build environment
3. Copy configurations and scripts
4. Build the ISO image (10-30 minutes)
5. Output the ISO to `out/` directory

### Build Output

After successful build, you'll find:

```
out/
└── kutu-os-YYYY.MM.DD-x86_64.iso
```

### Makefile Targets Explained

| Target | Description | Requires Root |
|--------|-------------|---------------|
| `make help` | Show all available commands | No |
| `make build` | Build the ISO image | Yes |
| `make clean` | Remove build artifacts | Yes |
| `make distclean` | Remove build artifacts and ISOs | Yes |
| `make test` | Test ISO in QEMU | No |
| `make install-deps` | Install required packages | No (uses sudo) |
| `make check` | Check system requirements | No |
| `make validate` | Validate configuration files | No |
| `make install-usb` | Write ISO to USB (interactive) | Yes |
| `make docs` | View documentation | No |
| `make info` | Show build information | No |
| `make quick` | Build and test in one command | Yes |

## Testing the ISO

### Test in QEMU (Virtual Machine)

```bash
./scripts/test-qemu.sh
```

This will:
- Launch QEMU with 8GB RAM and 4 CPU cores
- Boot from the ISO
- Enable KVM acceleration if available
- Forward SSH port 2222 to VM port 22

### Test on Real Hardware

#### Option 1: USB Drive

```bash
# Find your USB device (e.g., /dev/sdb)
lsblk

# Write ISO to USB (CAUTION: This will erase the drive!)
sudo dd if=out/kutu-os-*.iso of=/dev/sdX bs=4M status=progress conv=fsync

# Replace /dev/sdX with your actual USB device
```

#### Option 2: Ventoy

1. Install [Ventoy](https://www.ventoy.net/) on your USB drive
2. Copy the ISO file to the USB drive
3. Boot from USB and select the ISO

## Customization Before Building

### Adding Packages

Edit `archiso/packages.x86_64` and add package names:

```
# Your custom packages
package-name
another-package
```

### Custom Configurations

Add or modify files in:
- `configs/kernel/` - Kernel parameters
- `configs/systemd/` - System optimizations
- `configs/desktop/` - Desktop environment
- `configs/network/` - Network settings

### Custom Scripts

Add scripts to:
- `scripts/drivers/` - Driver installation
- `scripts/optimize/` - System optimizations
- `scripts/` - Build and setup scripts

### Branding

Replace files in:
- `configs/desktop/branding/` - Logos and icons
- `configs/desktop/themes/` - Color schemes
- `configs/desktop/wallpapers/` - Background images

## Troubleshooting

### Build Fails with "Permission Denied"

Make sure you're running the build script with sudo:
```bash
sudo ./scripts/build.sh
```

### "archiso command not found"

Install the archiso package:
```bash
sudo pacman -S archiso
```

### Out of Disk Space

The build process requires at least 20GB:
- Clean old builds: `sudo rm -rf work/ out/`
- Free up space: `sudo pacman -Sc`

### Build Hangs or Fails

1. Check your internet connection
2. Update mirrorlist: `sudo reflector --latest 20 --sort rate --save /etc/pacman.d/mirrorlist`
3. Clean and retry: `sudo rm -rf work/ && sudo ./scripts/build.sh`

### Package Download Fails

```bash
# Update package database
sudo pacman -Sy

# Update mirrors
sudo reflector --latest 20 --protocol https --sort rate --save /etc/pacman.d/mirrorlist

# Retry build
sudo ./scripts/build.sh
```

## Advanced Customization

### Custom Kernel

To build with a custom kernel:

1. Create kernel config in `configs/kernel/`
2. Modify `archiso/packages.x86_64` to use your kernel package
3. Update bootloader configs in `archiso/grub/` and `archiso/syslinux/`

### Multiple GPU Support

The first-boot script automatically detects and installs drivers for:
- NVIDIA (CUDA)
- AMD (ROCm)
- Intel (oneAPI)

To add custom GPU configurations, modify `scripts/drivers/install-*.sh`

### Custom Services

Add systemd services to `archiso/airootfs/etc/systemd/system/`

Enable them in `scripts/first-boot-setup.sh`

## Build Flags

The build script supports several environment variables:

```bash
# Set custom output directory
OUT_DIR=/custom/path sudo ./scripts/build.sh

# Verbose build
VERBOSE=1 sudo ./scripts/build.sh

# Skip package updates
SKIP_UPDATE=1 sudo ./scripts/build.sh
```

## Continuous Integration

See `.github/workflows/build.yml` for automated builds (if using GitHub Actions).

## Next Steps

After building:
1. [Test the ISO](TESTING.md)
2. [Install on hardware](INSTALLATION.md)
3. [Configure the system](CONFIGURATION.md)

## Support

- Documentation: https://kutu.so/docs
- Issues: https://github.com/kutu-so/os/issues
- Community: https://discord.gg/kutu-os
