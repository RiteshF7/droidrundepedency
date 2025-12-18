#!/usr/bin/env bash
# Standalone script to build scikit-learn for Termux
# This script isolates the scikit-learn build process for debugging

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

# Check if scipy is installed
if ! python3 -c "import scipy" 2>/dev/null; then
    log_warning "scipy not found, but continuing..."
fi

# Check if meson-python is installed
if ! python3 -c "import mesonpy" 2>/dev/null; then
    log_warning "meson-python not found, installing..."
    python3 -m pip install "meson-python<0.19.0,>=0.16.0" --quiet
fi
log_success "meson-python is available"

# Check if joblib is installed
if ! python3 -c "import joblib" 2>/dev/null; then
    log_warning "joblib not found, installing..."
    python3 -m pip install "joblib>=1.3.0" --quiet
fi
log_success "joblib is available"

# Check if threadpoolctl is installed
if ! python3 -c "import threadpoolctl" 2>/dev/null; then
    log_warning "threadpoolctl not found, installing..."
    python3 -m pip install "threadpoolctl>=3.2.0" --quiet
fi
log_success "threadpoolctl is available"

# ============================================
# Setup working directory
# ============================================
WHEELS_DIR="${HOME}/wheels"
mkdir -p "$WHEELS_DIR"
cd "$WHEELS_DIR"
log_info "Working directory: $WHEELS_DIR"

# ============================================
# Download scikit-learn source
# ============================================
log_step "Downloading scikit-learn source"

VERSION_SPEC="scikit-learn"
log_info "Version spec: $VERSION_SPEC"

