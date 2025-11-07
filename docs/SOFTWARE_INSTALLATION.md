# kutu OS Software Installation Guide

Guide for installing ML inference software on kutu OS.

## Overview

kutu OS provides modular installation scripts for ML inference software. The base OS includes system-level optimizations and GPU drivers, but application software (inference engines, models, tools) can be installed on-demand.

## Installation Methods

### Method 1: Interactive Installation (Recommended)

The master installation script provides an interactive menu:

```bash
cd /usr/local/bin  # Or wherever scripts are installed
sudo ./install-all.sh
```

**Menu Options:**
1. Base ML Dependencies (PyTorch, NumPy) - **RECOMMENDED FIRST**
2. LLM Inference Engines (Ollama, vLLM, SGLang)
3. Vision Models & Tools (YOLO, SAM, OpenCV)
4. Multimodal Models (LLaVA, Qwen-VL)
5. API Servers & Orchestration (LiteLLM, BentoML)
6. Development Tools (LangChain, LlamaIndex)

**Preset Options:**
- **A** - Install ALL components (~20-30GB, 60+ minutes)
- **M** - Minimal (Base ML + Ollama only) (~5GB, 10 minutes)
- **R** - Recommended (Base ML + LLM + Vision) (~10GB, 30 minutes)

### Method 2: Command Line Installation

Install specific components:

```bash
# Install everything
sudo ./install-all.sh --all

# Minimal installation
sudo ./install-all.sh --minimal

# Recommended installation
sudo ./install-all.sh --recommended

# Individual components
sudo ./install-all.sh --base
sudo ./install-all.sh --llm
sudo ./install-all.sh --vision
sudo ./install-all.sh --multimodal
sudo ./install-all.sh --api
sudo ./install-all.sh --dev
```

### Method 3: Individual Scripts

Run individual installation scripts:

```bash
# Base ML dependencies (required for most other software)
./scripts/software/install-base-ml.sh

# LLM inference engines
./scripts/software/install-llm-engines.sh

# Vision tools
./scripts/software/install-vision-tools.sh

# Multimodal models
./scripts/software/install-multimodal.sh

# API servers
./scripts/software/install-api-servers.sh

# Development tools
./scripts/software/install-dev-tools.sh
```

### Method 4: Using Makefile

```bash
# Interactive installation
make install-software
```

## Installation Details

### Base ML Dependencies

**Includes:**
- PyTorch with CUDA 12.1 support
- NumPy, SciPy, Pandas, Scikit-learn
- Matplotlib, Seaborn (visualization)
- Jupyter, IPython
- HuggingFace Transformers, Tokenizers, Datasets
- FastAPI, Uvicorn (API development)

**Installation time:** ~10 minutes
**Disk space:** ~5GB

**Install:**
```bash
./scripts/software/install-base-ml.sh
```

### LLM Inference Engines

**Includes:**
- **Ollama** - Easiest to use, one-command model deployment
- **vLLM** - High-throughput serving with PagedAttention
- **SGLang** - Structured generation (JSON, regex)
- **llama.cpp** - CPU-optimized inference
- **TensorRT-LLM** - NVIDIA GPU optimized (NVIDIA only)
- **ExLlamaV2** - GPTQ quantized models

**Installation time:** ~20 minutes
**Disk space:** ~3GB (excluding models)

**Install:**
```bash
./scripts/software/install-llm-engines.sh
```

**Post-install:**
```bash
# Test Ollama
ollama run llama3.3

# Test vLLM
python3 -m vllm.entrypoints.openai.api_server \
    --model meta-llama/Llama-3.3-70B-Instruct

# Test llama.cpp
llama-server --model /path/to/model.gguf
```

### Vision Models & Tools

