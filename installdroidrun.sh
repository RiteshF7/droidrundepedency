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
# Setup script directory
# ============================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
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
if ! build_package "numpy" "numpy"; then
    exit 1
fi
log_success "Phase 2 complete: numpy installed"

# ============================================
# Phase 3: Scientific Stack
# ============================================
log_info "Phase 3: Building scientific stack..."

# Build scipy
if ! build_package "scipy" "scipy>=1.8.0,<1.17.0"; then
    exit 1
fi

# Build pandas (with meson.build fix)
if ! build_package "pandas" "pandas<2.3.0" --fix-source=pandas; then
    exit 1
fi

# Build scikit-learn (with source fixes)
# Install dependencies first
log_info "Installing scikit-learn dependencies..."
pip install joblib>=1.3.0 threadpoolctl>=3.2.0 --quiet

if ! build_package "scikit-learn" "scikit-learn" --fix-source=scikit-learn --no-build-isolation --wheel-pattern="scikit_learn*.whl"; then
    exit 1
fi

log_success "Phase 3 complete: Scientific stack installed"

# ============================================
# Phase 4: Rust Packages (jiter)
# ============================================
log_info "Phase 4: Building jiter..."
if ! build_package "jiter" "jiter==0.12.0"; then
    exit 1
fi
log_success "Phase 4 complete: jiter installed"

# ============================================
# Phase 5: Other Compiled Packages
# ============================================
log_info "Phase 5: Building other compiled packages..."

# Build pyarrow
if ! build_package "pyarrow" "pyarrow" --pre-check --env-var="ARROW_HOME=$PREFIX"; then
    exit 1
fi

# Build psutil
if ! build_package "psutil" "psutil"; then
    exit 1
fi

# Build grpcio (with wheel patching)
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
if pip wheel grpcio --no-deps --no-build-isolation --wheel-dir . 2>&1 | grep -v "Looking in indexes" | grep -v "Collecting" | while read line; do log_info "  $line"; done; then
    log_success "grpcio wheel built successfully"
else
    log_error "Failed to build grpcio wheel"
    exit 1
fi

# Fix grpcio wheel
if ! fix_grpcio_wheel; then
    exit 1
fi

# Install the fixed wheel
log_info "Installing grpcio wheel..."
pip install --find-links . --no-index grpcio*.whl

# Set LD_LIBRARY_PATH for runtime (REQUIRED for grpcio to work)
export LD_LIBRARY_PATH=$PREFIX/lib:$LD_LIBRARY_PATH
# Add to ~/.bashrc for permanent fix
if ! grep -q "LD_LIBRARY_PATH.*PREFIX/lib" ~/.bashrc 2>/dev/null; then
    echo "export LD_LIBRARY_PATH=\$PREFIX/lib:\$LD_LIBRARY_PATH" >> ~/.bashrc
fi

log_success "grpcio installed (wheel fixed)"

# Build Pillow
if ! build_package "pillow" "pillow" --env-var="PKG_CONFIG_PATH=$PREFIX/lib/pkgconfig:$PKG_CONFIG_PATH" --env-var="LDFLAGS=-L$PREFIX/lib" --env-var="CPPFLAGS=-I$PREFIX/include"; then
    exit 1
fi

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
    
    # List of optional packages to build
    optional_packages=("tokenizers" "safetensors" "cryptography" "pydantic-core" "orjson")
    built_packages=()
    
    # Build each package (continue on failure)
    for pkg in "${optional_packages[@]}"; do
        if build_package "$pkg" "$pkg" 2>/dev/null; then
            built_packages+=("$pkg")
        else
            log_warning "Skipping $pkg (build failed)"
        fi
    done
    
    # Install any wheels that were built
    if [ ${#built_packages[@]} -gt 0 ]; then
        wheel_patterns=""
        for pkg in "${built_packages[@]}"; do
            wheel_patterns="${wheel_patterns} ${pkg}*.whl"
        done
        pip install --find-links . --no-index $wheel_patterns 2>/dev/null || true
    fi
    
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
