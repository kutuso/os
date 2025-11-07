#!/bin/bash
# kutu OS - Master Software Installation Script
# Orchestrates installation of all ML software components

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/var/log/kutu-install-all.log"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $*" | tee -a "$LOG_FILE"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING:${NC} $*" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $*" | tee -a "$LOG_FILE"
    exit 1
}

header() {
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
    echo -e "${MAGENTA}  $*${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
    echo ""
}

# Check if running as root (not recommended for pip installs)
check_user() {
    if [ "$EUID" -eq 0 ]; then
        warn "Running as root. Python packages will be installed system-wide."
        warn "Consider running as regular user for user-level installation."
        read -p "Continue anyway? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

# Display menu for selective installation
show_menu() {
    header "kutu OS Software Installation"

    echo -e "${BLUE}Select components to install:${NC}"
    echo ""
    echo "  1. Base ML Dependencies (PyTorch, NumPy, etc.) ${GREEN}[RECOMMENDED]${NC}"
    echo "  2. LLM Inference Engines (Ollama, vLLM, SGLang, llama.cpp)"
    echo "  3. Vision Models & Tools (YOLO, SAM, OpenCV)"
    echo "  4. Multimodal Models (LLaVA, Qwen-VL)"
    echo "  5. API Servers & Orchestration (LiteLLM, BentoML, Ray)"
    echo "  6. Development Tools (LangChain, LlamaIndex)"
    echo ""
    echo "  ${YELLOW}A. Install ALL components${NC}"
    echo "  ${YELLOW}M. Minimal install (Base ML + Ollama only)${NC}"
    echo "  ${YELLOW}R. Recommended install (Base ML + LLM Engines + Vision)${NC}"
    echo ""
    echo "  ${RED}Q. Quit${NC}"
    echo ""
}

# Install base ML dependencies
install_base() {
    header "Installing Base ML Dependencies"
    bash "$SCRIPT_DIR/install-base-ml.sh" || warn "Base ML installation had issues"
}

# Install LLM engines
install_llm() {
    header "Installing LLM Inference Engines"
    bash "$SCRIPT_DIR/install-llm-engines.sh" || warn "LLM engines installation had issues"
}

# Install vision tools
install_vision() {
    header "Installing Vision Models & Tools"
    bash "$SCRIPT_DIR/install-vision-tools.sh" || warn "Vision tools installation had issues"
}

# Install multimodal models
install_multimodal() {
    header "Installing Multimodal Models"
    bash "$SCRIPT_DIR/install-multimodal.sh" || warn "Multimodal installation had issues"
}

# Install API servers
install_api() {
    header "Installing API Servers & Orchestration"
    bash "$SCRIPT_DIR/install-api-servers.sh" || warn "API servers installation had issues"
}

# Install dev tools
install_dev() {
    header "Installing Development Tools"
    bash "$SCRIPT_DIR/install-dev-tools.sh" || warn "Dev tools installation had issues"
}

# Install all components
install_all() {
    log "Installing ALL components..."
    install_base
    install_llm
    install_vision
    install_multimodal
    install_api
    install_dev
}

# Minimal install
install_minimal() {
    log "Minimal installation: Base ML + Ollama..."
    install_base

    # Install just Ollama from LLM engines
    log "Installing Ollama..."
    curl -fsSL https://ollama.com/install.sh | sh || warn "Ollama installation failed"
}

# Recommended install
install_recommended() {
    log "Recommended installation: Base ML + LLM Engines + Vision..."
    install_base
    install_llm
    install_vision
}

# Interactive menu mode
interactive_mode() {
    check_user

    while true; do
        show_menu
        read -p "Enter your choice: " choice

        case $choice in
            1) install_base ;;
            2) install_llm ;;
            3) install_vision ;;
            4) install_multimodal ;;
            5) install_api ;;
            6) install_dev ;;
            A|a) install_all; break ;;
            M|m) install_minimal; break ;;
            R|r) install_recommended; break ;;
            Q|q) log "Installation cancelled"; exit 0 ;;
            *) warn "Invalid choice: $choice" ;;
        esac

        echo ""
        read -p "Press Enter to continue..."
    done
}

