#!/usr/bin/env bash
# Phase 4: Rust Packages (jiter)
# Installs jiter

set -euo pipefail

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# Initialize logging
init_logging

log_info "=========================================="
log_info "Phase 4: Jiter Installation"
log_info "=========================================="

# Check if phase is already complete
if is_phase_complete "4"; then
    log_success "Phase 4 already completed (skipping)"
    exit 0
fi

# Load environment if available
load_env_vars

# Setup build environment
setup_build_environment

log_info "Phase 4: Installing jiter..."
JITER_BUILT=false

# First, try to find and install pre-built jiter wheel
log_info "Checking for pre-built jiter wheel..."
jiter_wheel=""
DEPENDENCIES_WHEELS_DIRS=(
    "${SCRIPT_DIR}/../depedencies/wheels"
    "${HOME}/droidrundepedency/depedencies/wheels"
    "${HOME}/depedencies/wheels"
)
for DEPENDENCIES_WHEELS_DIR in "${DEPENDENCIES_WHEELS_DIRS[@]}"; do
    if [ -d "$DEPENDENCIES_WHEELS_DIR" ]; then
        ARCH_DIR=""
        if [ -d "${DEPENDENCIES_WHEELS_DIR}/_x86_64_wheels" ]; then
            ARCH_DIR="${DEPENDENCIES_WHEELS_DIR}/_x86_64_wheels"
        elif [ -d "${DEPENDENCIES_WHEELS_DIR}/arch64_wheels" ]; then
            ARCH_DIR="${DEPENDENCIES_WHEELS_DIR}/arch64_wheels"
        fi
        if [ -n "$ARCH_DIR" ]; then
            jiter_wheel=$(find "$ARCH_DIR" -name "jiter*.whl" 2>/dev/null | head -1)
            if [ -n "$jiter_wheel" ] && [ -f "$jiter_wheel" ]; then
                log_info "Found pre-built jiter wheel: $(basename "$jiter_wheel")"
                cp "$jiter_wheel" "$WHEELS_DIR/" 2>/dev/null || true
                break
            fi
        fi
    fi
done

# Try installing from pre-built wheel first
if [ -n "$jiter_wheel" ] && [ -f "$jiter_wheel" ]; then
    log_info "Installing jiter from pre-built wheel..."
    if python3 -m pip install --find-links "$WHEELS_DIR" --no-index "$jiter_wheel" 2>&1 | tee -a "$LOG_FILE"; then
        if python_pkg_installed "jiter" "jiter==0.12.0"; then
            JITER_BUILT=true
            log_success "jiter installed from pre-built wheel"
        fi
    else
        log_warning "Failed to install jiter from pre-built wheel, will try building from source"
    fi
fi

# If wheel installation failed, try building from source
if [ "$JITER_BUILT" = false ]; then
    # Check if maturin is available before attempting build
    if ! python_pkg_installed "maturin" "maturin"; then
        log_error "maturin is not installed - cannot build jiter from source"
        log_error "jiter requires maturin to build. Please ensure maturin is installed first."
        log_error "Try running Phase 1 again or install maturin manually: pip install maturin<2,>=1.9.4"
    else
        log_info "Building jiter from source (maturin is available)..."
        for attempt in 1 2; do
            if [ $attempt -gt 1 ]; then
                log_info "Retrying jiter build (attempt $attempt)..."
                rm -f jiter*.whl 2>/dev/null || true
            fi
            
            if build_package "jiter" "jiter==0.12.0"; then
                if python_pkg_installed "jiter" "jiter==0.12.0"; then
                    JITER_BUILT=true
                    break
                fi
            else
                log_warning "jiter build failed (attempt $attempt)"
                if [ $attempt -lt 2 ]; then
                    log_info "Waiting 5 seconds before retry..."
                    sleep 5
                fi
            fi
        done
    fi
fi

if [ "$JITER_BUILT" = false ]; then
    log_warning "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_warning "jiter installation failed - continuing without it"
    log_warning "This may be due to maturin build failure or Rust compilation issues"
    log_warning "Some droidrun features may not work without jiter"
    log_warning "Solution: Ensure pre-built jiter wheel is available in dependencies folder"
    log_warning "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "jiter installation error details saved to: $ERROR_LOG_FILE" | tee -a "$LOG_FILE"
else
    log_success "jiter installed successfully"
fi

log_success "Phase 4 complete: jiter processed"
mark_phase_complete "4"
save_env_vars

log_success "Phase 4 completed successfully"

