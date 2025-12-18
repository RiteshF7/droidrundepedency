#!/usr/bin/env bash
# Script to install droidrun LLM providers
# This script handles tokenizers failures gracefully

set -euo pipefail

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[⚠]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1" >&2
}

PYTHON_BIN="${PYTHON_BIN:-python3}"
PIP_BIN="${PIP_BIN:-$PYTHON_BIN -m pip}"

# Check if Python package is installed
python_pkg_installed() {
    local pkg_name=$1
    local import_name
    import_name=$(echo "$pkg_name" | tr '-' '_')
    
    if $PYTHON_BIN -c "import $import_name" >/dev/null 2>&1; then
        return 0
    fi
    
    if $PIP_BIN show "$pkg_name" >/dev/null 2>&1; then
        return 0
    fi
    
    return 1
}

# Setup
export PREFIX=${PREFIX:-/data/data/com.termux/files/usr}
WHEELS_DIR="${HOME}/wheels"
mkdir -p "$WHEELS_DIR"

log_info "=========================================="
log_info "droidrun Providers Installation Script"
log_info "=========================================="

# Ensure droidrun core is installed/importable
if ! python_pkg_installed "droidrun"; then
    log_warning "droidrun is not installed. Attempting to install..."
    if $PIP_BIN install --find-links "$WHEELS_DIR" droidrun; then
        if python_pkg_installed "droidrun"; then
            log_success "droidrun installed successfully"
        else
            log_error "droidrun install reported success but import failed"
            exit 1
        fi
    else
        log_error "Failed to install droidrun. Please install manually and retry."
        exit 1
    fi
else
    log_success "droidrun core is installed"
fi

# Check for tokenizers
TOKENIZERS_AVAILABLE=false
if python_pkg_installed "tokenizers"; then
    log_success "tokenizers is installed"
    TOKENIZERS_AVAILABLE=true
else
    log_warning "tokenizers is NOT installed"
    log_info "Some providers may not be available without tokenizers"
    log_info "Attempting to install tokenizers from pre-built wheel..."
    
    # Try to find pre-built tokenizers wheel
    tokenizers_wheel=""
    for wheel in "$WHEELS_DIR"/tokenizers*.whl; do
        if [ -f "$wheel" ]; then
            tokenizers_wheel="$wheel"
            break
        fi
    done
    
    if [ -n "$tokenizers_wheel" ] && [ -f "$tokenizers_wheel" ]; then
        log_info "Found pre-built tokenizers wheel: $(basename "$tokenizers_wheel")"
        log_info "Installing tokenizers from pre-built wheel..."
        if $PIP_BIN install --find-links "$WHEELS_DIR" --no-index "$tokenizers_wheel"; then
            log_success "tokenizers installed from pre-built wheel"
            TOKENIZERS_AVAILABLE=true
        else
            log_warning "Failed to install tokenizers from pre-built wheel"
        fi
    else
        log_warning "No pre-built tokenizers wheel found"
        log_info "tokenizers cannot be built on Android due to pthread_cond_clockwait limitation"
    fi
fi

echo
log_info "Installing droidrun providers..."
echo

# List of providers to install
PROVIDERS=(
    "google"
    "anthropic"
    "openai"
    "ollama"
    "openrouter"
    "deepseek"
)

INSTALLED_PROVIDERS=()
FAILED_PROVIDERS=()

for provider in "${PROVIDERS[@]}"; do
    log_info "Installing droidrun[$provider] provider..."
    
    # Skip deepseek if tokenizers is not available (it requires tokenizers)
    if [ "$provider" = "deepseek" ] && [ "$TOKENIZERS_AVAILABLE" = false ]; then
        log_warning "Skipping deepseek provider (requires tokenizers)"
        FAILED_PROVIDERS+=("$provider (requires tokenizers)")
        continue
    fi
    
    # Try to install provider
    log_info "Running: $PIP_BIN install \"droidrun[$provider]\" --find-links \"$WHEELS_DIR\""
    if $PIP_BIN install "droidrun[$provider]" --find-links "$WHEELS_DIR"; then
        log_success "droidrun[$provider] installed (pip reported success)"
        INSTALLED_PROVIDERS+=("$provider")
    else
        log_warning "Failed to install droidrun[$provider]"
        FAILED_PROVIDERS+=("$provider")
    fi
    echo
done

# Summary
log_info "=========================================="
log_info "Installation Summary"
log_info "=========================================="

echo
if [ ${#INSTALLED_PROVIDERS[@]} -gt 0 ]; then
    log_success "Successfully installed providers: ${INSTALLED_PROVIDERS[*]}"
fi

if [ ${#FAILED_PROVIDERS[@]} -gt 0 ]; then
    log_warning "Failed or skipped providers: ${FAILED_PROVIDERS[*]}"
fi

echo
if [ ${#INSTALLED_PROVIDERS[@]} -gt 0 ]; then
    log_success "Provider installation completed!"
    log_info "Installed ${#INSTALLED_PROVIDERS[@]} out of ${#PROVIDERS[@]} providers"
else
    log_warning "No providers were installed"
fi

exit 0
