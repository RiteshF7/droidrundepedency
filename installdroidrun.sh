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
# Step 0: Download and extract source.7z (Independent task)
# ============================================
log_info "Step 0: Setting up source packages..."

# Setup source directory paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="${SCRIPT_DIR}/depedencies/source"
DEPENDENCIES_DIR="${SCRIPT_DIR}/depedencies"
SOURCE_7Z="${DEPENDENCIES_DIR}/source.7z"
GITHUB_REPO="${GITHUB_REPO:-RiteshF7/droidrundepedency}"
GITHUB_RELEASE_TAG="${GITHUB_RELEASE_TAG:-latest}"

# Ensure directories exist
mkdir -p "$SOURCE_DIR" "$DEPENDENCIES_DIR"

# Check if source directory already has files
SOURCE_COUNT=$(find "$SOURCE_DIR" -maxdepth 1 -type f \( -name "*.tar.gz" -o -name "*.zip" \) ! -name "*sources.tar.gz" ! -name "*home_sources.tar.gz" ! -name "*test_*" 2>/dev/null | wc -l)

if [ "$SOURCE_COUNT" -eq 0 ]; then
    log_warning "No source packages found in $SOURCE_DIR"
    
    # Check if source.7z exists locally
    if [ -f "$SOURCE_7Z" ]; then
        log_info "Found source.7z locally, extracting..."
    else
        log_info "source.7z not found locally, downloading from GitHub releases..."
        
        # Check for download tools
        if ! command_exists curl && ! command_exists wget; then
            log_error "Neither curl nor wget is available. Cannot download source.7z"
            log_error "Please install curl or wget: pkg install curl"
            exit 1
        fi
        
        # Get latest release tag if needed
        if [ "$GITHUB_RELEASE_TAG" = "latest" ]; then
            log_info "Fetching latest release tag from $GITHUB_REPO..."
            if command_exists curl; then
                RELEASE_TAG=$(curl -sL "https://api.github.com/repos/${GITHUB_REPO}/releases/latest" | grep -o '"tag_name": "[^"]*' | cut -d'"' -f4)
            elif command_exists wget; then
                RELEASE_TAG=$(wget -qO- "https://api.github.com/repos/${GITHUB_REPO}/releases/latest" | grep -o '"tag_name": "[^"]*' | cut -d'"' -f4)
            fi
            
            if [ -z "$RELEASE_TAG" ]; then
                log_error "Failed to get latest release tag"
                exit 1
            fi
            log_success "Latest release tag: $RELEASE_TAG"
        else
            RELEASE_TAG="$GITHUB_RELEASE_TAG"
        fi
        
        # Download source.7z
        DOWNLOAD_URL="https://github.com/${GITHUB_REPO}/releases/download/${RELEASE_TAG}/source.7z"
        log_info "Downloading from: $DOWNLOAD_URL"
        log_info "Saving to: $SOURCE_7Z"
        
        if command_exists curl; then
            if curl -fL --progress-bar -o "$SOURCE_7Z" "$DOWNLOAD_URL"; then
                SIZE=$(du -h "$SOURCE_7Z" | cut -f1)
                log_success "Downloaded source.7z ($SIZE)"
            else
                log_error "Failed to download source.7z"
                rm -f "$SOURCE_7Z"
                exit 1
            fi
        elif command_exists wget; then
            if wget --progress=bar:force -O "$SOURCE_7Z" "$DOWNLOAD_URL" 2>&1; then
                SIZE=$(du -h "$SOURCE_7Z" | cut -f1)
                log_success "Downloaded source.7z ($SIZE)"
            else
                log_error "Failed to download source.7z"
                rm -f "$SOURCE_7Z"
                exit 1
            fi
        fi
    fi
    
    # Extract source.7z
    if [ -f "$SOURCE_7Z" ]; then
        log_info "Extracting source.7z to $SOURCE_DIR..."
        
        # Check for 7z extraction tool
        if ! command_exists 7z && ! command_exists 7za; then
            log_error "7z or 7za is not available"
            log_error "Install with: pkg install p7zip"
            exit 1
        fi
        
        # Extract to a temporary directory first to handle subdirectory structure
        TEMP_EXTRACT_DIR=$(mktemp -d)
        trap "rm -rf '$TEMP_EXTRACT_DIR'" EXIT
        
        if command_exists 7z; then
            if ! 7z x "$SOURCE_7Z" -o"$TEMP_EXTRACT_DIR" -y >/dev/null 2>&1; then
                log_error "Failed to extract source.7z with 7z"
                exit 1
            fi
        elif command_exists 7za; then
            if ! 7za x "$SOURCE_7Z" -o"$TEMP_EXTRACT_DIR" -y >/dev/null 2>&1; then
                log_error "Failed to extract source.7z with 7za"
                exit 1
            fi
        fi
        
        # Move extracted files to SOURCE_DIR
        EXTRACTED_FILES=$(find "$TEMP_EXTRACT_DIR" -type f \( -name "*.tar.gz" -o -name "*.zip" \) ! -name "*sources.tar.gz" ! -name "*home_sources.tar.gz" ! -name "*test_*" 2>/dev/null)
        
        if [ -z "$EXTRACTED_FILES" ]; then
            # Check if files are in a subdirectory
            SUBDIR=$(find "$TEMP_EXTRACT_DIR" -mindepth 1 -maxdepth 1 -type d | head -1)
            if [ -n "$SUBDIR" ]; then
                log_info "Files extracted to subdirectory, moving to $SOURCE_DIR..."
                find "$SUBDIR" -type f -exec mv {} "$SOURCE_DIR"/ \; 2>/dev/null || true
            else
                log_warning "No source packages found in extracted archive"
            fi
        else
            # Files are directly in temp directory
            log_info "Moving extracted files to $SOURCE_DIR..."
            find "$TEMP_EXTRACT_DIR" -type f \( -name "*.tar.gz" -o -name "*.zip" \) ! -name "*sources.tar.gz" ! -name "*home_sources.tar.gz" ! -name "*test_*" -exec mv {} "$SOURCE_DIR"/ \; 2>/dev/null || true
        fi
        
        # Cleanup temp directory
        rm -rf "$TEMP_EXTRACT_DIR"
        trap - EXIT
        
        # Re-count source packages after extraction
        SOURCE_COUNT=$(find "$SOURCE_DIR" -maxdepth 1 -type f \( -name "*.tar.gz" -o -name "*.zip" \) ! -name "*sources.tar.gz" ! -name "*home_sources.tar.gz" ! -name "*test_*" 2>/dev/null | wc -l)
        
        if [ "$SOURCE_COUNT" -gt 0 ]; then
            log_success "Extracted $SOURCE_COUNT source packages to $SOURCE_DIR"
        else
            log_error "No source packages found after extraction"
            log_error "Please check if source.7z contains valid source packages"
            exit 1
        fi
    fi
