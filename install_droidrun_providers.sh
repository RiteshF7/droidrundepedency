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

# Check if Python package is installed
python_pkg_installed() {
    local pkg_name=$1
    local import_name=$(echo "$pkg_name" | tr '-' '_')
    
    if python3 -c "import $import_name" 2>/dev/null; then
        return 0
    fi
    
    if python3 -m pip show "$pkg_name" >/dev/null 2>&1; then
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
echo

# Check if droidrun is installed
if ! python_pkg_installed "droidrun"; then
    log_error "droidrun is not installed. Please install droidrun first."
    exit 1
fi

log_success "droidrun core is installed"
echo

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
    tokenizers_wheel=$(find "$WHEELS_DIR" -name "tokenizers*.whl" 2>/dev/null | head -1)
    if [ -n "$tokenizers_wheel" ] && [ -f "$tokenizers_wheel" ]; then
        log_info "Found pre-built tokenizers wheel: $(basename "$tokenizers_wheel")"
        if python3 -m pip install --find-links "$WHEELS_DIR" --no-index "$tokenizers_wheel" 2>&1 | grep -v "Looking in indexes" | grep -v "Collecting" | while read line; do log_info "  $line"; done; then
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
    if python3 -m pip install "droidrun[$provider]" --find-links "$WHEELS_DIR" 2>&1 | grep -v "Looking in indexes" | grep -v "Collecting" | grep -v "The folder you are executing pip from" | while read line; do
        # Only show important lines
        if echo "$line" | grep -qE "(Successfully|Installing|Building|error|Error|ERROR|Failed|failed)" || [ -z "$line" ]; then
            log_info "  $line"
        fi
    done; then
        # Check if installation actually succeeded
        if python3 -c "from droidrun.providers import $provider" 2>/dev/null; then
            log_success "droidrun[$provider] installed successfully"
            INSTALLED_PROVIDERS+=("$provider")
        else
            log_warning "droidrun[$provider] installation reported success but provider not importable"
            FAILED_PROVIDERS+=("$provider")
        fi
    else
        log_warning "Failed to install droidrun[$provider]"
        FAILED_PROVIDERS+=("$provider")
    fi
    echo
done

# Summary
echo
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

