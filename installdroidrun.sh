#!/usr/bin/env bash
# droidrun Installation Script for Android/Termux
# Implements all phases from DEPENDENCIES.md

set -euo pipefail

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

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

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if package is installed
pkg_installed() {
    pkg list-installed 2>/dev/null | grep -q "^$1 " || return 1
}

# Validate tar.gz file integrity (global validation function)
validate_tar_gz() {
    local file=$1
    if [ ! -f "$file" ]; then
        return 1
    fi
    
    # Quick check: tar.gz files should start with gzip magic bytes (1f 8b)
    if [[ "$file" == *.tar.gz ]]; then
        local magic=$(head -c 2 "$file" | od -An -tx1 2>/dev/null | tr -d ' \n')
        if [ "$magic" != "1f8b" ]; then
            return 1
        fi
    fi
    
    # Verify it's a valid gzip file using Python (more reliable)
    if ! python3 -c "import gzip; f = open('$file', 'rb'); gzip.GzipFile(fileobj=f).read(1); f.close()" 2>/dev/null; then
        return 1
    fi
    
    # Check if it's a valid tar archive
    if ! tar -tzf "$file" >/dev/null 2>&1; then
        return 1
    fi
    
    return 0
}

# Safe source file usage - validates before using, downloads if needed
use_source_file() {
    local pkg_name=$1
    local version_spec=$2
    local source_file=$(get_source_file "$pkg_name")
    
    log_info "Checking source for $pkg_name..."
    
    if [ -f "$source_file" ]; then
        if validate_tar_gz "$source_file"; then
            local size=$(stat -c%s "$source_file" 2>/dev/null || stat -f%z "$source_file" 2>/dev/null || echo "0")
            log_success "Found valid local source: $(basename "$source_file") ($(numfmt --to=iec-i --suffix=B $size 2>/dev/null || echo "${size}B"))"
            return 0
        else
            log_warning "$(basename "$source_file") is corrupted or invalid"
            log_info "Removing corrupted file and downloading fresh copy..."
            rm -f "$source_file"
        fi
    fi
    
    # Download source file
    log_info "Downloading $pkg_name source ($version_spec)..."
    if pip download "$version_spec" --dest "$SOURCE_DIR" --no-cache-dir --no-binary :all: 2>&1 | grep -v "Looking in indexes" | grep -v "Collecting" | grep -v "Downloading" | grep -v "^$" | while read line; do log_info "  $line"; done; then
        # Find downloaded file and rename to standard name
        local downloaded_file=$(ls "$SOURCE_DIR"/${pkg_name}-*.tar.gz 2>/dev/null | head -1)
        if [ -n "$downloaded_file" ] && [ "$downloaded_file" != "$source_file" ]; then
            mv "$downloaded_file" "$source_file"
            log_success "Downloaded and renamed: $(basename "$source_file")"
        fi
        
        # Validate downloaded file
        if [ -f "$source_file" ] && validate_tar_gz "$source_file"; then
            local size=$(stat -c%s "$source_file" 2>/dev/null || stat -f%z "$source_file" 2>/dev/null || echo "0")
            log_success "Downloaded and validated: $(basename "$source_file") ($(numfmt --to=iec-i --suffix=B $size 2>/dev/null || echo "${size}B"))"
            return 0
        else
            log_error "Downloaded file validation failed for $pkg_name"
            rm -f "$source_file"
            return 1
        fi
    else
        log_error "Failed to download $pkg_name source"
        return 1
    fi
}

# Validate tar.gz file integrity
validate_tar_gz() {
    local file=$1
    if [ ! -f "$file" ]; then
        return 1
    fi
    
    # Check if file is a valid gzip file
    if ! gzip -t "$file" 2>/dev/null; then
        return 1
    fi
    
    # Check if file is a valid tar archive
    if ! tar -tzf "$file" >/dev/null 2>&1; then
        return 1
    fi
    
    return 0
}

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}droidrun Installation Script${NC}"
echo -e "${BLUE}========================================${NC}"
echo

# ============================================
# Setup PREFIX and check Termux environment
# ============================================
if [ -z "${PREFIX:-}" ]; then
    export PREFIX="/data/data/com.termux/files/usr"
fi

if [ ! -d "$PREFIX" ]; then
    log_error "Termux PREFIX directory not found: $PREFIX"
    log_error "This script must be run in Termux environment"
    exit 1
fi

log_info "PREFIX: $PREFIX"