else
    log_success "Found $SOURCE_COUNT source packages in $SOURCE_DIR (using local sources)"
fi

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

# Function to find source file locally
find_source_file() {
    local pkg_name=$1
    local version_pattern=$2
    
    # Try exact match first
    if [ -n "$version_pattern" ]; then
        local exact_match=$(find "$SOURCE_DIR" -maxdepth 1 -type f \( -name "${pkg_name}-${version_pattern}*.tar.gz" -o -name "${pkg_name}-${version_pattern}*.zip" \) ! -name "*sources.tar.gz" ! -name "*home_sources.tar.gz" ! -name "*test_*" 2>/dev/null | head -1)
        if [ -n "$exact_match" ]; then
            echo "$exact_match"
            return 0
        fi
    fi
    
    # Try pattern match
    local pattern_match=$(find "$SOURCE_DIR" -maxdepth 1 -type f \( -name "${pkg_name}-*.tar.gz" -o -name "${pkg_name}-*.zip" \) ! -name "*sources.tar.gz" ! -name "*home_sources.tar.gz" ! -name "*test_*" 2>/dev/null | head -1)
    if [ -n "$pattern_match" ]; then
        echo "$pattern_match"
        return 0
    fi
    
    return 1
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

pip install --upgrade pip wheel setuptools --quiet
pip install Cython "meson-python<0.19.0,>=0.16.0" "maturin<2,>=1.9.4" --quiet
log_success "Phase 1 complete: Build tools installed"

# ============================================
# Phase 2: Foundation (numpy)
# ============================================
log_info "Phase 2: Building numpy..."
cd "$WHEELS_DIR"

NUMPY_SOURCE=$(find_source_file "numpy" "")
if [ -n "$NUMPY_SOURCE" ]; then
    log_info "Using local source: $(basename "$NUMPY_SOURCE")"
    pip wheel "$NUMPY_SOURCE" --no-deps --wheel-dir .
else
    log_warning "numpy source not found locally, downloading..."
    pip download numpy --dest . --no-cache-dir
    pip wheel numpy --no-deps --wheel-dir .
fi
pip install --find-links . --no-index numpy*.whl
log_success "Phase 2 complete: numpy installed"

# ============================================
# Phase 3: Scientific Stack
# ============================================
log_info "Phase 3: Building scientific stack..."

# Build scipy
log_info "Building scipy..."
SCIPY_SOURCE=$(find_source_file "scipy" "")
if [ -n "$SCIPY_SOURCE" ]; then
    log_info "Using local source: $(basename "$SCIPY_SOURCE")"
    pip wheel "$SCIPY_SOURCE" --no-deps --wheel-dir .
else
    log_warning "scipy source not found locally, downloading..."
    pip download "scipy>=1.8.0,<1.17.0" --dest . --no-cache-dir
    pip wheel scipy --no-deps --wheel-dir .
fi
pip install --find-links . --no-index scipy*.whl
log_success "scipy installed"

# Build pandas (with meson.build fix)
log_info "Building pandas (applying meson.build fix)..."
PANDAS_SOURCE=$(find_source_file "pandas" "")
if [ -z "$PANDAS_SOURCE" ]; then
    log_warning "pandas source not found locally, downloading..."
    pip download "pandas<2.3.0" --dest . --no-cache-dir
    PANDAS_SOURCE=$(ls pandas-*.tar.gz | head -1)
fi

if [ -n "$PANDAS_SOURCE" ]; then
    log_info "Using local source: $(basename "$PANDAS_SOURCE")"
    # Fix meson.build version detection issue
    PANDAS_DIR=$(basename "$PANDAS_SOURCE" .tar.gz)
    WORK_DIR=$(mktemp -d)
    cp "$PANDAS_SOURCE" "$WORK_DIR/"
    cd "$WORK_DIR"
    tar -xzf "$(basename "$PANDAS_SOURCE")"
    if [ -f "$PANDAS_DIR/meson.build" ]; then
        sed -i "s/version: run_command.*/version: '$(echo $PANDAS_DIR | sed 's/pandas-//')',/" "$PANDAS_DIR/meson.build"
        tar -czf "$(basename "$PANDAS_SOURCE")" "$PANDAS_DIR/"
    fi
    pip wheel "$(basename "$PANDAS_SOURCE")" --no-deps --wheel-dir "$WHEELS_DIR"
    cd "$WHEELS_DIR"
    rm -rf "$WORK_DIR"
    pip install --find-links . --no-index pandas*.whl
    log_success "pandas installed"
else
    log_error "Failed to find pandas tarball"
    exit 1
fi

# Build scikit-learn (use pre-fixed tarball)
log_info "Building scikit-learn..."
SCIKIT_SOURCE=$(find "$SOURCE_DIR" -maxdepth 1 -type f \( -name "scikit*.tar.gz" -o -name "*scikit*.tar.gz" \) ! -name "*sources.tar.gz" ! -name "*home_sources.tar.gz" ! -name "*test_*" 2>/dev/null | head -1)
if [ -n "$SCIKIT_SOURCE" ]; then
    log_info "Using local source: $(basename "$SCIKIT_SOURCE")"
    pip wheel "$SCIKIT_SOURCE" --no-deps --no-build-isolation --wheel-dir .
else
    log_warning "scikit-learn source not found locally, using GitHub..."
    pip wheel https://raw.githubusercontent.com/RiteshF7/termux-packages/master/tmp_scikit_fixed.tar.gz --no-deps --no-build-isolation --wheel-dir .
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

JITER_SOURCE=$(find_source_file "jiter" "0.12.0")
if [ -n "$JITER_SOURCE" ]; then
    log_info "Using local source: $(basename "$JITER_SOURCE")"
    pip wheel "$JITER_SOURCE" --no-deps --wheel-dir .
else
    log_warning "jiter source not found locally, downloading..."
    pip download jiter==0.12.0 --dest . --no-cache-dir
    pip wheel jiter --no-deps --wheel-dir .
fi
pip install --find-links . --no-index jiter*.whl
log_success "Phase 4 complete: jiter installed"

# ============================================
# Phase 5: Other Compiled Packages
# ============================================
log_info "Phase 5: Building other compiled packages..."

# Build pyarrow
log_info "Building pyarrow..."
PYARROW_SOURCE=$(find_source_file "pyarrow" "")
if [ -n "$PYARROW_SOURCE" ]; then
    log_info "Using local source: $(basename "$PYARROW_SOURCE")"
    export ARROW_HOME=$PREFIX
    pip wheel "$PYARROW_SOURCE" --no-deps --wheel-dir .
    pip install --find-links . --no-index pyarrow*.whl
    log_success "pyarrow installed (built from source)"
else
    log_warning "pyarrow source not found locally, trying pre-built wheel..."
    pip download pyarrow --dest . --no-cache-dir
    if pip install --find-links . --no-index pyarrow*.whl 2>/dev/null; then
        log_success "pyarrow installed (pre-built wheel)"
    else
        log_info "No pre-built wheel found, building from source..."
        export ARROW_HOME=$PREFIX
        pip wheel pyarrow --no-deps --wheel-dir .
        pip install --find-links . --no-index pyarrow*.whl
        log_success "pyarrow installed (built from source)"
    fi
fi

# Build psutil
log_info "Building psutil..."
PSUTIL_SOURCE=$(find_source_file "psutil" "")
if [ -n "$PSUTIL_SOURCE" ]; then
    log_info "Using local source: $(basename "$PSUTIL_SOURCE")"
    pip wheel "$PSUTIL_SOURCE" --no-deps --wheel-dir .
else
    log_warning "psutil source not found locally, downloading..."
    pip download psutil --dest . --no-cache-dir
    pip wheel psutil --no-deps --wheel-dir .
fi
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

GRPCIO_SOURCE=$(find_source_file "grpcio" "")
if [ -n "$GRPCIO_SOURCE" ]; then
    log_info "Using local source: $(basename "$GRPCIO_SOURCE")"
    # Build wheel from local source
    pip wheel "$GRPCIO_SOURCE" --no-deps --no-build-isolation --wheel-dir .
else
    log_warning "grpcio source not found locally, downloading..."
    pip download grpcio --dest . --no-cache-dir
    # Build wheel
    pip wheel grpcio --no-deps --no-build-isolation --wheel-dir .
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

PILLOW_SOURCE=$(find_source_file "pillow" "")
if [ -n "$PILLOW_SOURCE" ]; then
    log_info "Using local source: $(basename "$PILLOW_SOURCE")"
    pip wheel "$PILLOW_SOURCE" --no-deps --wheel-dir .
else
    log_warning "pillow source not found locally, downloading..."
    pip download pillow --dest . --no-cache-dir
    pip wheel pillow --no-deps --wheel-dir .
fi
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
    
    for pkg in tokenizers safetensors cryptography pydantic-core orjson; do
        PKG_SOURCE=$(find_source_file "$pkg" "")
        if [ -n "$PKG_SOURCE" ]; then
            log_info "Using local source for $pkg: $(basename "$PKG_SOURCE")"
            if pip wheel "$PKG_SOURCE" --no-deps --wheel-dir . 2>/dev/null; then
                log_success "$pkg built"
            else
                log_warning "Skipping $pkg (build failed)"
            fi
        else
            log_warning "$pkg source not found locally, downloading..."
            pip download "$pkg" --dest . --no-cache-dir
            if pip wheel "$pkg" --no-deps --wheel-dir . 2>/dev/null; then
                log_success "$pkg built"
            else
                log_warning "Skipping $pkg (may have wheel or build failed)"
            fi
        fi
    done
    
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

