#!/usr/bin/env bash
# Standalone script to build pandas for Termux
# This script isolates the pandas build process for debugging

set -euo pipefail

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Package name (can be changed for different Termux variants)
PACKAGE_NAME="com.termux"

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[⚠]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1" >&2
}

log_step() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}\n"
}

# ============================================
# Setup PREFIX and check Termux environment
# ============================================
log_step "Setting up environment"

if [ -z "${PREFIX:-}" ]; then
    export PREFIX="/data/data/${PACKAGE_NAME}/files/usr"
fi

if [ ! -d "$PREFIX" ]; then
    log_error "Termux PREFIX directory not found: $PREFIX"
    log_error "This script must be run in Termux environment"
    exit 1
fi

log_info "PREFIX: $PREFIX"

# Setup build environment variables
export CMAKE_PREFIX_PATH=$PREFIX
export CMAKE_INCLUDE_PATH=$PREFIX/include
export CC=$PREFIX/bin/clang
export CXX=$PREFIX/bin/clang++
export TMPDIR=$HOME/tmp
mkdir -p "$TMPDIR"

# Set build parallelization
MEM_MB=$(awk '/MemTotal/ { printf "%.0f", $2/1024 }' /proc/meminfo 2>/dev/null || echo 0)
if [ "$MEM_MB" -ge 3500 ]; then
    JOBS=4
elif [ "$MEM_MB" -ge 2000 ]; then
    JOBS=2
else
    JOBS=1
fi

export NINJAFLAGS="-j$JOBS"
export MAKEFLAGS="-j$JOBS"
export MAX_JOBS=$JOBS

log_info "Build jobs: $JOBS"
log_info "Memory: ${MEM_MB}MB"

# ============================================
# Check prerequisites
# ============================================
log_step "Checking prerequisites"

if ! command -v python3 >/dev/null 2>&1; then
    log_error "python3 is not installed"
    exit 1
fi

if ! command -v pip >/dev/null 2>&1; then
    log_error "pip is not installed"
    exit 1
fi

PYTHON_VERSION=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>/dev/null || echo "unknown")
log_success "Python $PYTHON_VERSION found"

# Check if numpy is installed
if ! python3 -c "import numpy" 2>/dev/null; then
    log_error "numpy must be installed first"
    exit 1
fi
log_success "numpy is installed"

# Check if meson-python is installed
if ! python3 -c "import mesonpy" 2>/dev/null; then
    log_warning "meson-python not found, installing..."
    pip install "meson-python<0.19.0,>=0.16.0" --quiet
fi
log_success "meson-python is available"

# ============================================
# Setup working directory
# ============================================
WHEELS_DIR="${HOME}/wheels"
mkdir -p "$WHEELS_DIR"
cd "$WHEELS_DIR"
log_info "Working directory: $WHEELS_DIR"

# ============================================
# Download pandas source
# ============================================
log_step "Downloading pandas source"

VERSION_SPEC="pandas<2.3.0"
log_info "Version spec: $VERSION_SPEC"

log_info "Running: pip download \"$VERSION_SPEC\" --dest . --no-cache-dir --no-binary :all:"
DOWNLOAD_OUTPUT=$(pip download "$VERSION_SPEC" --dest . --no-cache-dir --no-binary :all: 2>&1)
DOWNLOAD_EXIT_CODE=$?

log_info "pip download exit code: $DOWNLOAD_EXIT_CODE"
log_info "pip download output:"
echo "$DOWNLOAD_OUTPUT" | while IFS= read -r line; do
    log_info "  $line"
done

if [ $DOWNLOAD_EXIT_CODE -ne 0 ]; then
    log_error "Failed to download pandas source"
    log_info "Contents of working directory:"
    ls -la "$WHEELS_DIR" | while IFS= read -r line; do
        log_info "  $line"
    done
    exit 1
fi

# Find downloaded file
SOURCE_FILE=$(ls pandas-*.tar.gz 2>/dev/null | head -1)
if [ -z "$SOURCE_FILE" ]; then
    log_error "Downloaded source file not found"
    log_error "Expected pattern: pandas-*.tar.gz"
    log_info "Files in directory:"
    ls -la "$WHEELS_DIR" | while IFS= read -r line; do
        log_info "  $line"
    done
    exit 1
fi

log_success "Found source file: $SOURCE_FILE"
SOURCE_SIZE=$(stat -c%s "$SOURCE_FILE" 2>/dev/null || stat -f%z "$SOURCE_FILE" 2>/dev/null || echo "unknown")
log_info "Source file size: $SOURCE_SIZE bytes"

# ============================================
# Extract and fix source
# ============================================
log_step "Extracting and fixing pandas source"

EXTRACT_DIR=$(mktemp -d)
log_info "Extract directory: $EXTRACT_DIR"

log_info "Extracting $SOURCE_FILE..."
if ! tar -xzf "$SOURCE_FILE" -C "$EXTRACT_DIR" 2>&1 | while IFS= read -r line; do
    log_info "  $line"
done; then
    log_error "Failed to extract $SOURCE_FILE"
    rm -rf "$EXTRACT_DIR"
    exit 1
fi

PKG_DIR=$(ls -d "$EXTRACT_DIR"/pandas-* 2>/dev/null | head -1)
if [ -z "$PKG_DIR" ]; then
    log_error "Extracted package directory not found"
    log_info "Contents of extract directory:"
    ls -la "$EXTRACT_DIR" | while IFS= read -r line; do
        log_info "  $line"
    done
    rm -rf "$EXTRACT_DIR"
    exit 1
fi

log_success "Extracted to: $PKG_DIR"

