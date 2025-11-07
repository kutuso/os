#!/bin/bash
# kutu OS - LLM Inference Engines Installation
# Installs Ollama, vLLM, SGLang, llama.cpp

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/var/log/kutu-install-llm-engines.log"

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

error() {
    log "ERROR: $*"
    exit 1
}

log "=== Installing LLM Inference Engines ==="

# Install Ollama
install_ollama() {
    log "Installing Ollama..."
    if command -v ollama &> /dev/null; then
        log "Ollama already installed: $(ollama --version)"
        return
    fi

    curl -fsSL https://ollama.com/install.sh | sh || log "Warning: Ollama installation failed"

    # Enable and start ollama service
    if systemctl is-enabled ollama &> /dev/null; then
        systemctl enable ollama
        systemctl start ollama || log "Warning: Could not start ollama service"
    fi

    log "Ollama installed successfully"
}

# Install vLLM
install_vllm() {
    log "Installing vLLM..."
    python3 -m pip install vllm || log "Warning: vLLM installation failed"
    log "vLLM installed"
}

# Install SGLang
install_sglang() {
    log "Installing SGLang..."
    python3 -m pip install "sglang[all]" || log "Warning: SGLang installation failed"
    log "SGLang installed"
}

# Install llama.cpp
install_llama_cpp() {
    log "Installing llama.cpp..."

    INSTALL_DIR="/opt/llama.cpp"

    if [ -d "$INSTALL_DIR" ]; then
        log "llama.cpp already exists at $INSTALL_DIR"
        return
    fi

    # Install build dependencies
    pacman -S --noconfirm --needed base-devel cmake git || log "Warning: Could not install build deps"

    # Clone and build
    git clone https://github.com/ggerganov/llama.cpp "$INSTALL_DIR" || error "Failed to clone llama.cpp"
    cd "$INSTALL_DIR"

    # Build with CUDA support
    cmake -B build -DLLAMA_CUDA=ON || log "Warning: CMake configuration failed, trying without CUDA"
    cmake --build build --config Release -j$(nproc) || log "Warning: Build failed"

    # Create symlinks
    ln -sf "$INSTALL_DIR/build/bin/llama-cli" /usr/local/bin/llama-cli || true
    ln -sf "$INSTALL_DIR/build/bin/llama-server" /usr/local/bin/llama-server || true

    log "llama.cpp installed"
}

# Install TensorRT-LLM (NVIDIA only)
install_tensorrt_llm() {
    if ! lspci | grep -i nvidia > /dev/null; then
        log "Skipping TensorRT-LLM (no NVIDIA GPU detected)"
        return
    fi

    log "Installing TensorRT-LLM..."
    python3 -m pip install tensorrt_llm || log "Warning: TensorRT-LLM installation failed"
    log "TensorRT-LLM installed"
}

# Install ExLlamaV2
install_exllamav2() {
    log "Installing ExLlamaV2..."
    python3 -m pip install exllamav2 || log "Warning: ExLlamaV2 installation failed"
    log "ExLlamaV2 installed"
}

# Install Text Generation WebUI (optional - commented out by default as it's large)
install_text_generation_webui() {
    log "Skipping Text Generation WebUI (can be installed manually if needed)"
    # Uncomment below to install:
    # WEBUI_DIR="/opt/text-generation-webui"
    # git clone https://github.com/oobabooga/text-generation-webui "$WEBUI_DIR"
    # cd "$WEBUI_DIR"
    # bash start_linux.sh
}

# Main installation
main() {
    log "Starting LLM engines installation..."

    install_ollama
    install_vllm
    install_sglang
    install_llama_cpp
    install_tensorrt_llm
    install_exllamav2
    # install_text_generation_webui  # Uncomment if needed

    log "=== LLM Inference Engines Installation Complete ==="
    log ""
    log "Installed engines:"
    log "  - Ollama: $(command -v ollama &> /dev/null && echo 'YES' || echo 'NO')"
    log "  - vLLM: $(python3 -c 'import vllm' 2>/dev/null && echo 'YES' || echo 'NO')"
    log "  - SGLang: $(python3 -c 'import sglang' 2>/dev/null && echo 'YES' || echo 'NO')"
    log "  - llama.cpp: $(command -v llama-server &> /dev/null && echo 'YES' || echo 'NO')"
}

main "$@"
