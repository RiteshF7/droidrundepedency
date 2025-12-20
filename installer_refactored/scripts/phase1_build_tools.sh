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
    if [ "$IS_TERMUX" = true ] && command_exists pkg; then
        log_info "Installing python-pip using pkg..."
        pkg install -y python-pip
        log_success "python-pip installed"
    else
        if [ "$IS_TERMUX" = false ]; then
            log_warning "python-pip check skipped (non-Termux environment)"
            log_info "Ensure pip is available: python3 -m ensurepip --upgrade"
        else
            log_error "pkg command not found - cannot install python-pip"
        fi
    fi
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
    # Note: maturin is optional for Phase 1, but required for Phase 4 (jiter)
    if ! python_pkg_installed "maturin" "maturin<2,>=1.9.4"; then
        log_info "Installing maturin (required for Phase 4: jiter)..."
        MATURIN_INSTALLED=false
        maturin_wheel=""
        DEPENDENCIES_WHEELS_DIRS=(
            "${SCRIPT_DIR}/../../depedencies/wheels"
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
                if python_pkg_installed "maturin" "maturin<2,>=1.9.4"; then
                    log_success "maturin installed from pre-built wheel"
                    MATURIN_INSTALLED=true
                fi
            fi
        fi
        
        # Try PyPI only if wheel installation failed
        if [ "$MATURIN_INSTALLED" = false ]; then
            # Check if Rust is available (required for building maturin from source)
            if ! command_exists rustc; then
                log_warning "Rust compiler not found - cannot build maturin from source"
                log_warning "maturin installation skipped (will be needed for Phase 4: jiter)"
                log_warning "Solution: Install Rust with 'pkg install rust' or provide pre-built maturin wheel"
                echo "=== maturin installation skipped at $(date) ===" >> "$ERROR_LOG_FILE"
                echo "Reason: Rust compiler not found (required for building from source)" >> "$ERROR_LOG_FILE"
                echo "maturin is optional for Phase 1 but required for Phase 4 (jiter)" >> "$ERROR_LOG_FILE"
                echo "" >> "$ERROR_LOG_FILE"
            else
                log_info "Attempting to install maturin from PyPI (Rust is available)..."
                if python3 -m pip install "maturin<2,>=1.9.4" 2>&1 | tee -a "$LOG_FILE"; then
                    if python_pkg_installed "maturin" "maturin<2,>=1.9.4"; then
                        log_success "maturin installed from PyPI"
                        MATURIN_INSTALLED=true
                    fi
                fi
            fi
            
            # Final check - log warning if still not installed
            if [ "$MATURIN_INSTALLED" = false ]; then
                log_warning "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                log_warning "Failed to install maturin - this is optional for Phase 1"
                log_warning "maturin will be required for Phase 4 (jiter installation)"
                log_warning "Possible solutions:"
                log_warning "  1. Provide pre-built maturin wheel in dependencies/wheels directory"
                log_warning "  2. Install Rust compiler: pkg install rust"
                log_warning "  3. Phase 4 will attempt to use pre-built jiter wheel (recommended)"
                log_warning "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                echo "=== maturin installation error at $(date) ===" >> "$ERROR_LOG_FILE"
                echo "Failed to install from both pre-built wheel and PyPI" >> "$ERROR_LOG_FILE"
                echo "Platform may not support maturin compilation from source" >> "$ERROR_LOG_FILE"
                echo "" >> "$ERROR_LOG_FILE"
            fi
        fi
    else
        log_success "maturin is already installed"
    fi
fi

# Verify required build tools are actually installed before marking complete
REQUIRED_TOOLS=("wheel" "setuptools" "Cython" "meson-python")
MISSING_REQUIRED=()
for tool in "${REQUIRED_TOOLS[@]}"; do
    if ! python_pkg_installed "$tool" "$tool"; then
        MISSING_REQUIRED+=("$tool")
    fi
done

if [ ${#MISSING_REQUIRED[@]} -gt 0 ]; then
    log_error "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_error "Phase 1 FAILED: Required build tools are not installed: ${MISSING_REQUIRED[*]}"
    log_error "Phase will not be marked as complete"
    log_error "Please fix the installation errors and rerun Phase 1"
    log_error "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    exit 1
fi

log_success "Phase 1 complete: All required build tools installed"
mark_phase_complete "1"
save_env_vars

log_success "Phase 1 completed successfully"

