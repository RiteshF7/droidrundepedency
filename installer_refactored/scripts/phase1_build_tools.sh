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

# Check if phase should be skipped (respects FORCE_RERUN)
if should_skip_phase "1"; then
    log_success "Phase 1 already completed (skipping)"
    log_info "To force rerun, set FORCE_RERUN=1 environment variable"
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

# Check and install Rust using pkg if not already installed (required for maturin)
if ! pkg_installed "rust"; then
    if [ "$IS_TERMUX" = true ] && command_exists pkg; then
        log_info "Installing Rust using pkg (required for maturin)..."
        pkg install -y rust
        log_success "Rust installed"
    else
        if [ "$IS_TERMUX" = false ]; then
            log_warning "Rust check skipped (non-Termux environment)"
            log_info "Ensure Rust is available for maturin installation"
        else
            log_error "pkg command not found - cannot install Rust"
        fi
    fi
else
    log_success "Rust is already installed"
fi

# Define essential and optional tools
ESSENTIAL_TOOLS=("wheel" "setuptools" "Cython" "meson-python")
OPTIONAL_TOOLS=("maturin")

# Check if essential tools are needed
essential_tools_needed=false
for tool in "${ESSENTIAL_TOOLS[@]}"; do
    if ! python_pkg_installed "$tool" "$tool"; then
        essential_tools_needed=true
        break
    fi
done

# Install essential build tools first
if [ "$essential_tools_needed" = true ]; then
    log_info "Installing essential build tools..."
    
    # Install wheel and setuptools only if needed
    if ! python_pkg_installed "wheel" "wheel" || ! python_pkg_installed "setuptools" "setuptools"; then
        log_info "Installing wheel and setuptools..."
        if ! python3 -m pip install --upgrade wheel setuptools --quiet; then
            log_error "Failed to install wheel and setuptools"
            exit 1
        fi
        log_success "wheel and setuptools installed"
    fi
    
    # Install Cython only if needed
    if ! python_pkg_installed "Cython" "Cython"; then
        log_info "Installing Cython..."
        if ! python3 -m pip install Cython --quiet; then
            log_error "Failed to install Cython"
            exit 1
        fi
        log_success "Cython installed"
    fi
    
    # Install meson-python only if needed
    if ! python_pkg_installed "meson-python" "meson-python<0.19.0,>=0.16.0"; then
        log_info "Installing meson-python..."
        if ! python3 -m pip install "meson-python<0.19.0,>=0.16.0" --quiet; then
            log_error "Failed to install meson-python"
            exit 1
        fi
        log_success "meson-python installed"
    fi
    
    log_success "All essential build tools installed"
else
    log_success "All essential build tools are already installed"
fi

# Install optional tools (maturin) - only after essential tools are confirmed
log_info "Checking optional build tools..."
if ! python_pkg_installed "maturin" "maturin<2,>=1.9.4"; then
    log_info "Attempting to install maturin (optional for Phase 1, required for Phase 4: jiter)..."
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
            log_info "Rust compiler not found - skipping maturin installation (optional for Phase 1)"
            log_info "Note: maturin will be needed for Phase 4 (jiter)"
            log_info "Solution: Install Rust with 'pkg install rust' or provide pre-built maturin wheel"
            echo "=== maturin installation skipped at $(date) ===" >> "$LOG_FILE"
            echo "Reason: Rust compiler not found (optional tool)" >> "$LOG_FILE"
            echo "" >> "$LOG_FILE"
        else
            log_info "Attempting to install maturin from PyPI (Rust is available)..."
            if python3 -m pip install "maturin<2,>=1.9.4" 2>&1 | tee -a "$LOG_FILE"; then
                if python_pkg_installed "maturin" "maturin<2,>=1.9.4"; then
                    log_success "maturin installed from PyPI"
                    MATURIN_INSTALLED=true
                else
                    log_info "maturin installation from PyPI completed but verification failed"
                fi
            else
                log_info "maturin installation from PyPI failed (optional tool)"
            fi
        fi
        
        # Final check - log info if still not installed (not an error, it's optional)
        if [ "$MATURIN_INSTALLED" = false ]; then
            log_info "maturin installation skipped (optional for Phase 1)"
            log_info "Note: maturin will be needed for Phase 4 (jiter). Solutions:"
            log_info "  - Provide pre-built maturin wheel in dependencies/wheels directory"
            log_info "  - Install Rust: pkg install rust (then rerun this phase)"
            log_info "  - Phase 4 can use pre-built jiter wheel (recommended if available)"
            echo "=== maturin installation skipped at $(date) ===" >> "$LOG_FILE"
            echo "Optional tool - Phase 1 can complete without it" >> "$LOG_FILE"
            echo "" >> "$LOG_FILE"
        fi
    fi
else
    log_success "maturin is already installed"
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

