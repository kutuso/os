#!/bin/bash
# kutu OS - Base ML Dependencies Installation
# Installs PyTorch, basic ML libraries, and common tools

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/var/log/kutu-install-base-ml.log"

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

error() {
    log "ERROR: $*"
    exit 1
}

log "=== Installing Base ML Dependencies ==="

# Check Python version
if ! command -v python3 &> /dev/null; then
    log "Installing Python..."
    pacman -S --noconfirm --needed python python-pip python-virtualenv || error "Failed to install Python"
fi

PYTHON_VERSION=$(python3 --version | awk '{print $2}')
log "Python version: $PYTHON_VERSION"

# Upgrade pip
log "Upgrading pip..."
python3 -m pip install --upgrade pip setuptools wheel

# Install PyTorch with CUDA support
log "Installing PyTorch with CUDA 12.1..."
python3 -m pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121 || \
    log "Warning: PyTorch installation had issues, may need manual intervention"

# Install basic ML libraries
log "Installing basic ML libraries..."
python3 -m pip install \
    numpy \
    scipy \
    pandas \
    scikit-learn \
    matplotlib \
    seaborn \
    jupyter \
    ipython \
    tqdm \
    || log "Warning: Some basic libraries failed to install"

# Install HuggingFace essentials
log "Installing HuggingFace libraries..."
python3 -m pip install \
    transformers \
    tokenizers \
    datasets \
    accelerate \
    huggingface-hub \
    || log "Warning: HuggingFace libraries had issues"

# Install common utilities
log "Installing utility libraries..."
python3 -m pip install \
    pyyaml \
    requests \
    aiohttp \
    fastapi \
    uvicorn \
    pydantic \
    || log "Warning: Some utilities failed to install"

# Verify PyTorch installation
log "Verifying PyTorch installation..."
python3 -c "import torch; print(f'PyTorch version: {torch.__version__}'); print(f'CUDA available: {torch.cuda.is_available()}'); print(f'CUDA version: {torch.version.cuda if torch.cuda.is_available() else \"N/A\"}')" | tee -a "$LOG_FILE"

log "=== Base ML Dependencies Installation Complete ==="
log "Installed packages can be found in: $(python3 -m pip list | wc -l) total packages"
