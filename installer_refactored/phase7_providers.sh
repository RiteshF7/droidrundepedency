#!/usr/bin/env bash
# Phase 7: Main Package + LLM Providers
# Installs droidrun and LLM providers

set -euo pipefail

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# Initialize logging
init_logging

log_info "=========================================="
log_info "Phase 7: Droidrun and Providers Installation"
log_info "=========================================="

# Check if phase is already complete
if is_phase_complete "7"; then
    log_success "Phase 7 already completed (skipping)"
    exit 0
fi

# Load environment if available
load_env_vars

# Setup build environment
setup_build_environment

log_info "Phase 7: Installing droidrun and LLM providers..."

cd "$HOME"

# Find install_droidrun_providers.sh script
PROVIDERS_SCRIPT=""
if [ -f "${SCRIPT_DIR}/../install_droidrun_providers.sh" ]; then
    PROVIDERS_SCRIPT="${SCRIPT_DIR}/../install_droidrun_providers.sh"
elif [ -f "${HOME}/droidrundepedency/install_droidrun_providers.sh" ]; then
    PROVIDERS_SCRIPT="${HOME}/droidrundepedency/install_droidrun_providers.sh"
elif [ -f "./install_droidrun_providers.sh" ]; then
    PROVIDERS_SCRIPT="./install_droidrun_providers.sh"
fi

if [ -n "$PROVIDERS_SCRIPT" ] && [ -f "$PROVIDERS_SCRIPT" ]; then
    log_info "Using provider installation script: $PROVIDERS_SCRIPT"
    # Make script executable
    chmod +x "$PROVIDERS_SCRIPT" 2>/dev/null || true
    
    # Run install_droidrun_providers.sh with same environment variables
    # The script will handle droidrun core installation and all providers
    if bash "$PROVIDERS_SCRIPT"; then
        log_success "Phase 7 complete: droidrun and providers installed"
    else
        log_error "Failed to install droidrun providers"
        log_error "Provider installation script failed"
        exit 1
    fi
else
    log_warning "install_droidrun_providers.sh not found, falling back to inline installation"
    log_warning "Expected locations:"
    log_warning "  ${SCRIPT_DIR}/../install_droidrun_providers.sh"
    log_warning "  ${HOME}/droidrundepedency/install_droidrun_providers.sh"
    log_warning "  ./install_droidrun_providers.sh"
    
    # Fallback: Install droidrun core only (providers should be installed separately)
    if python_pkg_installed "droidrun" "droidrun"; then
        log_success "droidrun is already installed"
    else
        log_info "Installing droidrun core..."
        if python3 -m pip install droidrun --find-links "$WHEELS_DIR" 2>/dev/null; then
            log_success "droidrun core installed"
            log_warning "Run install_droidrun_providers.sh separately to install LLM providers"
        else
            log_error "Failed to install droidrun core"
            exit 1
        fi
    fi
    log_success "Phase 7 complete: droidrun core installed"
fi

mark_phase_complete "7"
save_env_vars

log_success "Phase 7 completed successfully"