**Includes:**
- **Ultralytics YOLO** (v8/v9/v10/v11)
- **OpenCV** with contrib modules
- **Segment Anything (SAM)**
- **MediaPipe** (Google's vision tools)
- **ONNX Runtime** (GPU optimized)

**Installation time:** ~15 minutes
**Disk space:** ~2GB (excluding models)

**Install:**
```bash
./scripts/software/install-vision-tools.sh
```

**Post-install:**
```bash
# Test YOLO
from ultralytics import YOLO
model = YOLO('yolov11n.pt')
results = model('image.jpg')

# Test OpenCV
import cv2
print(cv2.__version__)
```

### Multimodal Models

**Includes:**
- **LLaVA** - Visual instruction tuning
- **Qwen-VL** - Vision-language model
- Additional vision-language utilities

**Installation time:** ~10 minutes
**Disk space:** ~1GB (excluding models)

**Install:**
```bash
./scripts/software/install-multimodal.sh
```

### API Servers & Orchestration

**Includes:**
- **LiteLLM** - Unified API gateway
- **BentoML** - Model serving framework
- **Ray Serve** - Distributed serving
- **Triton Client** - NVIDIA inference client

**Note:** LocalAI and Triton Server are Docker-based (install separately)

**Installation time:** ~10 minutes
**Disk space:** ~1GB

**Install:**
```bash
./scripts/software/install-api-servers.sh
```

### Development Tools

**Includes:**
- **LangChain** - LLM application framework
- **LlamaIndex** - RAG framework
- **DSPy** - LLM programming
- **Guidance** - Structured generation
- **Outlines** - Constrained output
- **AutoGPTQ, AutoAWQ** - Quantization tools

**Installation time:** ~15 minutes
**Disk space:** ~2GB

**Install:**
```bash
./scripts/software/install-dev-tools.sh
```

## Recommended Installation Workflows

### For General LLM Development
```bash
# 1. Base ML (required)
./scripts/software/install-base-ml.sh

# 2. LLM engines
./scripts/software/install-llm-engines.sh

# 3. Development tools
./scripts/software/install-dev-tools.sh

# Test
ollama run llama3.3
python3 -c "import langchain; print('LangChain ready')"
```

### For Computer Vision
```bash
# 1. Base ML
./scripts/software/install-base-ml.sh

# 2. Vision tools
./scripts/software/install-vision-tools.sh

# Test
python3 -c "from ultralytics import YOLO; print('YOLO ready')"
```

### For Multimodal Applications
```bash
# 1. Base ML
./scripts/software/install-base-ml.sh

# 2. LLM engines (for inference)
./scripts/software/install-llm-engines.sh

# 3. Vision tools
./scripts/software/install-vision-tools.sh

# 4. Multimodal models
./scripts/software/install-multimodal.sh

# Test
python3 -c "import llava; print('Multimodal ready')"
```

### For Production API Server
```bash
# 1. Base ML
./scripts/software/install-base-ml.sh

# 2. LLM engines (vLLM for throughput)
./scripts/software/install-llm-engines.sh

# 3. API servers
./scripts/software/install-api-servers.sh

# Start vLLM server
python3 -m vllm.entrypoints.openai.api_server \
    --model meta-llama/Llama-3.3-70B-Instruct \
    --port 8000
```

## Post-Installation

### Verify Installation

```bash
# Check Python packages
python3 -c "import torch; print(f'PyTorch: {torch.__version__}')"
python3 -c "import torch; print(f'CUDA available: {torch.cuda.is_available()}')"

# Check system commands
ollama --version
llama-server --help

# Check installation logs
cat /var/log/kutu-install-*.log
```

### Download Models

**Ollama Models:**
```bash
ollama pull llama3.3
ollama pull qwen2.5:72b
ollama pull mistral
```

**HuggingFace Models:**
```bash
# Install huggingface-cli
pip install huggingface-cli

# Download model
huggingface-cli download meta-llama/Llama-3.3-70B-Instruct
```

**GGUF Models (llama.cpp):**
```bash
# Download from HuggingFace
wget https://huggingface.co/TheBloke/Llama-2-70B-GGUF/resolve/main/llama-2-70b.Q4_K_M.gguf
```

**YOLO Models:**
```bash
python3
>>> from ultralytics import YOLO
>>> model = YOLO('yolov11n.pt')  # Downloads automatically
```

### Environment Setup

**Create Virtual Environment (Optional):**
```bash
python3 -m venv ~/ml-env
source ~/ml-env/bin/activate
# Install packages in virtual environment
```

**Set Environment Variables:**
```bash
# Add to ~/.bashrc or ~/.zshrc
export CUDA_VISIBLE_DEVICES=0  # Use first GPU
export PYTORCH_CUDA_ALLOC_CONF=max_split_size_mb:512
```

## Troubleshooting

### PyTorch CUDA Not Available

```bash
# Check NVIDIA driver
nvidia-smi

# Reinstall PyTorch with correct CUDA version
pip uninstall torch torchvision torchaudio
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121
```

### Out of Memory Errors

```bash
# Use smaller models or quantization
ollama run llama3.3:8b  # Instead of 70b

# Reduce batch size in vLLM
python3 -m vllm.entrypoints.openai.api_server \
    --model meta-llama/Llama-3.3-70B-Instruct \
    --max-model-len 4096 \
    --gpu-memory-utilization 0.9
```

### Permission Errors

```bash
# Don't use sudo with pip (installs system-wide)
# Instead, use --user flag
pip install --user package-name

# Or use virtual environment
python3 -m venv myenv
source myenv/bin/activate
pip install package-name
```

### Network/Download Issues

```bash
# Set pip timeout
pip install --timeout 300 package-name

# Use mirror
pip install -i https://pypi.org/simple package-name

# Download manually and install offline
pip download package-name
pip install --no-index --find-links . package-name
```

## Uninstallation

### Remove Python Packages

```bash
# List installed packages
pip list

# Remove specific package
pip uninstall package-name

# Remove all packages (nuclear option)
pip freeze | xargs pip uninstall -y
```

### Remove System Binaries

```bash
# Remove Ollama
sudo systemctl stop ollama
sudo systemctl disable ollama
sudo rm -rf /usr/local/bin/ollama /usr/share/ollama

# Remove llama.cpp
sudo rm -rf /opt/llama.cpp
sudo rm /usr/local/bin/llama-*
```

## Disk Space Management

### Check Usage

```bash
# Python packages size
pip list --format=freeze | while read p; do
    pip show $p | grep Location
done | sort -u | xargs du -sh

# Model storage
du -sh ~/.ollama/models
du -sh ~/.cache/huggingface
```

### Clean Cache

```bash
# Pip cache
pip cache purge

# HuggingFace cache
rm -rf ~/.cache/huggingface

# Ollama unused models
ollama rm model-name
```

## See Also

- [Software Catalog](SOFTWARE_CATALOG.md) - Complete software reference
- [Architecture](ARCHITECTURE.md) - System architecture
- [Building](BUILDING.md) - Build instructions

## Support

For installation issues:
- Check logs: `/var/log/kutu-install-*.log`
- Review [SOFTWARE_CATALOG.md](SOFTWARE_CATALOG.md)
- Open issue: https://github.com/kutu-so/os/issues

---

**Last Updated:** 2025-01-07
