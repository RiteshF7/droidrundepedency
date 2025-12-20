#!/usr/bin/env bash
# Phase 1: Build Tools (Pure Python)
# Installs wheel, setuptools, Cython, meson-python, maturin

set -euo pipefail

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../common.sh"

# Initialize logging
init_logging

log_info "=========================================="
log_info "Phase 1: Build Tools Installation"
log_info "=========================================="

# Check if phase is already complete
if is_phase_complete "1"; then
    log_success "Phase 1 already completed (skipping)"
    exit 0
fi

# Load environment if available
load_env_vars

# Setup build environment
setup_build_environment

# Check and install python-pip using pkg if not already installed
if ! pkg_installed "python-pip"; then
    log_info "Installing python-pip using pkg..."
    pkg install -y python-pip
    log_success "python-pip installed"
else
    log_success "python-pip is already installed"
fi

# Check and install build tools only if needed
build_tools_needed=false
for tool in "wheel" "setuptools" "Cython" "meson-python" "maturin"; do
    if ! python_pkg_installed "$tool" "$tool"; then
        build_tools_needed=true
        break
    fi
done

if [ "$build_tools_needed" = true ]; then
    # Install wheel and setuptools only if needed
    if ! python_pkg_installed "wheel" "wheel" || ! python_pkg_installed "setuptools" "setuptools"; then
        python3 -m pip install --upgrade wheel setuptools --quiet
    fi
    
    # Install Cython only if needed
    if ! python_pkg_installed "Cython" "Cython"; then
        python3 -m pip install Cython --quiet
    fi
    
    # Install meson-python only if needed
    if ! python_pkg_installed "meson-python" "meson-python<0.19.0,>=0.16.0"; then
        python3 -m pip install "meson-python<0.19.0,>=0.16.0" --quiet
    fi
    
    # Install maturin only if needed - try pre-built wheel first
    if ! python_pkg_installed "maturin" "maturin<2,>=1.9.4"; then
        log_info "Installing maturin (required for jiter)..."
        maturin_wheel=""
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
                    maturin_wheel=$(find "$ARCH_DIR" -name "maturin*.whl" 2>/dev/null | head -1)
                    if [ -n "$maturin_wheel" ] && [ -f "$maturin_wheel" ]; then
                        log_info "Found pre-built maturin wheel: $(basename "$maturin_wheel")"
                        cp "$maturin_wheel" "$WHEELS_DIR/" 2>/dev/null || true
                        break
                    fi
                fi
            fi
        done
        
        # Try installing from pre-built wheel first
        if [ -n "$maturin_wheel" ] && [ -f "$maturin_wheel" ]; then
            if python3 -m pip install --find-links "$WHEELS_DIR" --no-index "$maturin_wheel" 2>&1 | tee -a "$LOG_FILE"; then
                log_success "maturin installed from pre-built wheel"
            else
                log_warning "Failed to install maturin from pre-built wheel, trying PyPI..."
                if ! python3 -m pip install "maturin<2,>=1.9.4" 2>&1 | tee -a "$LOG_FILE"; then
                    log_error "Failed to install maturin from PyPI - this may cause jiter build to fail"
                    echo "=== maturin installation error at $(date) ===" >> "$ERROR_LOG_FILE"
                    echo "Failed to install from both pre-built wheel and PyPI" >> "$ERROR_LOG_FILE"
                    echo "" >> "$ERROR_LOG_FILE"
                fi
            fi
        else
            log_info "No pre-built maturin wheel found, installing from PyPI..."
            if ! python3 -m pip install "maturin<2,>=1.9.4" 2>&1 | tee -a "$LOG_FILE"; then
                log_error "Failed to install maturin from PyPI - this may cause jiter build to fail"
                echo "=== maturin installation error at $(date) ===" >> "$ERROR_LOG_FILE"
                echo "Failed to install from PyPI" >> "$ERROR_LOG_FILE"
                echo "" >> "$ERROR_LOG_FILE"
            fi
        fi
    fi
    
    log_success "Phase 1 complete: Build tools installed"
else
    log_success "Phase 1 complete: Build tools already installed"
fi

mark_phase_complete "1"
save_env_vars

log_success "Phase 1 completed successfully"