# Extract version from directory name
PKG_VERSION=$(basename "$PKG_DIR" | sed "s/pandas-//")
log_info "Package version: $PKG_VERSION"

# Fix meson.build
MESON_BUILD="$PKG_DIR/meson.build"
if [ ! -f "$MESON_BUILD" ]; then
    log_error "meson.build not found at: $MESON_BUILD"
    log_info "Contents of package directory:"
    ls -la "$PKG_DIR" | while IFS= read -r line; do
        log_info "  $line"
    done
    rm -rf "$EXTRACT_DIR"
    exit 1
fi

log_info "Found meson.build at: $MESON_BUILD"
log_info "Original meson.build (first 10 lines):"
head -10 "$MESON_BUILD" | while IFS= read -r line; do
    log_info "  $line"
done

log_info "Fixing meson.build: replacing version detection with '$PKG_VERSION'"
if sed -i "s/version: run_command.*/version: '$PKG_VERSION',/" "$MESON_BUILD" 2>&1; then
    log_success "meson.build fixed"
else
    log_error "Failed to fix meson.build"
    rm -rf "$EXTRACT_DIR"
    exit 1
fi

log_info "Fixed meson.build (first 10 lines):"
head -10 "$MESON_BUILD" | while IFS= read -r line; do
    log_info "  $line"
done

# Repackage fixed source
log_info "Repackaging fixed source..."
FIXED_SOURCE="$WHEELS_DIR/pandas-${PKG_VERSION}-fixed.tar.gz"
if ! tar -czf "$FIXED_SOURCE" -C "$EXTRACT_DIR" "$(basename "$PKG_DIR")" 2>&1 | while IFS= read -r line; do
    log_info "  $line"
done; then
    log_error "Failed to repackage pandas source"
    rm -rf "$EXTRACT_DIR"
    exit 1
fi

if [ ! -f "$FIXED_SOURCE" ]; then
    log_error "Repackaged file not created: $FIXED_SOURCE"
    rm -rf "$EXTRACT_DIR"
    exit 1
fi

FIXED_SIZE=$(stat -c%s "$FIXED_SOURCE" 2>/dev/null || stat -f%z "$FIXED_SOURCE" 2>/dev/null || echo "unknown")
log_success "Repackaged source created: $FIXED_SOURCE ($FIXED_SIZE bytes)"

rm -rf "$EXTRACT_DIR"

# ============================================
# Build wheel
# ============================================
log_step "Building pandas wheel"

log_info "Running: pip wheel \"$FIXED_SOURCE\" --no-deps --wheel-dir ."
log_info "This may take a while..."

if pip wheel "$FIXED_SOURCE" --no-deps --wheel-dir . 2>&1 | while IFS= read -r line; do
    # Filter out some verbose pip messages but keep important ones
    if [[ "$line" != *"Looking in indexes"* ]] && [[ "$line" != *"Collecting"* ]]; then
        log_info "  $line"
    fi
done; then
    log_success "pandas wheel built successfully"
else
    log_error "Failed to build pandas wheel"
    log_info "Contents of working directory:"
    ls -la "$WHEELS_DIR" | while IFS= read -r line; do
        log_info "  $line"
    done
    exit 1
fi

# Find built wheel
WHEEL_FILE=$(ls pandas-*.whl 2>/dev/null | head -1)
if [ -z "$WHEEL_FILE" ]; then
    log_error "Built wheel file not found"
    log_info "Contents of working directory:"
    ls -la "$WHEELS_DIR" | while IFS= read -r line; do
        log_info "  $line"
    done
    exit 1
fi

WHEEL_SIZE=$(stat -c%s "$WHEEL_FILE" 2>/dev/null || stat -f%z "$WHEEL_FILE" 2>/dev/null || echo "unknown")
log_success "Wheel created: $WHEEL_FILE ($WHEEL_SIZE bytes)"

# ============================================
# Pre-install pandas dependencies
# ============================================
log_step "Pre-installing pandas dependencies"

log_info "Installing pandas runtime dependencies..."
DEPENDENCIES=(
    "python-dateutil>=2.8.2"
    "pytz>=2020.1"
    "tzdata>=2022.7"
)

for dep in "${DEPENDENCIES[@]}"; do
    log_info "Checking/installing: $dep"
    if python3 -m pip install "$dep" 2>&1 | while IFS= read -r line; do
        if [[ "$line" != *"Looking in indexes"* ]] && [[ "$line" != *"Collecting"* ]]; then
            log_info "  $line"
        fi
    done; then
        log_success "$dep installed/available"
    else
        log_warning "Failed to install $dep, but continuing..."
    fi
done

log_success "Pandas dependencies pre-installed"

# ============================================
# Install wheel
# ============================================
log_step "Installing pandas wheel"

log_info "Running: pip install --find-links . --no-index --no-deps pandas*.whl"
if pip install --find-links . --no-index --no-deps pandas*.whl 2>&1 | while IFS= read -r line; do
    log_info "  $line"
done; then
    log_success "pandas installed successfully"
else
    log_error "Failed to install pandas wheel"
    exit 1
fi

# ============================================
# Verify installation
# ============================================
log_step "Verifying installation"

if python3 -c "import pandas; print(f'pandas {pandas.__version__} installed successfully')" 2>&1; then
    log_success "pandas verification passed"
else
    log_error "pandas verification failed"
    exit 1
fi

log_step "Build complete!"
log_success "pandas has been successfully built and installed"
log_info "Wheel location: $WHEEL_FILE"
log_info "Wheel directory: $WHEELS_DIR"

exit 0


