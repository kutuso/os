#!/bin/bash
# kutu OS - API Servers and Orchestration Tools Installation
# Installs LiteLLM, LocalAI, BentoML, etc.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/var/log/kutu-install-api-servers.log"

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

error() {
    log "ERROR: $*"
    exit 1
}

log "=== Installing API Servers and Orchestration Tools ==="

# Install LiteLLM
install_litellm() {
    log "Installing LiteLLM..."
    python3 -m pip install litellm || log "Warning: LiteLLM installation failed"
    log "LiteLLM installed"
}

# Install LocalAI (via Docker is recommended, but we'll note it)
install_localai() {
    log "LocalAI is best installed via Docker:"
    log "  docker pull localai/localai"
    log "  docker run -p 8080:8080 localai/localai"
    log "Skipping LocalAI pip installation"
}

# Install BentoML
install_bentoml() {
    log "Installing BentoML..."
    python3 -m pip install bentoml || log "Warning: BentoML installation failed"
    log "BentoML installed"
}

# Install Ray Serve
install_ray_serve() {
    log "Installing Ray[serve]..."
    python3 -m pip install "ray[serve]" || log "Warning: Ray Serve installation failed"
    log "Ray Serve installed"
}

# Install Triton Client (server is Docker-based)
install_triton_client() {
    log "Installing Triton Client..."
    python3 -m pip install tritonclient[all] || log "Warning: Triton client installation failed"
    log "Triton Client installed (server available via Docker)"
}

# Main installation
main() {
    log "Starting API servers installation..."

    install_litellm
    install_localai
    install_bentoml
    install_ray_serve
    install_triton_client

    log "=== API Servers Installation Complete ==="
    log ""
    log "Installed components:"
    log "  - LiteLLM: $(python3 -c 'import litellm' 2>/dev/null && echo 'YES' || echo 'NO')"
    log "  - BentoML: $(python3 -c 'import bentoml' 2>/dev/null && echo 'YES' || echo 'NO')"
    log "  - Ray: $(python3 -c 'import ray' 2>/dev/null && echo 'YES' || echo 'NO')"
}

main "$@"