# Command line mode
cli_mode() {
    case "$1" in
        --all)
            install_all
            ;;
        --minimal)
            install_minimal
            ;;
        --recommended)
            install_recommended
            ;;
        --base)
            install_base
            ;;
        --llm)
            install_llm
            ;;
        --vision)
            install_vision
            ;;
        --multimodal)
            install_multimodal
            ;;
        --api)
            install_api
            ;;
        --dev)
            install_dev
            ;;
        --help|-h)
            echo "kutu OS Software Installation Script"
            echo ""
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --all           Install all components"
            echo "  --minimal       Minimal install (Base ML + Ollama)"
            echo "  --recommended   Recommended install (Base + LLM + Vision)"
            echo "  --base          Install base ML dependencies only"
            echo "  --llm           Install LLM engines only"
            echo "  --vision        Install vision tools only"
            echo "  --multimodal    Install multimodal models only"
            echo "  --api           Install API servers only"
            echo "  --dev           Install dev tools only"
            echo "  --help, -h      Show this help"
            echo ""
            echo "If no option is provided, interactive menu will be shown."
            exit 0
            ;;
        *)
            if [ -n "$1" ]; then
                error "Unknown option: $1. Use --help for usage."
            fi
            ;;
    esac
}

# Display summary
show_summary() {
    header "Installation Summary"

    log "Checking installed components..."
    echo ""

    # Check Python packages
    echo -e "${BLUE}Python Packages:${NC}"
    python3 -c "import torch; print(f'  PyTorch: {torch.__version__}')" 2>/dev/null || echo "  PyTorch: NOT INSTALLED"
    python3 -c "import transformers; print(f'  Transformers: {transformers.__version__}')" 2>/dev/null || echo "  Transformers: NOT INSTALLED"
    python3 -c "import vllm; print('  vLLM: INSTALLED')" 2>/dev/null || echo "  vLLM: NOT INSTALLED"
    python3 -c "import sglang; print('  SGLang: INSTALLED')" 2>/dev/null || echo "  SGLang: NOT INSTALLED"
    python3 -c "import ultralytics; print('  Ultralytics: INSTALLED')" 2>/dev/null || echo "  Ultralytics: NOT INSTALLED"
    python3 -c "import langchain; print('  LangChain: INSTALLED')" 2>/dev/null || echo "  LangChain: NOT INSTALLED"

    echo ""
    echo -e "${BLUE}System Commands:${NC}"
    command -v ollama &> /dev/null && echo "  Ollama: INSTALLED" || echo "  Ollama: NOT INSTALLED"
    command -v llama-server &> /dev/null && echo "  llama.cpp: INSTALLED" || echo "  llama.cpp: NOT INSTALLED"

    echo ""
    echo -e "${GREEN}Installation logs saved to: $LOG_FILE${NC}"
}

# Main execution
main() {
    header "kutu OS ML Software Installer"

    log "Started at $(date)"
    log "Script directory: $SCRIPT_DIR"
    log "Log file: $LOG_FILE"

    # Check if arguments provided
    if [ $# -eq 0 ]; then
        # No arguments, run interactive mode
        interactive_mode
    else
        # Arguments provided, run CLI mode
        cli_mode "$@"
    fi

    show_summary

    header "Installation Complete!"
    log "Total time: $(date)"

    echo ""
    echo -e "${CYAN}Next steps:${NC}"
    echo "  1. Reboot if GPU drivers were installed"
    echo "  2. Test installation: python3 -c 'import torch; print(torch.cuda.is_available())'"
    echo "  3. Start using: ollama run llama3.3"
    echo ""
    echo -e "${YELLOW}For documentation, see: /usr/share/doc/kutu/SOFTWARE_CATALOG.md${NC}"
    echo ""
}

main "$@"
