# kutu OS Software Catalog

Comprehensive catalog of ML inference software, tools, and frameworks for kutu OS.

**Note:** This document lists application-level software. These belong in separate application repositories, not in the OS layer. This is a reference guide for what users can install on top of kutu OS.

---

## Table of Contents

- [LLM Inference Engines](#llm-inference-engines)
- [Vision Models & Tools](#vision-models--tools)
- [Multimodal Models](#multimodal-models)
- [API Servers & Orchestration](#api-servers--orchestration)
- [Model Management](#model-management)
- [Optimization Tools](#optimization-tools)
- [Monitoring & Profiling](#monitoring--profiling)
- [Development Libraries](#development-libraries)
- [Hardware-Specific Tools](#hardware-specific-tools)

---

## LLM Inference Engines

### Ollama

**Website:** https://ollama.ai
**GitHub:** https://github.com/ollama/ollama
**Description:** Easy-to-use LLM inference engine with model management

**Features:**

- One-command model deployment
- Built-in model library (Llama, Mistral, Qwen, etc.)
- OpenAI-compatible API
- Model quantization (Q4, Q5, Q8)
- Cross-platform (Linux, macOS, Windows)

**Installation:**

```bash
curl -fsSL https://ollama.com/install.sh | sh
```

**Supported Models:**

- Llama 3.3 (8B, 70B, 405B)
- Qwen 2.5 (0.5B - 72B)
- Mistral/Mixtral
- Phi-4
- DeepSeek
- CodeLlama
- And 100+ more

**GPU Support:** NVIDIA CUDA, AMD ROCm

**Use Cases:** General-purpose LLM inference, chatbots, RAG applications

---

### vLLM

**Website:** https://vllm.ai
**GitHub:** https://github.com/vllm-project/vllm
**Description:** High-throughput LLM inference with PagedAttention

**Features:**

- PagedAttention for efficient memory management
- Continuous batching for maximum throughput
- OpenAI-compatible API server
- Tensor parallelism for multi-GPU
- Quantization (AWQ, GPTQ, SqueezeLLM)
- Speculative decoding

**Installation:**

```bash
pip install vllm
```

**Performance:**

- Up to 24x higher throughput than HuggingFace Transformers
- Near-optimal memory utilization
- Efficient batching for high concurrency

**Supported Models:**

- Llama 3/3.1/3.3
- Mistral/Mixtral
- Qwen 2.5
- Yi, DeepSeek, Phi
- Most HuggingFace models

**GPU Support:** NVIDIA GPUs (A100, H100, RTX 40/50 series)

**Use Cases:** Production serving, high-traffic APIs, batch processing

---

### SGLang (Structured Generation Language)

**Website:** https://sgl-project.github.io
**GitHub:** https://github.com/sgl-project/sglang
**Description:** Fast inference engine with structured generation support

**Features:**

- RadixAttention for KV cache reuse
- Structured generation (JSON, regex, grammar)
- Multi-modal support (vision + language)
- Fast JSON mode
- OpenAI-compatible API
- Automatic prompt caching

**Installation:**

```bash
pip install sglang[all]
```

**Performance:**

- Up to 5x faster than vLLM for structured outputs
- Excellent for constrained generation tasks
- Efficient prompt caching

**Supported Models:**

- Llama 3.1/3.3
- Qwen 2.5
- Mistral
- Vision models (LLaVA, Qwen-VL)

**GPU Support:** NVIDIA CUDA

**Use Cases:** Structured data extraction, JSON generation, function calling

---

### llama.cpp

**GitHub:** https://github.com/ggerganov/llama.cpp
**Description:** C++ implementation for efficient CPU and GPU inference

**Features:**

- CPU inference optimized
- GGUF format (quantized models)
- Metal (Apple Silicon), CUDA, ROCm, Vulkan support
- Low memory usage
- Cross-platform

**Installation:**

```bash
git clone https://github.com/ggerganov/llama.cpp
cd llama.cpp && make
```

**Quantization Formats:**

- Q2_K, Q3_K_S, Q3_K_M, Q3_K_L
- Q4_K_S, Q4_K_M (recommended)
- Q5_K_S, Q5_K_M
- Q6_K, Q8_0

**Performance:**

- Best for CPU-only inference
- Excellent for edge devices
- Lower throughput than vLLM but more accessible

**Supported Models:**

- Llama models (GGUF format)
- Mistral, Qwen, Phi (GGUF)
- Many community-quantized models on HuggingFace

**GPU Support:** NVIDIA, AMD, Apple Metal, Intel (via Vulkan)

**Use Cases:** CPU inference, edge devices, low-resource environments

---

### TensorRT-LLM

**GitHub:** https://github.com/NVIDIA/TensorRT-LLM
**Description:** NVIDIA's optimized inference engine using TensorRT

**Features:**

- Best performance on NVIDIA GPUs
- FP8/INT8/INT4 quantization
- Multi-GPU tensor/pipeline parallelism
- Inflight batching
- KV cache optimization

**Installation:**

```bash
pip install tensorrt_llm
```

**Performance:**

- Up to 8x faster than PyTorch on NVIDIA GPUs
- Lowest latency for single requests
- Best throughput for NVIDIA hardware

**Supported Models:**

- Llama 3/3.1/3.3
- GPT, Mistral, Qwen
- Most major architectures

**GPU Support:** NVIDIA only (requires TensorRT)

**Use Cases:** Maximum performance on NVIDIA hardware, production deployments

---

### ExLlamaV2

**GitHub:** https://github.com/turboderp/exllamav2
**Description:** Fast inference engine optimized for consumer GPUs

**Features:**

- GPTQ quantization
- Fast 4-bit inference
- Low VRAM usage
- Simple Python API

**Installation:**

```bash
pip install exllamav2
```

**Performance:**

- Optimized for RTX 30/40 series
- Good balance of speed and quality
- Lower VRAM than unquantized models

**Supported Models:**

- Llama 2/3
- Mistral
- Models with GPTQ quantization

**GPU Support:** NVIDIA CUDA

**Use Cases:** Consumer GPU inference, GPTQ quantized models

---

### Text Generation WebUI (oobabooga)

**GitHub:** https://github.com/oobabooga/text-generation-webui
**Description:** Web interface for running LLMs locally

**Features:**

- User-friendly web UI
- Multiple backend support (llama.cpp, ExLlama, AutoGPTQ)
- Model switching
- Extensions and plugins
- Chat interface

**Installation:**

```bash
git clone https://github.com/oobabooga/text-generation-webui
cd text-generation-webui && ./start_linux.sh
```

**GPU Support:** NVIDIA, AMD (via ROCm)

**Use Cases:** Interactive testing, model comparison, non-technical users

---

## Vision Models & Tools

### YOLOv8/v9/v10/v11

**Website:** https://ultralytics.com
**GitHub:** https://github.com/ultralytics/ultralytics
**Description:** State-of-the-art real-time object detection

**Features:**

- Real-time object detection
- Instance segmentation
- Pose estimation
- Classification
- Tracking
- Export to ONNX, TensorRT, CoreML

**Installation:**

```bash
pip install ultralytics
```

**Models:**

- YOLOv8 (n/s/m/l/x variants)
- YOLOv9
- YOLOv10
- YOLOv11 (latest)

**Performance:**

- 50-200+ FPS on GPU
- Multi-stream support
- Optimized for inference

**GPU Support:** NVIDIA CUDA, TensorRT

**Use Cases:** Object detection, security cameras, manufacturing QC, robotics

---

### YOLO-NAS

**GitHub:** https://github.com/Deci-AI/super-gradients
**Description:** Neural Architecture Search YOLO variant

**Features:**

- Better accuracy than YOLOv8
- Quantization-aware training
- TensorRT optimization

**Installation:**

```bash
pip install super-gradients
```

**GPU Support:** NVIDIA CUDA

**Use Cases:** High-accuracy object detection

---

### RT-DETR

**GitHub:** https://github.com/lyuwenyu/RT-DETR
**Description:** Real-time detection transformer

**Features:**

- End-to-end object detection
- No NMS required
- Fast inference
- Better accuracy than YOLO in some cases

**Installation:**

```bash
pip install rtdetr-pytorch
```

**GPU Support:** NVIDIA CUDA

**Use Cases:** Transformer-based detection, research

---

### Segment Anything Model (SAM)

**GitHub:** https://github.com/facebookresearch/segment-anything
**Description:** Promptable segmentation model from Meta

**Features:**

- Zero-shot segmentation
- Point, box, or mask prompts
- Multiple masks per prompt
- Fast inference

**Installation:**

```bash
pip install segment-anything
```

**Models:**

- SAM (ViT-H/L/B)
- SAM 2 (video support)

**GPU Support:** NVIDIA CUDA

**Use Cases:** Image editing, annotation, automated masking

---

### MediaPipe

**Website:** https://mediapipe.dev
**GitHub:** https://github.com/google/mediapipe
**Description:** Google's ML solutions for vision tasks

**Features:**

- Face detection and mesh
- Pose estimation
- Hand tracking
- Object detection
- Image classification
- Cross-platform (CPU/GPU)

**Installation:**

```bash
pip install mediapipe
```

**Performance:**

- Optimized for real-time
- Mobile and desktop
- CPU-friendly

**GPU Support:** CPU, NVIDIA CUDA

**Use Cases:** AR/VR, fitness apps, gesture control

---

### OpenCV DNN Module

**Website:** https://opencv.org
**Description:** OpenCV's deep learning inference module

**Features:**

- Broad model format support (ONNX, TensorFlow, PyTorch)
- Efficient inference
- CPU and GPU backends

**Installation:**

```bash
pip install opencv-contrib-python
```

**GPU Support:** NVIDIA CUDA, OpenCL

**Use Cases:** Computer vision pipelines, prototyping

---

## Multimodal Models

### LLaVA (Large Language and Vision Assistant)

**GitHub:** https://github.com/haotian-liu/LLaVA
**Description:** Visual instruction tuned model

**Features:**

- Image understanding + language generation
- Multiple versions (7B, 13B, 34B)
- Chat interface
- Visual question answering

**Installation:**

```bash
pip install llava
```

**Inference Engines:**

- vLLM (native support)
- SGLang (optimized)
- Ollama (simplified)

**GPU Support:** NVIDIA CUDA

**Use Cases:** Image Q&A, visual reasoning, document understanding

---

### Qwen-VL / Qwen2-VL

**GitHub:** https://github.com/QwenLM/Qwen-VL
**Description:** Vision-language model from Alibaba

**Features:**

- Strong vision understanding
- Multi-lingual support
- Document OCR
- Chart understanding

**Models:**

- Qwen-VL (9.6B)
- Qwen-VL-Chat (9.6B)
- Qwen2-VL (2B, 7B, 72B)

**Installation:**

```bash
pip install qwen-vl-utils
```

**GPU Support:** NVIDIA CUDA

**Use Cases:** Document analysis, OCR, chart reading

---

### CogVLM / CogAgent

**GitHub:** https://github.com/THUDM/CogVLM
**Description:** Powerful vision-language models

**Features:**

- High-resolution image understanding
- GUI agent capabilities
- Strong OCR
- Multi-lingual

**Installation:**

```bash
pip install cogvlm
```

**GPU Support:** NVIDIA CUDA

**Use Cases:** GUI automation, document processing, visual agents

---

### InternVL

**GitHub:** https://github.com/OpenGVLab/InternVL
**Description:** Strong open-source vision-language model

**Features:**

- Competitive with GPT-4V
- Multi-modal understanding
- Strong on benchmarks

**Models:**

- InternVL-Chat-V1.5 (26B)
- InternVL2 (2B, 8B, 40B, 76B)

**GPU Support:** NVIDIA CUDA

**Use Cases:** Visual question answering, image captioning

---

## API Servers & Orchestration

### LiteLLM

**GitHub:** https://github.com/BerriAI/litellm
**Description:** Unified API for 100+ LLM providers

**Features:**

- OpenAI-compatible API
- Load balancing
- Fallbacks
- Caching
- Rate limiting
- Usage tracking

**Installation:**

```bash
pip install litellm
```

**Supported Backends:**

- Ollama
- vLLM
- SGLang
- OpenAI
- Anthropic
- And 100+ more

**Use Cases:** Multi-provider routing, API gateway, load balancing

---

### LocalAI

**GitHub:** https://github.com/mudler/LocalAI
**Description:** Drop-in OpenAI API replacement

**Features:**

- OpenAI-compatible API
- Text, audio, image generation
- Multiple backends (llama.cpp, vLLM, etc.)
- Docker deployment

**Installation:**

```bash
docker run -p 8080:8080 localai/localai
```

**Use Cases:** Self-hosted OpenAI alternative, privacy-focused deployments

---

### BentoML

**GitHub:** https://github.com/bentoml/BentoML
**Description:** ML model serving framework

**Features:**

- Model packaging
- REST and gRPC APIs
- Autoscaling
- Model versioning
- Production-ready

**Installation:**

```bash
pip install bentoml
```

**Use Cases:** ML model deployment, production serving, MLOps

---

### Ray Serve

**GitHub:** https://github.com/ray-project/ray
**Description:** Scalable ML serving with Ray

**Features:**

- Distributed serving
- Autoscaling
- Multi-model serving
- Built on Ray

**Installation:**

```bash
pip install ray[serve]
```

**Use Cases:** Large-scale deployments, distributed inference

---

### Triton Inference Server

**GitHub:** https://github.com/triton-inference-server/server
**Description:** NVIDIA's inference serving solution

**Features:**

- Multi-framework support (TensorRT, PyTorch, ONNX, etc.)
- Dynamic batching
- Model versioning
- HTTP/gRPC APIs
- Model ensemble

**Installation:**

```bash
docker pull nvcr.io/nvidia/tritonserver
```

**GPU Support:** NVIDIA (optimized)

**Use Cases:** High-performance serving, NVIDIA GPU optimization

---

## Model Management

### Hugging Face Hub

**Website:** https://huggingface.co
**Description:** Model repository and download tools

**Installation:**

```bash
pip install huggingface_hub
```

**CLI:**

```bash
huggingface-cli download meta-llama/Llama-3.3-70B-Instruct
```

**Features:**

- 500,000+ models
- Easy model download
- Authentication support
- Model cards and documentation

---

### GPT4All

**GitHub:** https://github.com/nomic-ai/gpt4all
**Description:** Ecosystem of open-source chatbots

**Features:**

- Desktop application
- Model library
- Cross-platform
- Privacy-focused

**Installation:**

```bash
pip install gpt4all
```

**Use Cases:** Non-technical users, desktop applications

---

### LM Studio

**Website:** https://lmstudio.ai
**Description:** Desktop app for running LLMs

**Features:**

- User-friendly GUI
- Model discovery
- Chat interface
- Local API server

**Installation:** Download from website (GUI only)

**Use Cases:** Desktop users, model testing

---

## Optimization Tools

### AutoGPTQ

**GitHub:** https://github.com/AutoGPTQ/AutoGPTQ
**Description:** GPTQ quantization implementation

**Features:**

- 4-bit quantization
- Fast inference
- CUDA kernels

**Installation:**

```bash
pip install auto-gptq
```

**Use Cases:** Model quantization, reducing VRAM usage

---

### AutoAWQ

**GitHub:** https://github.com/casper-hansen/AutoAWQ
**Description:** AWQ quantization implementation

**Features:**

- 4-bit quantization
- Better accuracy than GPTQ
- vLLM integration

**Installation:**

```bash
pip install autoawq
```

**Use Cases:** High-quality quantization

---

### ONNX Runtime

**GitHub:** https://github.com/microsoft/onnxruntime
**Description:** Cross-platform ML inference

**Features:**

- Hardware acceleration
- Quantization
- Model optimization
- Cross-platform

**Installation:**

```bash
pip install onnxruntime-gpu
```

**GPU Support:** NVIDIA CUDA, AMD ROCm, Intel, Apple

**Use Cases:** Cross-platform deployment, model optimization

---

### TensorRT

**Website:** https://developer.nvidia.com/tensorrt
**Description:** NVIDIA's deep learning optimizer

**Features:**

- Graph optimization
- Kernel fusion
- Precision calibration (FP16, INT8, FP8)
- Maximum NVIDIA GPU performance
