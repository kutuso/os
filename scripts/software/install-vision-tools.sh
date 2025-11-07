#!/bin/bash
# kutu OS - Vision Models and Tools Installation
# Installs YOLO, OpenCV, SAM, MediaPipe, etc.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/var/log/kutu-install-vision.log"

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

error() {
    log "ERROR: $*"
    exit 1
}

log "=== Installing Vision Models and Tools ==="

# Install OpenCV with contrib modules
install_opencv() {
    log "Installing OpenCV..."
    pacman -S --noconfirm --needed opencv || log "Warning: OpenCV system package failed"
    python3 -m pip install opencv-contrib-python || log "Warning: OpenCV Python failed"
    log "OpenCV installed"
}

# Install YOLO (Ultralytics)
install_yolo() {
    log "Installing Ultralytics YOLO..."
    python3 -m pip install ultralytics || log "Warning: Ultralytics installation failed"
    log "YOLO installed"
}

# Install Segment Anything Model (SAM)
install_sam() {
    log "Installing Segment Anything (SAM)..."
    python3 -m pip install segment-anything || log "Warning: SAM installation failed"
    log "SAM installed"
}

# Install MediaPipe
install_mediapipe() {
    log "Installing MediaPipe..."
    python3 -m pip install mediapipe || log "Warning: MediaPipe installation failed"
    log "MediaPipe installed"
}

# Install additional vision tools
install_vision_extras() {
    log "Installing additional vision libraries..."
    python3 -m pip install \
        pillow \
        imageio \
        scikit-image \
        albumentations \
        || log "Warning: Some vision extras failed"
    log "Vision extras installed"
}

# Install ONNX Runtime for optimized inference
install_onnx() {
    log "Installing ONNX Runtime..."
    python3 -m pip install onnxruntime-gpu || log "Warning: ONNX Runtime GPU failed, trying CPU version"
    python3 -m pip install onnxruntime || log "Warning: ONNX Runtime installation failed"
    log "ONNX Runtime installed"
}

# Main installation
main() {
    log "Starting vision tools installation..."

    install_opencv
    install_yolo
    install_sam
    install_mediapipe
    install_vision_extras
    install_onnx

    log "=== Vision Tools Installation Complete ==="
    log ""
    log "Installed tools:"
    log "  - OpenCV: $(python3 -c 'import cv2; print(cv2.__version__)' 2>/dev/null || echo 'NO')"
    log "  - Ultralytics: $(python3 -c 'import ultralytics' 2>/dev/null && echo 'YES' || echo 'NO')"
    log "  - SAM: $(python3 -c 'import segment_anything' 2>/dev/null && echo 'YES' || echo 'NO')"
    log "  - MediaPipe: $(python3 -c 'import mediapipe' 2>/dev/null && echo 'YES' || echo 'NO')"
}

main "$@"
