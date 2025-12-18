#!/usr/bin/env bash
# Standalone installer for the Hugging Face tokenizers package on Termux
# Useful for debugging tokenizers install issues before integrating into main script

set -euo pipefail

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Logging helpers
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[⚠]${NC} $1"; }
log_error() { echo -e "${RED}[✗]${NC} $1" >&2; }

# Check if a Python package is available
python_pkg_installed() {
    local pkg_name=$1
    local import_name
    import_name=$(echo "$pkg_name" | tr '-' '_')

    if python3 -c "import $import_name" >/dev/null 2>&1; then
        return 0
    fi

    if python3 -m pip show "$pkg_name" >/dev/null 2>&1; then
        return 0
    fi

    return 1
}

export PREFIX=${PREFIX:-/data/data/com.termux/files/usr}
WHEELS_DIR="${HOME}/wheels"
mkdir -p "$WHEELS_DIR"

log_info "=========================================="
log_info "Tokenizers Standalone Installer (Termux)"
log_info "=========================================="
echo

# Short-circuit if already present
if python_pkg_installed "tokenizers"; then
    log_success "tokenizers already installed"
    exit 0
fi

# Locate a pre-built wheel first (preferred on Termux)
tokenizers_wheel=""
for wheel in "$WHEELS_DIR"/tokenizers*.whl; do
    if [ -f "$wheel" ]; then
        tokenizers_wheel="$wheel"
        break
    fi
done

if [ -n "$tokenizers_wheel" ]; then
    log_info "Found wheel: $(basename "$tokenizers_wheel")"
    log_info "Installing from local wheel..."
    if python3 -m pip install --no-index --find-links "$WHEELS_DIR" "$tokenizers_wheel"; then
        if python_pkg_installed "tokenizers"; then
            log_success "tokenizers installed from wheel"
            exit 0
        else
            log_warning "Install reported success but import failed"
        fi
    else
        log_warning "Failed to install tokenizers from wheel"
    fi
else
    log_warning "No local tokenizers wheel found in $WHEELS_DIR"
fi

# Fallback: try pip binary install (may fail on Termux due to musl/glibc mismatch)
log_info "Trying pip binary install (this may fail on Termux)..."
if python3 -m pip install --only-binary=:all: tokenizers; then
    if python_pkg_installed "tokenizers"; then
        log_success "tokenizers installed via pip binary"
        exit 0
    else
        log_warning "pip binary install reported success but import failed"
    fi
else
    log_warning "pip binary install failed"
fi

log_error "tokenizers installation failed. Provide a compatible wheel in $WHEELS_DIR and rerun."
exit 1

