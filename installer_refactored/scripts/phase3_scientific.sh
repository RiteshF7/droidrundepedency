#!/usr/bin/env bash
# Phase 3: Scientific Stack
# Installs scipy, pandas, scikit-learn

set -euo pipefail

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../common.sh"

# Initialize logging
init_logging

log_info "=========================================="
log_info "Phase 3: Scientific Stack Installation"
log_info "=========================================="

# Check if phase should be skipped (respects FORCE_RERUN)
if should_skip_phase "3"; then
    log_success "Phase 3 already completed (skipping)"
    log_info "To force rerun, set FORCE_RERUN=1 environment variable"
    exit 0
fi

# Load environment if available
load_env_vars

# Setup build environment
setup_build_environment

log_info "Phase 3: Building scientific stack..."

# Build scipy
if ! build_package "scipy" "scipy>=1.8.0,<1.17.0"; then
    log_error "Failed to build scipy - this is required, exiting"
    exit 1
fi

# Build pandas using the tested build_pandas.sh script
if python_pkg_installed "pandas" "pandas<2.3.0"; then
    log_success "pandas is already installed and satisfies version requirement (pandas<2.3.0), skipping build"
else
    log_info "pandas not installed or version requirement (pandas<2.3.0) not satisfied, will build"
    
    # Pre-install pandas dependencies before building
    log_info "Pre-installing pandas runtime dependencies..."
    PANDAS_DEPS=(
        "python-dateutil>=2.8.2"
        "pytz>=2020.1"
        "tzdata>=2022.7"
    )
    
    for dep in "${PANDAS_DEPS[@]}"; do
        dep_name=$(echo "$dep" | sed 's/[<>=].*//')
        if ! python_pkg_installed "$dep_name" "$dep"; then
            log_info "Installing $dep..."
            pip_output=$(python3 -m pip install "$dep" 2>&1)
            pip_exit=$?
            
            echo "$pip_output" | grep -v "Looking in indexes" | grep -v "Collecting" | grep -v "The folder you are executing pip from" | while read line; do log_info "  $line"; done || true
            
            if [ $pip_exit -eq 0 ]; then
                log_success "$dep installed"
            else
                log_warning "Failed to install $dep (exit code: $pip_exit), but continuing..."
                echo "$pip_output" | grep -i "error\|failed\|exception" | head -5 | while read line; do log_warning "    $line"; done || true
            fi
        else
            log_info "$dep_name already installed"
        fi
    done
    
    log_info "Building pandas using build_pandas.sh..."
    
    # Check if build_pandas.sh exists
    BUILD_PANDAS_SCRIPT="${SCRIPT_DIR}/../build_pandas.sh"
    if [ ! -f "$BUILD_PANDAS_SCRIPT" ]; then
        BUILD_PANDAS_SCRIPT="${HOME}/droidrundepedency/build_pandas.sh"
        if [ ! -f "$BUILD_PANDAS_SCRIPT" ]; then
            BUILD_PANDAS_SCRIPT="./build_pandas.sh"
        fi
    fi
    
    if [ ! -f "$BUILD_PANDAS_SCRIPT" ]; then
        log_error "build_pandas.sh not found. Expected locations:"
        log_error "  ${SCRIPT_DIR}/../build_pandas.sh"
        log_error "  ${HOME}/droidrundepedency/build_pandas.sh"
        log_error "  ./build_pandas.sh"
        log_error "Falling back to build_package method..."
        if ! build_package "pandas" "pandas<2.3.0" --fix-source=pandas; then
            log_error "Failed to build pandas - this is required, exiting"
            exit 1
        fi
    else
        log_info "Using build script: $BUILD_PANDAS_SCRIPT"
        chmod +x "$BUILD_PANDAS_SCRIPT" 2>/dev/null || true
        
        if bash "$BUILD_PANDAS_SCRIPT"; then
            log_success "pandas built and installed successfully using build_pandas.sh"
        else
            log_error "Failed to build pandas using build_pandas.sh - this is required, exiting"
            exit 1
        fi
    fi
fi

# Build scikit-learn using the tested build_scikit_learn.sh script
if python_pkg_installed "scikit-learn" "scikit-learn"; then
    log_success "scikit-learn is already installed, skipping build"
else
    log_info "scikit-learn not installed, will build"
    
    # Pre-install scikit-learn runtime dependencies before building
    log_info "Pre-installing scikit-learn runtime dependencies..."
    SCIKIT_LEARN_DEPS=(
        "joblib>=1.3.0"
        "threadpoolctl>=3.2.0"
    )
    
    for dep in "${SCIKIT_LEARN_DEPS[@]}"; do
        dep_name=$(echo "$dep" | sed 's/[<>=].*//')
        if ! python_pkg_installed "$dep_name" "$dep"; then
            log_info "Installing $dep..."
            scikit_dep_output=$(python3 -m pip install "$dep" 2>&1)
            scikit_dep_exit=$?
            if [ $scikit_dep_exit -ne 0 ]; then
                log_warning "Failed to install $dep (exit code: $scikit_dep_exit)"
                echo "$scikit_dep_output" | grep -v "Looking in indexes" | grep -v "Collecting" | grep -v "The folder you are executing pip from" | while read line; do log_warning "  $line"; done
            else
                log_success "$dep installed"
            fi
        else
            log_info "$dep_name already installed"
        fi
    done
    
    log_info "Building scikit-learn using build_scikit_learn.sh..."
    
    # Find build_scikit_learn.sh
    BUILD_SCIKIT_LEARN_SCRIPT=""
    if [ -f "${SCRIPT_DIR}/../build_scikit_learn.sh" ]; then
        BUILD_SCIKIT_LEARN_SCRIPT="${SCRIPT_DIR}/../build_scikit_learn.sh"
    elif [ -f "${HOME}/droidrundepedency/build_scikit_learn.sh" ]; then
        BUILD_SCIKIT_LEARN_SCRIPT="${HOME}/droidrundepedency/build_scikit_learn.sh"
    elif [ -f "./build_scikit_learn.sh" ]; then
        BUILD_SCIKIT_LEARN_SCRIPT="./build_scikit_learn.sh"
    fi
    
    if [ -n "$BUILD_SCIKIT_LEARN_SCRIPT" ]; then
        log_info "Using build script: $BUILD_SCIKIT_LEARN_SCRIPT"
        chmod +x "$BUILD_SCIKIT_LEARN_SCRIPT" 2>/dev/null || true
        
        if bash "$BUILD_SCIKIT_LEARN_SCRIPT"; then
            log_success "scikit-learn built and installed successfully using build_scikit_learn.sh"
        else
            log_warning "Failed to build scikit-learn using build_scikit_learn.sh - continuing without it"
            log_warning "Some droidrun features may not work without scikit-learn"
        fi
    else
        log_warning "build_scikit_learn.sh not found, falling back to generic build_package for scikit-learn"
        if ! build_package "scikit-learn" "scikit-learn" --fix-source=scikit-learn --no-build-isolation --wheel-pattern="scikit_learn*.whl"; then
            log_warning "Failed to build scikit-learn - continuing without it"
            log_warning "Some droidrun features may not work without scikit-learn"
        fi
    fi
fi

log_success "Phase 3 complete: Scientific stack installed"
mark_phase_complete "3"
save_env_vars

log_success "Phase 3 completed successfully"

