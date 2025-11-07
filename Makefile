# kutu OS Makefile
# Build system for creating ML-optimized Arch Linux ISO

.PHONY: all build clean test test-qemu install-deps check help validate install-usb docs

# Default target
all: build

# Variables
PROJECT_NAME := kutu-os
BUILD_DIR := work
OUT_DIR := out
ARCHISO_DIR := archiso
SCRIPTS_DIR := scripts
DOCS_DIR := docs

# ISO output name
ISO_NAME := $(shell ls -t $(OUT_DIR)/$(PROJECT_NAME)-*.iso 2>/dev/null | head -n1)

# Colors for output
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[1;33m
BLUE := \033[0;34m
MAGENTA := \033[0;35m
CYAN := \033[0;36m
NC := \033[0m # No Color

# Help target - show available commands
help:
	@echo "$(CYAN)════════════════════════════════════════════════════════$(NC)"
	@echo "$(MAGENTA)  kutu OS Build System$(NC)"
	@echo "$(CYAN)════════════════════════════════════════════════════════$(NC)"
	@echo ""
	@echo "$(GREEN)Build & Test:$(NC)"
	@echo "  $(YELLOW)make build$(NC)              - Build kutu OS ISO (base system only)"
	@echo "  $(YELLOW)make build-fat$(NC)          - Build with ALL ML software pre-installed"
	@echo "  $(YELLOW)make clean$(NC)              - Remove build artifacts"
	@echo "  $(YELLOW)make test$(NC)               - Test ISO in QEMU"
	@echo "  $(YELLOW)make install-usb$(NC)        - Write ISO to USB (interactive)"
	@echo ""
	@echo "$(GREEN)System & Validation:$(NC)"
	@echo "  $(YELLOW)make check$(NC)              - Check system requirements"
	@echo "  $(YELLOW)make install-deps$(NC)       - Install build dependencies"
	@echo "  $(YELLOW)make validate$(NC)           - Validate configuration files"
	@echo ""
	@echo "$(GREEN)Software Installation:$(NC)"
	@echo "  $(YELLOW)make install-software$(NC)   - Install ML software (interactive)"
	@echo ""
	@echo "$(GREEN)Documentation:$(NC)"
	@echo "  $(YELLOW)make docs$(NC)               - View documentation"
	@echo "  $(YELLOW)make info$(NC)               - Show build information"
	@echo "  $(YELLOW)make help$(NC)               - Show this help"
	@echo ""
	@echo "$(CYAN)════════════════════════════════════════════════════════$(NC)"
	@echo "$(BLUE)Quick Start:$(NC)"
	@echo "  sudo make build-fat          # Build with ALL software (recommended)"
	@echo "  make test                    # Test in QEMU"
	@echo "  sudo make install-usb        # Write to USB"
	@echo ""
	@echo "$(BLUE)Alternative:$(NC)"
	@echo "  sudo make build              # Build base OS only (faster)"
	@echo ""
	@echo "$(YELLOW)Note: Build requires sudo/root. build-fat takes 60-90 min.$(NC)"
	@echo "$(CYAN)════════════════════════════════════════════════════════$(NC)"

# Check if running as root (for build target)
check-root:
	@if [ "$$(id -u)" -ne 0 ]; then \
		echo "$(RED)Error: This target requires root privileges$(NC)"; \
		echo "$(YELLOW)Please run: sudo make build$(NC)"; \
		exit 1; \
	fi

# Check system requirements
check:
	@echo "$(CYAN)Checking system requirements...$(NC)"
	@echo ""
	@echo "$(BLUE)Operating System:$(NC)"
	@if [ -f /etc/arch-release ]; then \
		echo "  $(GREEN)✓$(NC) Arch Linux detected"; \
	else \
		echo "  $(YELLOW)⚠$(NC) Not Arch Linux (may work on Arch-based distros)"; \
	fi
	@echo ""
	@echo "$(BLUE)Disk Space:$(NC)"
	@df -h . | awk 'NR==2 {if ($$4 ~ /[0-9]+G/ && substr($$4,1,length($$4)-1) >= 20) print "  $(GREEN)✓$(NC) " $$4 " available"; else print "  $(RED)✗$(NC) " $$4 " available (need 20GB+)"}'
	@echo ""
	@echo "$(BLUE)Required Commands:$(NC)"
	@for cmd in mkarchiso mksquashfs xorriso mkfs.fat; do \
		if command -v $$cmd >/dev/null 2>&1; then \
			echo "  $(GREEN)✓$(NC) $$cmd"; \
		else \
			echo "  $(RED)✗$(NC) $$cmd (missing)"; \
		fi; \
	done
	@echo ""

# Install dependencies
install-deps:
	@echo "$(CYAN)Installing dependencies...$(NC)"
	@if [ "$$(id -u)" -ne 0 ]; then \
		echo "$(YELLOW)Note: This requires sudo privileges$(NC)"; \
		sudo pacman -S --needed --noconfirm archiso squashfs-tools libisoburn dosfstools; \
	else \
		pacman -S --needed --noconfirm archiso squashfs-tools libisoburn dosfstools; \
	fi
	@echo "$(GREEN)✓ Dependencies installed$(NC)"

# Validate configuration files
validate:
	@echo "$(CYAN)Validating configuration files...$(NC)"
	@echo ""
	@echo "$(BLUE)Checking required files:$(NC)"
	@for file in $(ARCHISO_DIR)/profiledef.sh $(ARCHISO_DIR)/packages.x86_64 $(ARCHISO_DIR)/pacman.conf; do \
		if [ -f "$$file" ]; then \
			echo "  $(GREEN)✓$(NC) $$file"; \
		else \
			echo "  $(RED)✗$(NC) $$file (missing)"; \
		fi; \
	done
	@echo ""
	@echo "$(BLUE)Checking scripts:$(NC)"
	@for script in $(SCRIPTS_DIR)/build.sh $(SCRIPTS_DIR)/test-qemu.sh $(SCRIPTS_DIR)/first-boot-setup.sh; do \
		if [ -f "$$script" ] && [ -x "$$script" ]; then \
			echo "  $(GREEN)✓$(NC) $$script"; \
		elif [ -f "$$script" ]; then \
			echo "  $(YELLOW)⚠$(NC) $$script (not executable)"; \
		else \
			echo "  $(RED)✗$(NC) $$script (missing)"; \
		fi; \
	done
	@echo ""
	@echo "$(GREEN)Validation complete$(NC)"

# Build the ISO
build: check-root
	@echo "$(CYAN)════════════════════════════════════════════════════════$(NC)"
	@echo "$(MAGENTA)  Building kutu OS ISO$(NC)"
	@echo "$(CYAN)════════════════════════════════════════════════════════$(NC)"
	@echo ""
	@./$(SCRIPTS_DIR)/build.sh
	@echo ""
	@echo "$(GREEN)✓ Build complete!$(NC)"
	@echo ""
	@if [ -n "$(ISO_NAME)" ]; then \
		echo "$(BLUE)ISO created:$(NC) $(ISO_NAME)"; \
		ls -lh $(ISO_NAME); \
	fi
	@echo ""

# Build with ALL ML software pre-installed
build-fat: check-root
	@echo "$(CYAN)════════════════════════════════════════════════════════$(NC)"
	@echo "$(MAGENTA)  Building kutu OS (FAT) with ML Software$(NC)"
	@echo "$(CYAN)════════════════════════════════════════════════════════$(NC)"
	@echo ""
	@echo "$(YELLOW)⚠  This will:$(NC)"
	@echo "  - Take 60-90 minutes to build"
	@echo "  - Create a 10-15GB ISO file"
	@echo "  - Install ALL ML software (PyTorch, vLLM, YOLO, etc.)"
	@echo ""
	@read -p "Continue? (y/N) " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		./$(SCRIPTS_DIR)/build.sh --with-software; \
		echo ""; \
		echo "$(GREEN)✓ FAT ISO build complete!$(NC)"; \
	else \
		echo "$(YELLOW)Cancelled$(NC)"; \
	fi

# Clean build artifacts
clean:
	@echo "$(YELLOW)Cleaning build artifacts...$(NC)"
	@if [ "$$(id -u)" -ne 0 ]; then \
		echo "$(RED)Error: Clean requires root privileges$(NC)"; \
		echo "$(YELLOW)Please run: sudo make clean$(NC)"; \
		exit 1; \
	fi
	@rm -rf $(BUILD_DIR)
	@echo "$(GREEN)✓ Build directory cleaned$(NC)"

# Clean everything including output ISOs
distclean: clean
	@echo "$(YELLOW)Removing output ISOs...$(NC)"
	@rm -rf $(OUT_DIR)
	@mkdir -p $(OUT_DIR)
	@echo "$(GREEN)✓ All artifacts cleaned$(NC)"

# Test in QEMU
test-qemu: test

test:
	@echo "$(CYAN)Testing ISO in QEMU...$(NC)"
	@if [ ! -f "$(ISO_NAME)" ]; then \
		echo "$(RED)Error: No ISO found in $(OUT_DIR)/$(NC)"; \
		echo "$(YELLOW)Please build first: sudo make build$(NC)"; \
		exit 1; \
	fi
	@echo "$(BLUE)Launching QEMU with ISO: $(ISO_NAME)$(NC)"
	@echo ""
	@./$(SCRIPTS_DIR)/test-qemu.sh

# Interactive USB installation
install-usb: check-root
	@echo "$(CYAN)════════════════════════════════════════════════════════$(NC)"
	@echo "$(MAGENTA)  Write ISO to USB Drive$(NC)"
	@echo "$(CYAN)════════════════════════════════════════════════════════$(NC)"
	@echo ""
	@if [ ! -f "$(ISO_NAME)" ]; then \
		echo "$(RED)Error: No ISO found in $(OUT_DIR)/$(NC)"; \
		echo "$(YELLOW)Please build first: sudo make build$(NC)"; \
		exit 1; \
	fi
	@echo "$(YELLOW)⚠  WARNING: This will ERASE the selected drive!$(NC)"
	@echo ""
	@echo "$(BLUE)Available drives:$(NC)"
	@lsblk -o NAME,SIZE,TYPE,MOUNTPOINT | grep -E "disk|NAME"
	@echo ""
	@read -p "Enter device name (e.g., sdb): " device; \
	if [ -z "$$device" ]; then \
		echo "$(RED)Error: No device specified$(NC)"; \
		exit 1; \
	fi; \
	if [ ! -b "/dev/$$device" ]; then \
		echo "$(RED)Error: /dev/$$device is not a valid block device$(NC)"; \
		exit 1; \
	fi; \
	echo ""; \
	echo "$(RED)⚠  FINAL WARNING: This will erase /dev/$$device$(NC)"; \
	read -p "Type 'yes' to continue: " confirm; \
	if [ "$$confirm" = "yes" ]; then \
		echo ""; \
		echo "$(CYAN)Writing ISO to /dev/$$device...$(NC)"; \
		dd if=$(ISO_NAME) of=/dev/$$device bs=4M status=progress conv=fsync; \
		sync; \
		echo ""; \
		echo "$(GREEN)✓ ISO written successfully to /dev/$$device$(NC)"; \
		echo "$(BLUE)You can now boot from this USB drive$(NC)"; \
	else \
		echo "$(YELLOW)Cancelled$(NC)"; \
	fi

# Generate/view documentation
docs:
	@echo "$(CYAN)kutu OS Documentation$(NC)"
	@echo ""
	@echo "$(BLUE)Available documentation:$(NC)"
	@echo "  1. $(GREEN)README.md$(NC) - Main overview"
	@echo "  2. $(GREEN)docs/BUILDING.md$(NC) - Build instructions"
	@echo "  3. $(GREEN)docs/ARCHITECTURE.md$(NC) - Technical architecture"
	@echo "  4. $(GREEN)CONTRIBUTING.md$(NC) - Contribution guidelines"
	@echo ""
	@read -p "Enter number to view (or press Enter to skip): " choice; \
	case $$choice in \
		1) less README.md ;; \
		2) less $(DOCS_DIR)/BUILDING.md ;; \
		3) less $(DOCS_DIR)/ARCHITECTURE.md ;; \
		4) less CONTRIBUTING.md ;; \
		*) echo "$(YELLOW)Skipped$(NC)" ;; \
	esac