# ============================================
# Setup source directory paths
# ============================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="${SCRIPT_DIR}/depedencies/source"
DEPENDENCIES_DIR="${SCRIPT_DIR}/depedencies"

# Ensure directories exist
mkdir -p "$SOURCE_DIR" "$DEPENDENCIES_DIR"

log_info "Source directory: $SOURCE_DIR"
echo

# ============================================
# Check and install system dependencies
# ============================================
log_info "Checking system dependencies..."

REQUIRED_PKGS=(
    "python" "python-pip"
    "autoconf" "automake" "libtool" "make" "binutils"
    "clang" "cmake" "ninja"
    "rust"
    "flang" "blas-openblas"
    "libjpeg-turbo" "libpng" "libtiff" "libwebp" "freetype"
    "libarrow-cpp"
    "openssl" "libc++" "zlib"
    "protobuf" "libprotobuf"
    "abseil-cpp" "c-ares" "libre2"
    "patchelf"
)

MISSING_PKGS=()
for pkg in "${REQUIRED_PKGS[@]}"; do
    if ! pkg_installed "$pkg"; then
        MISSING_PKGS+=("$pkg")
    fi
done

if [ ${#MISSING_PKGS[@]} -gt 0 ]; then
    log_warning "Missing system packages: ${MISSING_PKGS[*]}"
    log_info "Installing missing packages..."
    pkg update -y
    pkg install -y "${MISSING_PKGS[@]}"
    log_success "System packages installed"
else
    log_success "All system dependencies are installed"
fi

# ============================================
# Setup build environment variables
# ============================================
log_info "Setting up build environment..."

export PREFIX=${PREFIX:-/data/data/com.termux/files/usr}

# Build parallelization (limit to 2 jobs to avoid memory issues)
export NINJAFLAGS="-j2"
export MAKEFLAGS="-j2"
export MAX_JOBS=2

# CMAKE configuration (required for patchelf and other CMake-based builds)
export CMAKE_PREFIX_PATH=$PREFIX
export CMAKE_INCLUDE_PATH=$PREFIX/include

# Compiler environment variables
export CC=$PREFIX/bin/clang
export CXX=$PREFIX/bin/clang++

# Temporary directory (fixes compiler permission issues)
export TMPDIR=$HOME/tmp
mkdir -p "$TMPDIR"

# Ensure wheels directory exists
WHEELS_DIR="${HOME}/wheels"
mkdir -p "$WHEELS_DIR"

log_success "Build environment configured"

# Helper function to get source file path
get_source_file() {
    local pkg_name=$1
    echo "${SOURCE_DIR}/${pkg_name}.tar.gz"
}

# ============================================
# Create gfortran symlink for scipy compatibility
# ============================================
if [ ! -f "$PREFIX/bin/gfortran" ]; then
    log_info "Creating gfortran symlink (required for scipy/scikit-learn)..."
    ln -sf "$PREFIX/bin/flang" "$PREFIX/bin/gfortran"
    log_success "gfortran symlink created"
fi

# ============================================
# Check Python and pip
# ============================================
if ! command_exists python3; then
    log_error "python3 is not installed"
    exit 1
fi

if ! command_exists pip; then
    log_error "pip is not installed"
    exit 1
fi

PYTHON_VERSION=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>/dev/null || echo "unknown")
log_success "Python $PYTHON_VERSION found"

# ============================================
# Phase 1: Build Tools (Pure Python)
# ============================================
log_info "Phase 1: Installing build tools..."
cd "$WHEELS_DIR"

pip install --upgrade wheel setuptools --quiet
pip install Cython "meson-python<0.19.0,>=0.16.0" "maturin<2,>=1.9.4" --quiet
log_success "Phase 1 complete: Build tools installed"

# ============================================
# Phase 2: Foundation (numpy)
# ============================================
log_info "Phase 2: Building numpy..."
cd "$WHEELS_DIR"

if use_source_file "numpy" "numpy"; then
    local source_file=$(get_source_file "numpy")
    log_info "Building wheel from source: $(basename "$source_file")"
    if pip wheel "$source_file" --no-deps --wheel-dir . 2>&1 | grep -v "Looking in indexes" | grep -v "Collecting" | while read line; do log_info "  $line"; done; then
        log_success "numpy wheel built successfully"
    else
        log_error "Failed to build numpy wheel"
        exit 1
    fi
else
    log_error "Failed to obtain numpy source"
    exit 1
fi

log_info "Installing numpy wheel..."
pip install --find-links . --no-index numpy*.whl
log_success "Phase 2 complete: numpy installed"

# ============================================
# Phase 3: Scientific Stack
# ============================================
log_info "Phase 3: Building scientific stack..."

# Build scipy
log_info "Building scipy..."
if use_source_file "scipy" "scipy>=1.8.0,<1.17.0"; then
    local source_file=$(get_source_file "scipy")
    log_info "Building wheel from source: $(basename "$source_file")"
    if pip wheel "$source_file" --no-deps --wheel-dir . 2>&1 | grep -v "Looking in indexes" | grep -v "Collecting" | while read line; do log_info "  $line"; done; then
        log_success "scipy wheel built successfully"
    else
        log_error "Failed to build scipy wheel"
        exit 1
    fi
else
    log_error "Failed to obtain scipy source"
    exit 1
fi
log_info "Installing scipy wheel..."
pip install --find-links . --no-index scipy*.whl
log_success "scipy installed"

# Build pandas (with meson.build fix)
log_info "Building pandas (applying meson.build fix)..."
if use_source_file "pandas" "pandas<2.3.0"; then
    local source_file=$(get_source_file "pandas")
    log_info "Applying meson.build fix to pandas source..."
    
    # Fix meson.build version detection issue
    WORK_DIR=$(mktemp -d)
    cp "$source_file" "$WORK_DIR/"
    cd "$WORK_DIR"
    log_info "Extracting pandas source..."
    tar -xzf pandas.tar.gz
    PANDAS_DIR=$(ls -d pandas-* | head -1)
    if [ -f "$PANDAS_DIR/meson.build" ]; then
        PANDAS_VERSION=$(echo "$PANDAS_DIR" | sed 's/pandas-//')
        log_info "Fixing meson.build: replacing version detection with '$PANDAS_VERSION'"
        sed -i "s/version: run_command.*/version: '$PANDAS_VERSION',/" "$PANDAS_DIR/meson.build"
        log_success "meson.build fixed"
        tar -czf pandas.tar.gz "$PANDAS_DIR/"
    fi
    
    log_info "Building wheel from fixed source..."
    if pip wheel pandas.tar.gz --no-deps --wheel-dir "$WHEELS_DIR" 2>&1 | grep -v "Looking in indexes" | grep -v "Collecting" | while read line; do log_info "  $line"; done; then
        log_success "pandas wheel built successfully"
    else
        log_error "Failed to build pandas wheel"
        rm -rf "$WORK_DIR"
        exit 1
    fi
    cd "$WHEELS_DIR"
    rm -rf "$WORK_DIR"
    
    log_info "Installing pandas wheel..."
    pip install --find-links . --no-index pandas*.whl
    log_success "pandas installed"
else
    log_error "Failed to obtain pandas source"
    exit 1
fi

# Build scikit-learn (with source fixes)
log_info "Building scikit-learn..."
if use_source_file "scikit-learn" "scikit-learn"; then
    local source_file=$(get_source_file "scikit-learn")
    log_info "Applying fixes to scikit-learn source..."
    
    # Fix scikit-learn source files
    WORK_DIR=$(mktemp -d)
    cp "$source_file" "$WORK_DIR/"
    cd "$WORK_DIR"
    log_info "Extracting scikit-learn source..."
    tar -xzf scikit-learn.tar.gz
    SCIKIT_DIR=$(ls -d scikit-learn-* | head -1)
    
    # Fix 1: Add shebang to version.py
    if [ -f "$SCIKIT_DIR/sklearn/_build_utils/version.py" ]; then
        if ! head -1 "$SCIKIT_DIR/sklearn/_build_utils/version.py" | grep -q "^#!/"; then
            log_info "Fixing sklearn/_build_utils/version.py: adding shebang"
            sed -i '1i#!/usr/bin/env python3' "$SCIKIT_DIR/sklearn/_build_utils/version.py"
            log_success "version.py fixed"
        fi
    fi
    
    # Fix 2: Fix meson.build version extraction
    if [ -f "$SCIKIT_DIR/meson.build" ]; then
        SCIKIT_VERSION=$(echo "$SCIKIT_DIR" | sed 's/scikit-learn-//')
        log_info "Fixing meson.build: replacing version extraction with '$SCIKIT_VERSION'"
        sed -i "s/version: run_command.*/version: '$SCIKIT_VERSION',/" "$SCIKIT_DIR/meson.build" 2>/dev/null || \
        sed -i "s/version:.*/version: '$SCIKIT_VERSION',/" "$SCIKIT_DIR/meson.build"
        log_success "meson.build fixed"
    fi
    
    # Repackage fixed tarball
    log_info "Repackaging fixed source..."
    tar -czf scikit-learn.tar.gz "$SCIKIT_DIR/"
    
    log_info "Building wheel from fixed source..."
    if pip wheel scikit-learn.tar.gz --no-deps --no-build-isolation --wheel-dir "$WHEELS_DIR" 2>&1 | grep -v "Looking in indexes" | grep -v "Collecting" | while read line; do log_info "  $line"; done; then
        log_success "scikit-learn wheel built successfully"
    else
        log_error "Failed to build scikit-learn wheel"
        rm -rf "$WORK_DIR"
        exit 1
    fi
    cd "$WHEELS_DIR"
    rm -rf "$WORK_DIR"
else
    log_error "Failed to obtain scikit-learn source"
    exit 1
fi

# Install missing dependencies first (required before installing scikit-learn)
pip install joblib>=1.3.0 threadpoolctl>=3.2.0 --quiet

# Install the wheel
pip install --find-links . --no-index scikit_learn*.whl
log_success "scikit-learn installed"

log_success "Phase 3 complete: Scientific stack installed"

# ============================================
# Phase 4: Rust Packages (jiter)
# ============================================
log_info "Phase 4: Building jiter..."
cd "$WHEELS_DIR"

if use_source_file "jiter" "jiter==0.12.0"; then
    local source_file=$(get_source_file "jiter")
    log_info "Building wheel from source: $(basename "$source_file")"
    if pip wheel "$source_file" --no-deps --wheel-dir . 2>&1 | grep -v "Looking in indexes" | grep -v "Collecting" | while read line; do log_info "  $line"; done; then
        log_success "jiter wheel built successfully"
    else
        log_error "Failed to build jiter wheel"
        exit 1
    fi
else
    log_error "Failed to obtain jiter source"
    exit 1
fi
log_info "Installing jiter wheel..."
pip install --find-links . --no-index jiter*.whl
log_success "Phase 4 complete: jiter installed"

# ============================================
# Phase 5: Other Compiled Packages
# ============================================
log_info "Phase 5: Building other compiled packages..."

# Build pyarrow
log_info "Building pyarrow..."
log_info "Checking for pre-built pyarrow wheel first..."
pip download pyarrow --dest . --no-cache-dir 2>&1 | grep -v "Looking in indexes" | grep -v "Collecting" | while read line; do log_info "  $line"; done || true
if pip install --find-links . --no-index pyarrow*.whl 2>/dev/null; then
    log_success "pyarrow installed (pre-built wheel)"
else
    log_info "No pre-built wheel found, building from source..."
    if use_source_file "pyarrow" "pyarrow"; then
        export ARROW_HOME=$PREFIX
        local source_file=$(get_source_file "pyarrow")
        log_info "Building wheel from source: $(basename "$source_file")"
        if pip wheel "$source_file" --no-deps --wheel-dir . 2>&1 | grep -v "Looking in indexes" | grep -v "Collecting" | while read line; do log_info "  $line"; done; then
            log_success "pyarrow wheel built successfully"
        else
            log_error "Failed to build pyarrow wheel"
            exit 1
        fi
        log_info "Installing pyarrow wheel..."
        pip install --find-links . --no-index pyarrow*.whl
        log_success "pyarrow installed (built from source)"
    else
        log_error "Failed to obtain pyarrow source"
        exit 1
    fi
fi

# Build psutil
log_info "Building psutil..."
if use_source_file "psutil" "psutil"; then
    local source_file=$(get_source_file "psutil")
    log_info "Building wheel from source: $(basename "$source_file")"
    if pip wheel "$source_file" --no-deps --wheel-dir . 2>&1 | grep -v "Looking in indexes" | grep -v "Collecting" | while read line; do log_info "  $line"; done; then
        log_success "psutil wheel built successfully"
    else
        log_error "Failed to build psutil wheel"
        exit 1
    fi
else
    log_error "Failed to obtain psutil source"
    exit 1
fi
log_info "Installing psutil wheel..."
pip install --find-links . --no-index psutil*.whl
log_success "psutil installed"

# Build grpcio (with wheel patching)
log_info "Building grpcio (this may take a while)..."

# Set GRPC build flags to use system libraries
export GRPC_PYTHON_BUILD_SYSTEM_OPENSSL=1
export GRPC_PYTHON_BUILD_SYSTEM_ZLIB=1
export GRPC_PYTHON_BUILD_SYSTEM_CARES=1
export GRPC_PYTHON_BUILD_SYSTEM_RE2=1
export GRPC_PYTHON_BUILD_SYSTEM_ABSL=1
export GRPC_PYTHON_BUILD_WITH_CYTHON=1

if use_source_file "grpcio" "grpcio"; then
    local source_file=$(get_source_file "grpcio")
    log_info "Building wheel from source: $(basename "$source_file")"
    if pip wheel "$source_file" --no-deps --no-build-isolation --wheel-dir . 2>&1 | grep -v "Looking in indexes" | grep -v "Collecting" | while read line; do log_info "  $line"; done; then
        log_success "grpcio wheel built successfully"
    else
        log_error "Failed to build grpcio wheel"
        exit 1
    fi
else
    log_error "Failed to obtain grpcio source"
    exit 1
fi

# Fix wheel: extract, patch .so, repackage
WHEEL_FILE=$(ls grpcio-*.whl | head -1)
if [ -z "$WHEEL_FILE" ]; then
    log_error "Failed to build grpcio wheel"
    exit 1
fi

log_info "Fixing grpcio wheel: $WHEEL_FILE"

# Extract wheel
unzip -q "$WHEEL_FILE" -d grpcio_extract

# Find and patch the .so file
SO_FILE=$(find grpcio_extract -name "cygrpc*.so" | head -1)
if [ -z "$SO_FILE" ]; then
    log_error "Error: cygrpc*.so not found in wheel"
    rm -rf grpcio_extract
    exit 1
fi

# Add abseil libraries to NEEDED list and set RPATH
patchelf --add-needed libabsl_flags_internal.so "$SO_FILE"
patchelf --add-needed libabsl_flags.so "$SO_FILE"
patchelf --add-needed libabsl_flags_commandlineflag.so "$SO_FILE"
patchelf --add-needed libabsl_flags_reflection.so "$SO_FILE"
patchelf --set-rpath "$PREFIX/lib" "$SO_FILE"

# Repackage the wheel
cd grpcio_extract
python3 << 'PYEOF'
import zipfile
import os
zf = zipfile.ZipFile('../grpcio-fixed.whl', 'w', zipfile.ZIP_DEFLATED)
for root, dirs, files in os.walk('.'):
    for file in files:
        filepath = os.path.join(root, file)
        arcname = os.path.relpath(filepath, '.')
        zf.write(filepath, arcname)
zf.close()
print('Fixed wheel created: grpcio-fixed.whl')
PYEOF
cd ..

# Replace original wheel with fixed one
rm -rf grpcio_extract
rm "$WHEEL_FILE"
mv grpcio-fixed.whl "$WHEEL_FILE"

# Install the fixed wheel
pip install --find-links . --no-index grpcio*.whl

# Set LD_LIBRARY_PATH for runtime (REQUIRED for grpcio to work)
export LD_LIBRARY_PATH=$PREFIX/lib:$LD_LIBRARY_PATH
# Add to ~/.bashrc for permanent fix
if ! grep -q "LD_LIBRARY_PATH.*PREFIX/lib" ~/.bashrc 2>/dev/null; then
    echo "export LD_LIBRARY_PATH=\$PREFIX/lib:\$LD_LIBRARY_PATH" >> ~/.bashrc
fi

log_success "grpcio installed (wheel fixed)"

# Build Pillow
log_info "Building Pillow..."
export PKG_CONFIG_PATH=$PREFIX/lib/pkgconfig:$PKG_CONFIG_PATH
export LDFLAGS="-L$PREFIX/lib"
export CPPFLAGS="-I$PREFIX/include"

if use_source_file "pillow" "pillow"; then
    local source_file=$(get_source_file "pillow")
    log_info "Building wheel from source: $(basename "$source_file")"
    if pip wheel "$source_file" --no-deps --wheel-dir . 2>&1 | grep -v "Looking in indexes" | grep -v "Collecting" | while read line; do log_info "  $line"; done; then
        log_success "pillow wheel built successfully"
    else
        log_error "Failed to build pillow wheel"
        exit 1
    fi
else
    log_error "Failed to obtain pillow source"
    exit 1
fi
log_info "Installing pillow wheel..."
pip install --find-links . --no-index pillow*.whl
log_success "Pillow installed"

log_success "Phase 5 complete: Other compiled packages installed"

# ============================================
# Phase 6: Additional Compiled (optional)
# ============================================
log_info "Phase 6: Checking optional compiled packages..."

# These usually have pre-built wheels, try install first
if pip install tokenizers safetensors cryptography pydantic-core orjson --find-links "$WHEELS_DIR" 2>/dev/null; then
    log_success "Phase 6 complete: Optional packages installed (pre-built wheels)"
else
    log_info "Some packages need building from source..."
    
    # Build tokenizers
    log_info "Building tokenizers..."
    if use_source_file "tokenizers" "tokenizers"; then
        local source_file=$(get_source_file "tokenizers")
        if pip wheel "$source_file" --no-deps --wheel-dir . 2>&1 | grep -v "Looking in indexes" | grep -v "Collecting" | while read line; do log_info "  $line"; done; then
            log_success "tokenizers built"
        else
            log_warning "Skipping tokenizers (build failed)"
        fi
    else
        log_warning "Skipping tokenizers (source download failed)"
    fi
    
    # Build safetensors
    log_info "Building safetensors..."
    if use_source_file "safetensors" "safetensors"; then
        local source_file=$(get_source_file "safetensors")
        if pip wheel "$source_file" --no-deps --wheel-dir . 2>&1 | grep -v "Looking in indexes" | grep -v "Collecting" | while read line; do log_info "  $line"; done; then
            log_success "safetensors built"
        else
            log_warning "Skipping safetensors (build failed)"
        fi
    else
        log_warning "Skipping safetensors (source download failed)"
    fi
    
    # Build cryptography
    log_info "Building cryptography..."
    if use_source_file "cryptography" "cryptography"; then
        local source_file=$(get_source_file "cryptography")
        if pip wheel "$source_file" --no-deps --wheel-dir . 2>&1 | grep -v "Looking in indexes" | grep -v "Collecting" | while read line; do log_info "  $line"; done; then
            log_success "cryptography built"
        else
            log_warning "Skipping cryptography (build failed)"
        fi
    else
        log_warning "Skipping cryptography (source download failed)"
    fi
    
    # Build pydantic-core
    log_info "Building pydantic-core..."
    if use_source_file "pydantic-core" "pydantic-core"; then
        local source_file=$(get_source_file "pydantic-core")
        if pip wheel "$source_file" --no-deps --wheel-dir . 2>&1 | grep -v "Looking in indexes" | grep -v "Collecting" | while read line; do log_info "  $line"; done; then
            log_success "pydantic-core built"
        else
            log_warning "Skipping pydantic-core (build failed)"
        fi
    else
        log_warning "Skipping pydantic-core (source download failed)"
    fi
    
    # Build orjson
    log_info "Building orjson..."
    if use_source_file "orjson" "orjson"; then
        local source_file=$(get_source_file "orjson")
        if pip wheel "$source_file" --no-deps --wheel-dir . 2>&1 | grep -v "Looking in indexes" | grep -v "Collecting" | while read line; do log_info "  $line"; done; then
            log_success "orjson built"
        else
            log_warning "Skipping orjson (build failed)"
        fi
    else
        log_warning "Skipping orjson (source download failed)"
    fi
    
    # Install any wheels that were built
    pip install --find-links . --no-index tokenizers*.whl safetensors*.whl cryptography*.whl pydantic-core*.whl orjson*.whl 2>/dev/null || true
    log_success "Phase 6 complete: Optional packages processed"
fi

# ============================================
# Phase 7: Main Package + LLM Providers
# ============================================
log_info "Phase 7: Installing droidrun and LLM providers..."

cd "$HOME"

# Install base droidrun with all providers
log_info "Installing droidrun with all LLM providers..."
pip install 'droidrun[google,anthropic,openai,deepseek,ollama,openrouter]' --find-links "$WHEELS_DIR"

log_success "Phase 7 complete: droidrun installed"

# ============================================
# Final Summary
# ============================================
echo
echo -e "${BLUE}========================================${NC}"
log_success "Installation complete!"
echo -e "${BLUE}========================================${NC}"
echo
echo "droidrun has been successfully installed with all dependencies."
echo
echo "Important notes:"
echo "  - LD_LIBRARY_PATH has been configured for grpcio"
echo "  - Restart your terminal or run: source ~/.bashrc"
echo "  - Wheels are available in: $WHEELS_DIR"
echo
echo "To verify installation:"
echo "  python3 -c 'import droidrun; print(\"droidrun installed successfully\")'"
echo

exit 0
