#!/usr/bin/env bash
# Phase 2: Foundation (numpy)
# Installs numpy

set -euo pipefail

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# Initialize logging
init_logging

log_info "=========================================="
log_info "Phase 2: NumPy Installation"
log_info "=========================================="

# Check if phase is already complete
if is_phase_complete "2"; then
    log_success "Phase 2 already completed (skipping)"
    exit 0
fi

# Load environment if available
load_env_vars

# Setup build environment
setup_build_environment

log_info "Phase 2: Building numpy..."
if ! build_package "numpy" "numpy"; then
    log_error "Failed to build numpy - this is required"
    exit 1
fi

log_success "Phase 2 complete: numpy installed"
mark_phase_complete "2"
save_env_vars

log_success "Phase 2 completed successfully"

