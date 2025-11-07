# kutu OS Makefile Reference

Complete reference for the kutu OS Makefile build system.

## Overview

The Makefile provides a convenient interface to build, test, and manage kutu OS. It handles dependency checking, validation, and provides helpful feedback with colored output.

## Quick Reference

```bash
make help          # Show all commands
make build         # Build ISO
make test          # Test in QEMU
make clean         # Clean build files
make install-usb   # Write to USB
```

## All Available Targets

### Primary Targets

#### `make help`
**Description:** Display help message with all available targets
**Requires root:** No
**Example:**
```bash
make help
```

#### `make build`
**Description:** Build the kutu OS ISO image
**Requires root:** Yes
**Time:** 10-30 minutes
**Output:** `out/kutu-os-YYYY.MM.DD-x86_64.iso`
**Example:**
```bash
sudo make build
```

#### `make clean`
**Description:** Remove build artifacts from `work/` directory
**Requires root:** Yes
**Example:**
```bash
sudo make clean
```

#### `make distclean`
**Description:** Remove all build artifacts AND output ISOs
**Requires root:** Yes
**Example:**
```bash
sudo make distclean
```

#### `make test` or `make test-qemu`
**Description:** Test the ISO in QEMU virtual machine
**Requires root:** No
**Prerequisites:** Built ISO must exist
**QEMU Settings:**
- 8GB RAM
- 4 CPU cores
- KVM acceleration (if available)
- UEFI boot

**Example:**
```bash
make test
```

### Utility Targets

#### `make check`
**Description:** Check system requirements
**Requires root:** No
**Checks:**
- Operating system (Arch Linux)
- Available disk space (20GB+)
- Required commands (mkarchiso, mksquashfs, etc.)

**Example:**
```bash
make check
```

#### `make install-deps`
**Description:** Install required dependencies
**Requires root:** No (uses sudo internally)
**Installs:**
- archiso
- squashfs-tools
- libisoburn
- dosfstools

**Example:**
```bash
make install-deps
```

#### `make validate`
**Description:** Validate configuration files and scripts
**Requires root:** No
**Validates:**
- Required files exist
- Scripts are executable
- Configuration completeness

**Example:**
```bash
make validate
```

#### `make install-usb`
**Description:** Interactive USB installation
**Requires root:** Yes
**Features:**
- Shows available drives
- Interactive device selection
- Safety confirmations
- Progress display

**Example:**
```bash
sudo make install-usb
```

**Interactive prompts:**
```
1. Lists available drives with sizes
2. Prompts for device name (e.g., "sdb")
3. Final confirmation (type "yes")
4. Writes ISO with progress
```

#### `make docs`
**Description:** View documentation files
**Requires root:** No
**Options:**
1. README.md
2. docs/BUILDING.md
3. docs/ARCHITECTURE.md
4. CONTRIBUTING.md

**Example:**
```bash
make docs
```

#### `make info`
**Description:** Show build information
**Requires root:** No
**Displays:**
- Project name
- Build/output directories
- Existing ISO images
- Directory sizes

**Example:**
```bash
make info
```

### Advanced Targets

#### `make quick`
**Description:** Build and test in one command
**Requires root:** Yes
**Equivalent to:** `make build && make test`
**Example:**
```bash
sudo make quick
```

#### `make list`
**Description:** List all available Makefile targets
**Requires root:** No
**Example:**
```bash
make list
```

## Workflow Examples

### First Time Build

```bash
# 1. Check your system
make check

# 2. Install dependencies if needed
make install-deps

# 3. Validate configurations
make validate

# 4. Build the ISO
sudo make build

# 5. Test it
make test
```

### Iterative Development

```bash
# Make changes to configs or scripts
vim configs/kernel/cmdline

# Validate changes
make validate

# Clean previous build
sudo make clean

# Rebuild
sudo make build

# Test
make test
```

### Creating Bootable USB

```bash
# Build if not already built
sudo make build

# Interactive USB installation (safer)
sudo make install-usb

# Or manual dd (faster, less safe)
sudo dd if=out/kutu-os-*.iso of=/dev/sdX bs=4M status=progress
```

### Cleaning Up

```bash
# Remove build artifacts (keep ISOs)
sudo make clean

# Remove everything (including ISOs)
sudo make distclean
```

## Output Colors

The Makefile uses colored output for better readability:

- **Cyan**: Headers and section titles
- **Green**: Success messages and checkmarks (✓)
- **Yellow**: Warnings and important notes (⚠)
- **Red**: Errors and failures (✗)
- **Blue**: Informational messages
- **Magenta**: Main titles

## Environment Variables

Currently, the Makefile doesn't use environment variables, but you can customize:

```bash
# Use custom output directory
OUT_DIR=my-builds sudo make build

# Use custom build directory
BUILD_DIR=my-work sudo make build
```

## Error Handling

### "This target requires root privileges"
**Solution:** Run with sudo
```bash
sudo make build
```

### "No ISO found"
**Solution:** Build first
```bash
sudo make build
```

### "Not Arch Linux"
**Solution:** The build process works best on Arch Linux or Arch-based distributions (Manjaro, EndeavourOS, etc.)

### Missing dependencies
**Solution:**
```bash
make install-deps
```

## Tips and Tricks

### Parallel Builds
For faster builds on multi-core systems:
```bash
sudo make -j$(nproc) build
```

### Verbose Output
For debugging:
```bash
sudo make build V=1
```

### Dry Run
See what would be executed:
```bash
make -n build
```

### Silent Mode
Suppress output:
```bash
make -s build
```

## Integration with CI/CD

### GitHub Actions Example

```yaml
name: Build kutu OS

on: [push, pull_request]

jobs:
  build:
    runs-on: ubuntu-latest
    container: archlinux:latest

    steps:
      - uses: actions/checkout@v3

      - name: Install dependencies
        run: make install-deps

      - name: Check system
        run: make check

      - name: Validate configs
        run: make validate

      - name: Build ISO
        run: make build

      - name: Upload ISO
        uses: actions/upload-artifact@v3
        with:
          name: kutu-os-iso
          path: out/*.iso
```

## Customization

To add custom targets, edit the Makefile:

```makefile
# Custom target example
my-custom-target:
	@echo "Running custom task..."
	@./scripts/my-custom-script.sh
```

## Troubleshooting

### Build hangs
- Check available disk space: `df -h`
- Check internet connection (for package downloads)
- Try cleaning and rebuilding: `sudo make distclean && sudo make build`

### QEMU test fails
- Install QEMU: `sudo pacman -S qemu-full`
- Check if KVM is available: `ls -la /dev/kvm`

### USB write fails
- Check device permissions
- Ensure device is unmounted
- Verify device path with `lsblk`

## See Also

- [Building Guide](BUILDING.md)
- [Architecture Overview](ARCHITECTURE.md)
- [Contributing Guidelines](../CONTRIBUTING.md)

## Support

For issues with the Makefile:
- Check `make help`
- Read [BUILDING.md](BUILDING.md)
- Open an issue: https://github.com/kutu-so/os/issues
