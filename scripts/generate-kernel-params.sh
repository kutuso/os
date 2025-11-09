#!/bin/bash
# Generate kernel boot parameters from config files
# Outputs parameters suitable for GRUB/syslinux

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Read base cmdline parameters
CMDLINE_BASE="$PROJECT_ROOT/configs/kernel/cmdline"

if [ ! -f "$CMDLINE_BASE" ]; then
    echo "Error: Base cmdline file not found: $CMDLINE_BASE" >&2
    exit 1
fi

# Extract uncommented, non-empty lines and join them
grep -v '^#' "$CMDLINE_BASE" | grep -v '^$' | tr '\n' ' ' | sed 's/  */ /g' | sed 's/^ //; s/ $//'
