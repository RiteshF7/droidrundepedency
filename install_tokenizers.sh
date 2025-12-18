#!/usr/bin/env bash
# Script to install tokenizers from pre-built wheel
# tokenizers cannot be built on Android due to pthread_cond_clockwait limitation

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
    echo -e "${RED}[✗]${NC} $1"
}

# Check if Python package is installed
python_pkg_installed() {
    local pkg_name=$1
    local import_name=$(echo "$pkg_name" | tr '-' '_')
    
    if python3 -c "import $import_name"; then
        return 0
    fi
    
    if python3 -m pip show "$pkg_name"; then
        return 0
    fi
    
    return 1
}

# Setup
export PREFIX=${PREFIX:-/data/data/com.termux/files/usr}
WHEELS_DIR="${HOME}/wheels"
mkdir -p "$WHEELS_DIR"

log_info "=========================================="
log_info "tokenizers Installation Script"
log_info "=========================================="
echo

# Check if tokenizers is already installed
if python_pkg_installed "tokenizers"; then
    log_success "tokenizers is already installed"
    python3 -c "import tokenizers; print(f'tokenizers version: {tokenizers.__version__}')"
    exit 0
fi

log_info "tokenizers is NOT installed"
log_info "tokenizers cannot be built on Android due to pthread_cond_clockwait limitation"
log_info "We need to install it from a pre-built wheel"
echo

# Check multiple possible locations for dependencies folder
DEPENDENCIES_WHEELS_DIRS=(
    "${SCRIPT_DIR:-$HOME}/depedencies/wheels"
    "${HOME}/droidrundepedency/depedencies/wheels"
    "${HOME}/depedencies/wheels"
    "./depedencies/wheels"
)

# Try to find architecture-specific wheel directory
ARCH_DIR=""
for DEPENDENCIES_WHEELS_DIR in "${DEPENDENCIES_WHEELS_DIRS[@]}"; do
    if [ -d "$DEPENDENCIES_WHEELS_DIR" ]; then
        log_info "Found dependencies folder: $DEPENDENCIES_WHEELS_DIR"
        
        # Check for architecture-specific directories
        if [ -d "${DEPENDENCIES_WHEELS_DIR}/_x86_64_wheels" ]; then
            ARCH_DIR="${DEPENDENCIES_WHEELS_DIR}/_x86_64_wheels"
            log_info "Found x86_64 wheels directory: $ARCH_DIR"
            break
        elif [ -d "${DEPENDENCIES_WHEELS_DIR}/arch64_wheels" ]; then
            ARCH_DIR="${DEPENDENCIES_WHEELS_DIR}/arch64_wheels"
            log_info "Found arch64 wheels directory: $ARCH_DIR"
            break
        else
            # Check if wheels are directly in the dependencies folder
            for wheel in "$DEPENDENCIES_WHEELS_DIR"/tokenizers*.whl; do
                if [ -f "$wheel" ]; then
                    ARCH_DIR="$DEPENDENCIES_WHEELS_DIR"
                    log_info "Found tokenizers wheels in: $ARCH_DIR"
                    break 2
                fi
            done
        fi
    fi
done

# Also check WHEELS_DIR
if [ -z "$ARCH_DIR" ]; then
    log_info "Checking local wheels directory: $WHEELS_DIR"
    for wheel in "$WHEELS_DIR"/tokenizers*.whl; do
        if [ -f "$wheel" ]; then
            ARCH_DIR="$WHEELS_DIR"
            log_info "Found tokenizers wheels in local wheels directory"
            break
        fi
    done
fi

if [ -z "$ARCH_DIR" ]; then
    log_error "No tokenizers wheel found in any of the checked locations:"
    for dir in "${DEPENDENCIES_WHEELS_DIRS[@]}"; do
        log_info "  - $dir"
    done
    log_info "  - $WHEELS_DIR"
    echo
    log_error "tokenizers installation failed - no pre-built wheel found"
    log_info "Please ensure tokenizers wheel is available in one of the above locations"
    exit 1
fi

# Find tokenizers wheel
log_info "Searching for tokenizers wheel in: $ARCH_DIR"
tokenizers_wheel=""
for wheel in "$ARCH_DIR"/tokenizers*.whl; do
    if [ -f "$wheel" ]; then
        tokenizers_wheel="$wheel"
        log_info "Found tokenizers wheel: $(basename "$tokenizers_wheel")"
        break
    fi
done

if [ -z "$tokenizers_wheel" ] || [ ! -f "$tokenizers_wheel" ]; then
    log_error "tokenizers wheel file not found in: $ARCH_DIR"
    log_info "Files in directory:"
    ls -la "$ARCH_DIR" | while read line; do
        log_info "  $line"
    done
    exit 1
fi

# Copy wheel to WHEELS_DIR if it's not already there
if [ "$(dirname "$tokenizers_wheel")" != "$WHEELS_DIR" ]; then
    log_info "Copying tokenizers wheel to $WHEELS_DIR..."
    cp "$tokenizers_wheel" "$WHEELS_DIR/" || {
        log_warning "Failed to copy wheel, but will try to install from original location"
    }
fi

# Install tokenizers from wheel
log_info "Installing tokenizers from pre-built wheel..."
log_info "Wheel location: $tokenizers_wheel"
log_info "Running: python3 -m pip install --find-links \"$WHEELS_DIR\" --no-index \"$tokenizers_wheel\""
echo

if python3 -m pip install --find-links "$WHEELS_DIR" --no-index "$tokenizers_wheel"; then
    log_success "tokenizers installation command completed"
    
    # Verify installation
    if python_pkg_installed "tokenizers"; then
        log_success "tokenizers is now installed and importable"
        python3 -c "import tokenizers; print(f'tokenizers version: {tokenizers.__version__}')"
        echo
        log_success "tokenizers installation completed successfully!"
        exit 0
    else
        log_error "tokenizers installation reported success but package is not importable"
        log_info "Trying to verify with pip show..."
        python3 -m pip show tokenizers
        exit 1
    fi
else
    log_error "Failed to install tokenizers from pre-built wheel"
    log_info "Please check the error messages above"
    exit 1
fi

