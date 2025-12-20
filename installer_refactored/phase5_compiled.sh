#!/usr/bin/env bash
# Phase 5: Other Compiled Packages
# Installs pyarrow, psutil, grpcio, pillow

set -euo pipefail

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# Initialize logging
init_logging

log_info "=========================================="
log_info "Phase 5: Compiled Packages Installation"
log_info "=========================================="

# Check if phase is already complete
if is_phase_complete "5"; then
    log_success "Phase 5 already completed (skipping)"
    exit 0
fi

# Load environment if available
load_env_vars

# Setup build environment
setup_build_environment

log_info "Phase 5: Building other compiled packages..."

# Build pyarrow (optional - continue on failure)
if ! build_package "pyarrow" "pyarrow" --pre-check --env-var="ARROW_HOME=$PREFIX"; then
    log_warning "pyarrow build failed - continuing without it"
    log_warning "Some droidrun features may not work without pyarrow"
fi

# Build psutil (optional - continue on failure)
if ! build_package "psutil" "psutil"; then
    log_warning "psutil build failed - continuing without it"
    log_warning "Some droidrun features may not work without psutil"
fi

# Build grpcio (with wheel patching)
if python_pkg_installed "grpcio" "grpcio"; then
    log_success "grpcio is already installed, skipping build"
else
    log_info "Building grpcio (this may take a while)..."
    # Set GRPC build flags to use system libraries
    export GRPC_PYTHON_BUILD_SYSTEM_OPENSSL=1
    export GRPC_PYTHON_BUILD_SYSTEM_ZLIB=1
    export GRPC_PYTHON_BUILD_SYSTEM_CARES=1
    export GRPC_PYTHON_BUILD_SYSTEM_RE2=1
    export GRPC_PYTHON_BUILD_SYSTEM_ABSL=1
    export GRPC_PYTHON_BUILD_WITH_CYTHON=1

    cd "$WHEELS_DIR"
    log_info "Building grpcio wheel (pip will download source automatically)..."
    grpcio_wheel_output=$(python3 -m pip wheel grpcio --no-deps --no-build-isolation --wheel-dir . 2>&1) || {
        log_error "Failed to build grpcio wheel"
        echo "$grpcio_wheel_output" | grep -v "Looking in indexes" | grep -v "Collecting" | grep -v "The folder you are executing pip from" | while read line; do log_error "  $line"; done
        exit 1
    }
    # Display output (filtering out noise)
    echo "$grpcio_wheel_output" | grep -v "Looking in indexes" | grep -v "Collecting" | grep -v "The folder you are executing pip from" | while read line; do log_info "  $line"; done || true
    
    # Verify wheel was created and get absolute path
    grpcio_wheel=$(ls -1 grpcio*.whl 2>/dev/null | head -1)
    if [ -z "$grpcio_wheel" ] || [ ! -f "$grpcio_wheel" ]; then
        log_error "grpcio wheel file not found after build"
        exit 1
    fi
    
    log_success "grpcio wheel built successfully"

    # Fix grpcio wheel (needs to be in WHEELS_DIR)
    cd "$WHEELS_DIR"
    if ! fix_grpcio_wheel; then
        log_error "Failed to fix grpcio wheel"
        exit 1
    fi

    # Get absolute paths before changing directory
    grpcio_wheel=$(ls -1 grpcio*.whl 2>/dev/null | head -1)
    if [ -z "$grpcio_wheel" ] || [ ! -f "$grpcio_wheel" ]; then
        log_error "grpcio wheel file not found after fix"
        exit 1
    fi
    grpcio_wheel_abs=$(cd "$(dirname "$grpcio_wheel")" && pwd)/$(basename "$grpcio_wheel")
    wheels_dir_abs=$(cd "$WHEELS_DIR" && pwd)

    # Install grpcio dependencies first (typing-extensions is required)
    log_info "Installing grpcio dependencies..."
    if ! python_pkg_installed "typing-extensions" "typing-extensions>=4.12"; then
        log_info "Installing typing-extensions (required by grpcio)..."
        typing_ext_output=$(cd "$HOME" && python3 -m pip install "typing-extensions>=4.12" 2>&1)
        typing_ext_exit=$?
        
        # Display output (filtering out noise)
        echo "$typing_ext_output" | grep -v "Looking in indexes" | grep -v "Collecting" | grep -v "The folder you are executing pip from" | while read line; do log_info "  $line"; done || true
        
        if [ $typing_ext_exit -ne 0 ]; then
            log_error "Failed to install typing-extensions (exit code: $typing_ext_exit) - this is required for grpcio"
            echo "$typing_ext_output" | grep -i "error\|failed\|exception" | head -5 | while read line; do log_error "    $line"; done || true
            exit 1
        else
            # Verify it's actually installed and importable
            if python3 -c "import typing_extensions" 2>/dev/null; then
                log_success "typing-extensions installed and verified"
            else
                log_error "typing-extensions installation succeeded but package is not importable"
                exit 1
            fi
        fi
    else
        log_info "typing-extensions already installed"
        # Verify it's importable
        if ! python3 -c "import typing_extensions" 2>/dev/null; then
            log_warning "typing-extensions appears installed but not importable, reinstalling..."
            typing_ext_output=$(cd "$HOME" && python3 -m pip install --force-reinstall "typing-extensions>=4.12" 2>&1)
            typing_ext_exit=$?
            if [ $typing_ext_exit -ne 0 ]; then
                log_error "Failed to reinstall typing-extensions"
                exit 1
            fi
        fi
    fi

    # Install the fixed wheel - change to HOME directory to avoid "directory not found" errors
    # Use --no-deps since we've already installed typing-extensions
    log_info "Installing grpcio wheel (dependencies already installed)..."
    grpcio_install_output=$(cd "$HOME" && python3 -m pip install --no-deps "$grpcio_wheel_abs" 2>&1) || {
        log_error "Failed to install grpcio wheel"
        echo "$grpcio_install_output" | grep -v "Looking in indexes" | grep -v "Collecting" | grep -v "The folder you are executing pip from" | while read line; do log_error "  $line"; done
        exit 1
    }
    # Display output (filtering out warnings)
    echo "$grpcio_install_output" | grep -v "Looking in indexes" | grep -v "Collecting" | grep -v "The folder you are executing pip from" | while read line; do log_info "  $line"; done || true
fi

# Set LD_LIBRARY_PATH for runtime (REQUIRED for grpcio to work)
export LD_LIBRARY_PATH=$PREFIX/lib:${LD_LIBRARY_PATH:-}
# Add to ~/.bashrc for permanent fix
if ! grep -q "LD_LIBRARY_PATH.*PREFIX/lib" ~/.bashrc 2>/dev/null; then
    echo "export LD_LIBRARY_PATH=\$PREFIX/lib:\$LD_LIBRARY_PATH" >> ~/.bashrc
fi

log_success "grpcio installed (wheel fixed)"

# Build Pillow (optional - continue on failure)
if ! build_package "pillow" "pillow" --env-var="PKG_CONFIG_PATH=$PREFIX/lib/pkgconfig:${PKG_CONFIG_PATH:-}" --env-var="LDFLAGS=-L$PREFIX/lib" --env-var="CPPFLAGS=-I$PREFIX/include"; then
    log_warning "pillow build failed - continuing without it"
    log_warning "Some droidrun features may not work without pillow"
fi

log_success "Phase 5 complete: Other compiled packages processed"
mark_phase_complete "5"
save_env_vars

log_success "Phase 5 completed successfully"

