#!/bin/bash
# kutu OS - Development Tools Installation
# Installs LangChain, LlamaIndex, and other dev libraries

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/var/log/kutu-install-dev-tools.log"

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

error() {
    log "ERROR: $*"
    exit 1
}

log "=== Installing Development Tools ==="

# Install LangChain
install_langchain() {
    log "Installing LangChain..."
    python3 -m pip install langchain langchain-community langchain-core || log "Warning: LangChain installation failed"
    log "LangChain installed"
}

# Install LlamaIndex
install_llamaindex() {
    log "Installing LlamaIndex..."
    python3 -m pip install llama-index || log "Warning: LlamaIndex installation failed"
    log "LlamaIndex installed"
}

# Install DSPy
install_dspy() {
    log "Installing DSPy..."
    python3 -m pip install dspy-ai || log "Warning: DSPy installation failed"
    log "DSPy installed"
}

# Install Guidance
install_guidance() {
    log "Installing Guidance..."
    python3 -m pip install guidance || log "Warning: Guidance installation failed"
    log "Guidance installed"
}

# Install Outlines
install_outlines() {
    log "Installing Outlines..."
    python3 -m pip install outlines || log "Warning: Outlines installation failed"
    log "Outlines installed"
}

# Install quantization tools
install_quantization_tools() {
    log "Installing quantization tools..."
    python3 -m pip install auto-gptq autoawq || log "Warning: Quantization tools installation had issues"
    log "Quantization tools installed"
}

# Main installation
main() {
    log "Starting development tools installation..."

    install_langchain
    install_llamaindex
    install_dspy
    install_guidance
    install_outlines
    install_quantization_tools

    log "=== Development Tools Installation Complete ==="
    log ""
    log "Installed tools:"
    log "  - LangChain: $(python3 -c 'import langchain' 2>/dev/null && echo 'YES' || echo 'NO')"
    log "  - LlamaIndex: $(python3 -c 'import llama_index' 2>/dev/null && echo 'YES' || echo 'NO')"
    log "  - DSPy: $(python3 -c 'import dspy' 2>/dev/null && echo 'YES' || echo 'NO')"
    log "  - Guidance: $(python3 -c 'import guidance' 2>/dev/null && echo 'YES' || echo 'NO')"
    log "  - Outlines: $(python3 -c 'import outlines' 2>/dev/null && echo 'YES' || echo 'NO')"
}

main "$@"