# Quick build and test
quick: build test

# Show build info
info:
	@echo "$(CYAN)════════════════════════════════════════════════════════$(NC)"
	@echo "$(MAGENTA)  kutu OS Build Information$(NC)"
	@echo "$(CYAN)════════════════════════════════════════════════════════$(NC)"
	@echo ""
	@echo "$(BLUE)Project:$(NC) $(PROJECT_NAME)"
	@echo "$(BLUE)Build Directory:$(NC) $(BUILD_DIR)"
	@echo "$(BLUE)Output Directory:$(NC) $(OUT_DIR)"
	@echo ""
	@if [ -d "$(OUT_DIR)" ] && [ -n "$$(ls -A $(OUT_DIR) 2>/dev/null)" ]; then \
		echo "$(BLUE)ISO Images:$(NC)"; \
		ls -lh $(OUT_DIR)/*.iso 2>/dev/null || echo "  None"; \
	else \
		echo "$(YELLOW)No ISO images built yet$(NC)"; \
	fi
	@echo ""
	@if [ -d "$(BUILD_DIR)" ]; then \
		echo "$(BLUE)Build directory size:$(NC) $$(du -sh $(BUILD_DIR) 2>/dev/null | cut -f1)"; \
	else \
		echo "$(BLUE)Build directory:$(NC) Not created"; \
	fi
	@echo ""

# List all targets
list:
	@echo "$(CYAN)Available make targets:$(NC)"
	@$(MAKE) -pRrq -f $(firstword $(MAKEFILE_LIST)) : 2>/dev/null | \
		awk -v RS= -F: '/^# File/,/^# Finished Make data base/ {if ($$1 !~ "^[#.]") {print "  " $$1}}' | \
		grep -v -e '^[^[:alnum:]]' -e '^$@$$' | \
		sort

# Install ML software (post-installation)
install-software:
	@echo "$(CYAN)════════════════════════════════════════════════════════$(NC)"
	@echo "$(MAGENTA)  Install ML Software$(NC)"
	@echo "$(CYAN)════════════════════════════════════════════════════════$(NC)"
	@echo ""
	@echo "$(YELLOW)This will install ML inference software on the built ISO or running system.$(NC)"
	@echo ""
	@./$(SCRIPTS_DIR)/software/install-all.sh

# Install software during build (creates fat ISO with everything)
build-with-software: check-root
	@echo "$(CYAN)════════════════════════════════════════════════════════$(NC)"
	@echo "$(MAGENTA)  Building kutu OS with ML Software$(NC)"
	@echo "$(CYAN)════════════════════════════════════════════════════════$(NC)"
	@echo ""
	@echo "$(YELLOW)This creates a larger ISO with ML software pre-installed.$(NC)"
	@echo "$(YELLOW)Build time will be significantly longer (30-60 minutes).$(NC)"
	@echo ""
	@read -p "Continue? (y/N) " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		echo "$(BLUE)Not yet implemented. Use post-installation method:$(NC)"; \
		echo "  1. sudo make build"; \
		echo "  2. Boot the ISO"; \
		echo "  3. Run: ./scripts/software/install-all.sh"; \
	else \
		echo "$(YELLOW)Cancelled$(NC)"; \
	fi

# Default when no target specified
.DEFAULT_GOAL := help
