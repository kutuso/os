#!/bin/bash
# kutu OS - Build-time Software Installation
# Installs ALL ML software into the ISO during build

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AIROOTFS_ROOT="${1:-/}"
LOG_FILE="/tmp/kutu-build-software.log"

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

error() {
    log "ERROR: $*"
    exit 1
}

log "=== Building kutu OS with ALL ML Software ==="
log "Root directory: $AIROOTFS_ROOT"

# Function to run commands in chroot if building ISO
run_in_root() {
    if [ "$AIROOTFS_ROOT" = "/" ]; then
        bash -c "$@"
    else
        arch-chroot "$AIROOTFS_ROOT" bash -c "$@"
    fi
}

# Install system packages first
install_system_packages() {
    log "Installing system-level packages..."

    run_in_root "pacman -Sy --noconfirm --needed \
        python \
        python-pip \
        python-virtualenv \
        base-devel \
        cmake \
        git \
        wget \
        curl \
        opencv \
        opencv-cuda \
        || true"

    log "System packages installed"
}

# Install Python base ML stack
install_base_ml() {
    log "Installing base ML dependencies..."

    run_in_root "python3 -m pip install --no-cache-dir \
        torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121 \
        numpy scipy pandas scikit-learn \
        matplotlib seaborn \
        jupyter ipython \
        transformers tokenizers datasets accelerate huggingface-hub \
        pyyaml requests aiohttp fastapi uvicorn pydantic \
        tqdm \
        || true"

    log "Base ML installed"
}

# Install LLM inference engines
install_llm_engines() {
    log "Installing LLM inference engines..."

    # vLLM
    run_in_root "python3 -m pip install --no-cache-dir vllm || true"

    # SGLang
    run_in_root "python3 -m pip install --no-cache-dir 'sglang[all]' || true"

    # ExLlamaV2
    run_in_root "python3 -m pip install --no-cache-dir exllamav2 || true"

    # TensorRT-LLM (NVIDIA only, may fail on non-NVIDIA)
    run_in_root "python3 -m pip install --no-cache-dir tensorrt_llm || true"

    # Ollama - install via official script
    log "Installing Ollama..."
    if [ "$AIROOTFS_ROOT" = "/" ]; then
        curl -fsSL https://ollama.com/install.sh | sh || log "Warning: Ollama install failed"
    else
        # For chroot, we'll install the binary manually
        run_in_root "curl -fsSL https://ollama.com/install.sh | sh || true"
    fi

    # llama.cpp - build from source
    log "Building llama.cpp..."
    LLAMA_DIR="${AIROOTFS_ROOT}/opt/llama.cpp"
    if [ ! -d "$LLAMA_DIR" ]; then
        git clone --depth 1 https://github.com/ggerganov/llama.cpp "$LLAMA_DIR" || log "Warning: llama.cpp clone failed"
        if [ -d "$LLAMA_DIR" ]; then
            run_in_root "cd /opt/llama.cpp && cmake -B build -DLLAMA_CUDA=ON && cmake --build build --config Release -j\$(nproc) || true"
            run_in_root "ln -sf /opt/llama.cpp/build/bin/llama-cli /usr/local/bin/llama-cli || true"
            run_in_root "ln -sf /opt/llama.cpp/build/bin/llama-server /usr/local/bin/llama-server || true"
        fi
    fi

    log "LLM engines installed"
}

# Install vision tools
install_vision_tools() {
    log "Installing vision tools..."

    run_in_root "python3 -m pip install --no-cache-dir \
        opencv-contrib-python \
        ultralytics \
        segment-anything \
        mediapipe \
        onnxruntime-gpu \
        pillow imageio scikit-image albumentations \
        || true"

    log "Vision tools installed"
}

# Install multimodal models
install_multimodal() {
    log "Installing multimodal models..."

    run_in_root "python3 -m pip install --no-cache-dir \
        llava \
        qwen-vl-utils \
        timm einops sentencepiece protobuf \
        || true"

    log "Multimodal models installed"
}

# Install API servers
install_api_servers() {
    log "Installing API servers..."

    run_in_root "python3 -m pip install --no-cache-dir \
        litellm \
        bentoml \
        'ray[serve]' \
        tritonclient[all] \
        || true"

    log "API servers installed"
}

# Install development tools
install_dev_tools() {
    log "Installing development tools..."

    run_in_root "python3 -m pip install --no-cache-dir \
        langchain langchain-community langchain-core \
        llama-index \
        dspy-ai \
        guidance \
        outlines \
        auto-gptq autoawq \
        || true"

    log "Development tools installed"
}

# Main installation
main() {
    log "Starting comprehensive software installation..."
    log "This will take 30-60 minutes and require significant disk space"

    install_system_packages
    install_base_ml
    install_llm_engines
    install_vision_tools
    install_multimodal
    install_api_servers
    install_dev_tools

    log "=== Software Installation Complete ==="
    log ""
    log "Verifying installations..."

    # Verify key components
    run_in_root "python3 -c 'import torch; print(f\"PyTorch: {torch.__version__}\")' || echo 'PyTorch: FAILED'"
    run_in_root "python3 -c 'import vllm; print(\"vLLM: OK\")' || echo 'vLLM: FAILED'"
    run_in_root "python3 -c 'import ultralytics; print(\"YOLO: OK\")' || echo 'YOLO: FAILED'"
    run_in_root "python3 -c 'import langchain; print(\"LangChain: OK\")' || echo 'LangChain: FAILED'"

    log "Build-time software installation complete!"
    log "Log file: $LOG_FILE"
}

main "$@"