# Get the latest version and download URL from PyPI JSON API
log_info "Getting latest version and download URL from PyPI..."
PYPI_JSON=""
if command -v curl >/dev/null 2>&1; then
    PYPI_JSON=$(curl -s https://pypi.org/pypi/scikit-learn/json)
elif command -v wget >/dev/null 2>&1; then
    PYPI_JSON=$(wget -q -O - https://pypi.org/pypi/scikit-learn/json)
else
    PYPI_JSON=$(python3 -c "import urllib.request; print(urllib.request.urlopen('https://pypi.org/pypi/scikit-learn/json').read().decode())" 2>/dev/null || echo "")
fi

if [ -z "$PYPI_JSON" ]; then
    log_error "Could not get PyPI JSON. Please check network connection."
    exit 1
fi

# Extract version and source tarball URL from JSON
PYPI_VERSION=$(echo "$PYPI_JSON" | python3 -c "import sys, json; print(json.load(sys.stdin)['info']['version'])" 2>/dev/null || echo "")
SOURCE_URL=$(echo "$PYPI_JSON" | python3 -c "import sys, json; data = json.load(sys.stdin); urls = [f['url'] for f in data['urls'] if f['packagetype'] == 'sdist']; print(urls[0] if urls else '')" 2>/dev/null || echo "")

if [ -z "$PYPI_VERSION" ] || [ -z "$SOURCE_URL" ]; then
    log_error "Could not extract version or URL from PyPI JSON"
    log_info "Version: $PYPI_VERSION"
    log_info "URL: $SOURCE_URL"
    exit 1
fi

log_info "Latest version: $PYPI_VERSION"
log_info "Source URL: $SOURCE_URL"
SOURCE_FILE="scikit-learn-${PYPI_VERSION}.tar.gz"
SOURCE_PATH="$WHEELS_DIR/$SOURCE_FILE"

log_info "Downloading from: $SOURCE_URL"
log_info "Saving to: $SOURCE_PATH"

# Download using curl, wget, or Python
DOWNLOAD_SUCCESS=false
if command -v curl >/dev/null 2>&1; then
    if curl -L -f -o "$SOURCE_PATH" "$SOURCE_URL" 2>&1 | while IFS= read -r line; do
        log_info "  $line"
    done; then
        DOWNLOAD_SUCCESS=true
    fi
elif command -v wget >/dev/null 2>&1; then
    if wget -O "$SOURCE_PATH" "$SOURCE_URL" 2>&1 | while IFS= read -r line; do
        log_info "  $line"
    done; then
        DOWNLOAD_SUCCESS=true
    fi
else
    if python3 -c "import urllib.request; urllib.request.urlretrieve('$SOURCE_URL', '$SOURCE_PATH')" 2>&1 | while IFS= read -r line; do
        log_info "  $line"
    done; then
        DOWNLOAD_SUCCESS=true
    fi
fi

# Verify download was successful and file has reasonable size (>1MB)
if [ "$DOWNLOAD_SUCCESS" = false ] || [ ! -f "$SOURCE_PATH" ]; then
    log_error "Failed to download scikit-learn source"
    exit 1
fi

FILE_SIZE=$(stat -c%s "$SOURCE_PATH" 2>/dev/null || stat -f%z "$SOURCE_PATH" 2>/dev/null || echo 0)
if [ "$FILE_SIZE" -lt 1000000 ]; then
    log_error "Downloaded file is too small ($FILE_SIZE bytes), download may have failed"
    rm -f "$SOURCE_PATH"
    exit 1
fi

log_info "Downloaded file size: $FILE_SIZE bytes"

SOURCE_FILE="$SOURCE_PATH"

# Verify downloaded file (SOURCE_FILE already contains full path)
if [ ! -f "$SOURCE_FILE" ]; then
    log_error "Downloaded source file not found: $SOURCE_FILE"
    log_info "Files in directory:"
    ls -la "$WHEELS_DIR" | while IFS= read -r line; do
        log_info "  $line"
    done
    exit 1
fi

# SOURCE_FILE already contains the full path from line 221, no need to prepend WHEELS_DIR

log_success "Found source file: $SOURCE_FILE"
SOURCE_SIZE=$(stat -c%s "$SOURCE_FILE" 2>/dev/null || stat -f%z "$SOURCE_FILE" 2>/dev/null || echo "unknown")
log_info "Source file size: $SOURCE_SIZE bytes"

# ============================================
# Extract and fix source
# ============================================
log_step "Extracting and fixing scikit-learn source"

EXTRACT_DIR=$(mktemp -d)
log_info "Extract directory: $EXTRACT_DIR"

log_info "Extracting $SOURCE_FILE..."
# Extract without piping to avoid blocking on empty output
set +e  # Temporarily disable exit on error to capture exit code
tar -xzf "$SOURCE_FILE" -C "$EXTRACT_DIR" >/dev/null 2>&1
TAR_EXIT=$?
set -e  # Re-enable exit on error

if [ $TAR_EXIT -ne 0 ]; then
    log_error "Failed to extract $SOURCE_FILE (exit code: $TAR_EXIT)"
    rm -rf "$EXTRACT_DIR"
    exit 1
fi

log_success "Extraction completed"

# Try both patterns: scikit-learn-* and scikit_learn-*
PKG_DIR=$(ls -d "$EXTRACT_DIR"/scikit-learn-* "$EXTRACT_DIR"/scikit_learn-* 2>/dev/null | head -1)
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

# Extract version from directory name (handle both scikit-learn and scikit_learn)
PKG_VERSION=$(basename "$PKG_DIR" | sed "s/scikit[-_]learn-//")
log_info "Package version: $PKG_VERSION"

# Fix sklearn/_build_utils/version.py - add shebang if missing
VERSION_PY="$PKG_DIR/sklearn/_build_utils/version.py"
if [ -f "$VERSION_PY" ]; then
    log_info "Found version.py at: $VERSION_PY"
    if ! head -1 "$VERSION_PY" | grep -q "^#!/"; then
        log_info "Fixing version.py: adding shebang"
        sed -i '1i#!/usr/bin/env python3' "$VERSION_PY"
        log_success "version.py fixed (shebang added)"
    else
        log_info "version.py already has shebang"
    fi
else
    log_warning "version.py not found at: $VERSION_PY (may not be needed)"
fi

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

log_info "Fixing meson.build: replacing version extraction with '$PKG_VERSION'"
# Try to replace version: run_command first, if that fails try version: pattern
if sed -i "s/version: run_command.*/version: '$PKG_VERSION',/" "$MESON_BUILD" 2>&1; then
    log_success "meson.build fixed (run_command pattern)"
else
    log_info "run_command pattern not found, trying generic version pattern"
    if sed -i "s/version:.*/version: '$PKG_VERSION',/" "$MESON_BUILD" 2>&1; then
        log_success "meson.build fixed (generic pattern)"
    else
        log_error "Failed to fix meson.build"
        rm -rf "$EXTRACT_DIR"
        exit 1
    fi
fi

log_info "Fixed meson.build (first 10 lines):"
head -10 "$MESON_BUILD" | while IFS= read -r line; do
    log_info "  $line"
done

# Repackage fixed source
log_info "Repackaging fixed source..."
FIXED_SOURCE="$WHEELS_DIR/scikit-learn-${PKG_VERSION}-fixed.tar.gz"
set +e  # Temporarily disable exit on error to capture exit code
tar -czf "$FIXED_SOURCE" -C "$EXTRACT_DIR" "$(basename "$PKG_DIR")" >/dev/null 2>&1
TAR_EXIT=$?
set -e  # Re-enable exit on error

if [ $TAR_EXIT -ne 0 ]; then
    log_error "Failed to repackage scikit-learn source (exit code: $TAR_EXIT)"
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
log_step "Building scikit-learn wheel"

log_info "Running: python3 -m pip wheel \"$FIXED_SOURCE\" --no-deps --no-build-isolation --wheel-dir ."
log_info "This may take a while..."

# Show output in real-time and capture exit code
set +e  # Temporarily disable exit on error to capture exit code
python3 -m pip wheel "$FIXED_SOURCE" --no-deps --no-build-isolation --wheel-dir . 2>&1 | while IFS= read -r line; do
    # Filter out some verbose pip messages but keep important ones
    if [[ "$line" != *"Looking in indexes"* ]] && [[ "$line" != *"Collecting"* ]]; then
        log_info "  $line"
    fi
done
WHEEL_EXIT_CODE=${PIPESTATUS[0]}
set -e  # Re-enable exit on error

if [ $WHEEL_EXIT_CODE -ne 0 ]; then
    log_error "Failed to build scikit-learn wheel (exit code: $WHEEL_EXIT_CODE)"
    log_info "Contents of working directory:"
    ls -la "$WHEELS_DIR" | while IFS= read -r line; do
        log_info "  $line"
    done
    exit 1
fi

log_success "scikit-learn wheel built successfully"

# Find built wheel
WHEEL_FILE=$(ls scikit_learn-*.whl 2>/dev/null | head -1)
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
# Install wheel
# ============================================
log_step "Installing scikit-learn wheel"

log_info "Running: python3 -m pip install --find-links . --no-index --no-deps scikit_learn*.whl"
# Show output in real-time and capture exit code
set +e  # Temporarily disable exit on error to capture exit code
python3 -m pip install --find-links . --no-index --no-deps scikit_learn*.whl 2>&1 | while IFS= read -r line; do
    log_info "  $line"
done
INSTALL_EXIT_CODE=${PIPESTATUS[0]}
set -e  # Re-enable exit on error

if [ $INSTALL_EXIT_CODE -ne 0 ]; then
    log_error "Failed to install scikit-learn wheel (exit code: $INSTALL_EXIT_CODE)"
    exit 1
fi

log_success "scikit-learn installed successfully"

# ============================================
# Verify installation
# ============================================
log_step "Verifying installation"

if python3 -c "import sklearn; print(f'scikit-learn {sklearn.__version__} installed successfully')" 2>&1; then
    log_success "scikit-learn verification passed"
else
    log_error "scikit-learn verification failed"
    exit 1
fi

log_step "Build complete!"
log_success "scikit-learn has been successfully built and installed"
log_info "Wheel location: $WHEEL_FILE"
log_info "Wheel directory: $WHEELS_DIR"

exit 0

