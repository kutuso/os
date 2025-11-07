#!/bin/bash
# kutu OS - Multimodal Models Installation
# Installs LLaVA, Qwen-VL, and other vision-language models

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/var/log/kutu-install-multimodal.log"

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

error() {
    log "ERROR: $*"
    exit 1
}

log "=== Installing Multimodal Models ==="

# Install LLaVA
install_llava() {
    log "Installing LLaVA..."
    python3 -m pip install llava || log "Warning: LLaVA installation failed"
    log "LLaVA installed"
}

# Install Qwen-VL utilities
install_qwen_vl() {
    log "Installing Qwen-VL utilities..."
    python3 -m pip install qwen-vl-utils || log "Warning: Qwen-VL utils installation failed"
    log "Qwen-VL installed"
}

# Install additional multimodal dependencies
install_multimodal_deps() {
    log "Installing multimodal dependencies..."
    python3 -m pip install \
        timm \
        einops \
        sentencepiece \
        protobuf \
        || log "Warning: Some multimodal deps failed"
    log "Multimodal dependencies installed"
}

# Main installation
main() {
    log "Starting multimodal models installation..."

    install_llava
    install_qwen_vl
    install_multimodal_deps

    log "=== Multimodal Models Installation Complete ==="
    log ""
    log "Installed models:"
    log "  - LLaVA: $(python3 -c 'import llava' 2>/dev/null && echo 'YES' || echo 'NO')"
    log "  - Qwen-VL: $(python3 -c 'import qwen_vl_utils' 2>/dev/null && echo 'YES' || echo 'NO')"
}

main "$@"
