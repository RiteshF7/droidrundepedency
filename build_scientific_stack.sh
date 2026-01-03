#!/bin/bash
# Build scientific stack (numpy -> scipy -> scikit-learn) in sequence
# Uses wheels when available, builds from source when needed

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TERMUX_PACKAGES_DIR="${SCRIPT_DIR}/termux-packages"
WHEELS_DIR="${WHEELS_DIR:-${HOME}/wheels}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Ensure wheels directory exists
mkdir -p "$WHEELS_DIR"
log_info "Wheels directory: $WHEELS_DIR"

# Check if we're in the right directory
if [ ! -d "$TERMUX_PACKAGES_DIR/packages/python-numpy" ]; then
    log_error "Termux packages directory not found: $TERMUX_PACKAGES_DIR"
    exit 1
fi

# Function to check if wheel exists
wheel_exists() {
    local pkg_name="$1"
    local wheel_pattern="${pkg_name}-*.whl"
    [ -n "$(find "$WHEELS_DIR" -name "$wheel_pattern" 2>/dev/null | head -1)" ]
}

# Function to build a package
build_package() {
    local pkg_name="$1"
    local pkg_dir="$TERMUX_PACKAGES_DIR/packages/python-${pkg_name}"
    
    if [ ! -d "$pkg_dir" ]; then
        log_error "Package directory not found: $pkg_dir"
        return 1
    fi
    
    log_info "Building $pkg_name..."
    cd "$pkg_dir"
    
    # Export WHEELS_DIR so build scripts can use it
    export WHEELS_DIR="$WHEELS_DIR"
    
    # Run the build script
    if bash build.sh; then
        log_info "$pkg_name build completed successfully"
        
        # Try to find and copy the built wheel
        local built_wheel=$(find . -name "${pkg_name}-*.whl" -o -name "${pkg_name//-/_}-*.whl" 2>/dev/null | head -1)
        if [ -n "$built_wheel" ]; then
            log_info "Copying wheel to $WHEELS_DIR: $(basename "$built_wheel")"
            cp "$built_wheel" "$WHEELS_DIR/" || true
        fi
        
        return 0
    else
        log_error "$pkg_name build failed"
        return 1
    fi
}

# Step 1: Build numpy
log_info "=========================================="
log_info "Step 1: Building numpy"
log_info "=========================================="

if wheel_exists "numpy"; then
    log_warn "numpy wheel already exists, skipping build"
    log_warn "To rebuild, remove numpy wheels from $WHEELS_DIR"
else
    if ! build_package "numpy"; then
        log_error "Failed to build numpy"
        exit 1
    fi
fi

# Verify numpy wheel exists
if ! wheel_exists "numpy"; then
    log_error "numpy wheel not found after build"
    exit 1
fi

# Step 2: Build scipy (depends on numpy)
log_info "=========================================="
log_info "Step 2: Building scipy"
log_info "=========================================="

if wheel_exists "scipy"; then
    log_warn "scipy wheel already exists, skipping build"
    log_warn "To rebuild, remove scipy wheels from $WHEELS_DIR"
else
    # Ensure numpy is available for scipy build
    log_info "Installing numpy wheel for scipy build..."
    NUMPY_WHEEL=$(find "$WHEELS_DIR" -name "numpy-*.whl" | head -1)
    if [ -n "$NUMPY_WHEEL" ]; then
        pip install "$NUMPY_WHEEL" --find-links "$WHEELS_DIR" --no-index --no-deps || true
    fi
    
    if ! build_package "scipy"; then
        log_error "Failed to build scipy"
        exit 1
    fi
fi

# Verify scipy wheel exists
if ! wheel_exists "scipy"; then
    log_error "scipy wheel not found after build"
    exit 1
fi

# Step 3: Build scikit-learn (depends on numpy and scipy)
log_info "=========================================="
log_info "Step 3: Building scikit-learn"
log_info "=========================================="

if wheel_exists "scikit_learn"; then
    log_warn "scikit-learn wheel already exists, skipping build"
    log_warn "To rebuild, remove scikit-learn wheels from $WHEELS_DIR"
else
    # Ensure numpy and scipy are available for scikit-learn build
    log_info "Installing numpy and scipy wheels for scikit-learn build..."
    NUMPY_WHEEL=$(find "$WHEELS_DIR" -name "numpy-*.whl" | head -1)
    SCIPY_WHEEL=$(find "$WHEELS_DIR" -name "scipy-*.whl" | head -1)
    
    if [ -n "$NUMPY_WHEEL" ]; then
        pip install "$NUMPY_WHEEL" --find-links "$WHEELS_DIR" --no-index --no-deps || true
    fi
    if [ -n "$SCIPY_WHEEL" ]; then
        pip install "$SCIPY_WHEEL" --find-links "$WHEELS_DIR" --no-index --no-deps || true
    fi
    
    if ! build_package "scikit-learn"; then
        log_error "Failed to build scikit-learn"
        exit 1
    fi
fi

# Final summary
log_info "=========================================="
log_info "Build Summary"
log_info "=========================================="
log_info "Wheels directory: $WHEELS_DIR"
log_info "Built wheels:"
ls -lh "$WHEELS_DIR"/*.whl 2>/dev/null | awk '{print "  " $9 " (" $5 ")"}' || log_warn "No wheels found"

log_info "=========================================="
log_info "All builds completed successfully!"
log_info "=========================================="


