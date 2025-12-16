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

# Validate tar.gz file integrity
validate_tar_gz() {
    local file=$1
    if [ ! -f "$file" ]; then
        return 1
    fi
    
    # Check if file is a valid gzip file using Python (more reliable)
    if python3 -c "import gzip; f = open('$file', 'rb'); gzip.GzipFile(fileobj=f).read(1); f.close()" 2>/dev/null; then
        # Check if it's a valid tar archive
        if tar -tzf "$file" >/dev/null 2>&1; then
            return 0
        fi
    fi
    
    return 1
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
# Step 0: Download and extract sourceversion1.7z (Independent task)
# ============================================
log_info "Step 0: Setting up source packages..."

# Setup source directory paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="${SCRIPT_DIR}/depedencies/source"
DEPENDENCIES_DIR="${SCRIPT_DIR}/depedencies"
SOURCE_7Z="${DEPENDENCIES_DIR}/sourceversion1.7z"
GITHUB_REPO="${GITHUB_REPO:-RiteshF7/droidrundepedency}"
GITHUB_RELEASE_TAG="${GITHUB_RELEASE_TAG:-hellow}"

# Ensure directories exist
mkdir -p "$SOURCE_DIR" "$DEPENDENCIES_DIR"

# Install p7zip if not already installed (only if network is available)
if ! command_exists 7z && ! command_exists 7za; then
    log_info "Installing p7zip (required for extracting archives)..."
    if pkg install p7zip -y 2>/dev/null; then
        log_success "p7zip installed"
    else
        log_warning "Failed to install p7zip (network may be unavailable)"
        log_warning "Please install manually: pkg install p7zip"
        log_warning "Or ensure 7z/7za is available in PATH"
    fi
fi

# Check if source directory already has files
SOURCE_COUNT=$(find "$SOURCE_DIR" -maxdepth 1 -type f \( -name "*.tar.gz" -o -name "*.zip" \) ! -name "*sources.tar.gz" ! -name "*home_sources.tar.gz" ! -name "*test_*" 2>/dev/null | wc -l)

if [ "$SOURCE_COUNT" -eq 0 ]; then
    log_warning "No source packages found in $SOURCE_DIR"
    
    # Check if sourceversion1.7z exists locally
    if [ -f "$SOURCE_7Z" ]; then
        log_info "Found sourceversion1.7z locally, extracting..."
    else
        log_info "sourceversion1.7z not found locally, downloading from GitHub releases..."
        
        # Check for download tools
        if ! command_exists curl && ! command_exists wget; then
            log_error "Neither curl nor wget is available. Cannot download sourceversion1.7z"
            log_error "Please install curl or wget: pkg install curl"
            exit 1
        fi
        
        # Use release tag (default: hellow)
        RELEASE_TAG="${GITHUB_RELEASE_TAG:-hellow}"
        log_info "Using release tag: $RELEASE_TAG"
        
        # Download sourceversion1.7z from GitHub releases
        # URL format: https://github.com/OWNER/REPO/releases/download/TAG/FILENAME
        DOWNLOAD_URL="https://github.com/${GITHUB_REPO}/releases/download/${RELEASE_TAG}/sourceversion1.7z"
        log_info "Downloading from: $DOWNLOAD_URL"
        log_info "Saving to: $SOURCE_7Z"
        
        if command_exists curl; then
            HTTP_CODE=$(curl -sL -w "%{http_code}" -o "$SOURCE_7Z" "$DOWNLOAD_URL" || echo "000")
            if [ "$HTTP_CODE" = "200" ]; then
                SIZE=$(du -h "$SOURCE_7Z" | cut -f1)
                log_success "Downloaded sourceversion1.7z ($SIZE)"
            else
                rm -f "$SOURCE_7Z"
                if [ "$HTTP_CODE" = "404" ]; then
                    log_error "Release not found (404): $DOWNLOAD_URL"
                    log_error "The GitHub release '$RELEASE_TAG' does not exist or file not found."
                    log_info "To fix this:"
                    log_info "1. Check release exists at: https://github.com/${GITHUB_REPO}/releases"
                    log_info "2. Verify tag name matches: $RELEASE_TAG"
                    log_info "3. Ensure sourceversion1.7z is attached to the release"
                    log_info ""
                    log_info "Alternatively, place sourceversion1.7z in: $DEPENDENCIES_DIR/"
                else
                    log_error "Failed to download sourceversion1.7z (HTTP $HTTP_CODE)"
                    log_error "URL: $DOWNLOAD_URL"
                fi
                exit 1
            fi
        elif command_exists wget; then
            if wget --progress=bar:force -O "$SOURCE_7Z" "$DOWNLOAD_URL" 2>&1; then
                SIZE=$(du -h "$SOURCE_7Z" | cut -f1)
                log_success "Downloaded sourceversion1.7z ($SIZE)"
            else
                rm -f "$SOURCE_7Z"
                log_error "Failed to download sourceversion1.7z"
                log_error "The GitHub release '$RELEASE_TAG' may not exist or file not found."
                log_info "Check release at: https://github.com/${GITHUB_REPO}/releases"
                log_info "Or place sourceversion1.7z in: $DEPENDENCIES_DIR/"
                exit 1
            fi
        fi
    fi
    
    # Extract sourceversion1.7z
    if [ -f "$SOURCE_7Z" ]; then
        log_info "Extracting sourceversion1.7z to $SOURCE_DIR..."
        
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
                log_error "Failed to extract sourceversion1.7z with 7z"
                exit 1
            fi
        elif command_exists 7za; then
            if ! 7za x "$SOURCE_7Z" -o"$TEMP_EXTRACT_DIR" -y >/dev/null 2>&1; then
                log_error "Failed to extract sourceversion1.7z with 7za"
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
            log_error "Please check if sourceversion1.7z contains valid source packages"
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

# Hardcoded source file names (standardized names)
# All source files are renamed to standardized names for easy recognition
AIOHTTP_SOURCE_FILE="${SOURCE_DIR}/aiohttp.tar.gz"
APKUTILS2_SOURCE_FILE="${SOURCE_DIR}/apkutils2.tar.gz"
BUILD_SOURCE_FILE="${SOURCE_DIR}/build.tar.gz"
CFFI_SOURCE_FILE="${SOURCE_DIR}/cffi.tar.gz"
CRYPTOGRAPHY_SOURCE_FILE="${SOURCE_DIR}/cryptography.tar.gz"
GREENLET_SOURCE_FILE="${SOURCE_DIR}/greenlet.tar.gz"
GRPCIO_SOURCE_FILE="${SOURCE_DIR}/grpcio.tar.gz"
HF_XET_SOURCE_FILE="${SOURCE_DIR}/hf-xet.tar.gz"
JITER_SOURCE_FILE="${SOURCE_DIR}/jiter.tar.gz"
MARKUPSAFE_SOURCE_FILE="${SOURCE_DIR}/markupsafe.tar.gz"
NUMPY_SOURCE_FILE="${SOURCE_DIR}/numpy.tar.gz"
ORJSON_SOURCE_FILE="${SOURCE_DIR}/orjson.tar.gz"
PANDAS_SOURCE_FILE="${SOURCE_DIR}/pandas.tar.gz"
PILLOW_SOURCE_FILE="${SOURCE_DIR}/pillow.tar.gz"
PSUTIL_SOURCE_FILE="${SOURCE_DIR}/psutil.tar.gz"
PYARROW_SOURCE_FILE="${SOURCE_DIR}/pyarrow.tar.gz"
PYDANTIC_CORE_SOURCE_FILE="${SOURCE_DIR}/pydantic-core.tar.gz"
REGEX_SOURCE_FILE="${SOURCE_DIR}/regex.tar.gz"
SAFETENSORS_SOURCE_FILE="${SOURCE_DIR}/safetensors.tar.gz"
SCIKIT_LEARN_SOURCE_FILE="${SOURCE_DIR}/scikit-learn.tar.gz"
SCIPY_SOURCE_FILE="${SOURCE_DIR}/scipy.tar.gz"
SQLEAN_PY_SOURCE_FILE="${SOURCE_DIR}/sqlean-py.tar.gz"
TIKTOKEN_SOURCE_FILE="${SOURCE_DIR}/tiktoken.tar.gz"
TOKENIZERS_SOURCE_FILE="${SOURCE_DIR}/tokenizers.tar.gz"

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

if [ -f "$NUMPY_SOURCE_FILE" ]; then
    if validate_tar_gz "$NUMPY_SOURCE_FILE"; then
        log_info "Using local source: numpy.tar.gz"
        pip wheel "$NUMPY_SOURCE_FILE" --no-deps --wheel-dir .
    else
        log_error "numpy.tar.gz is corrupted or invalid (not a valid gzip/tar file)"
        log_warning "Removing corrupted file and downloading fresh copy..."
        rm -f "$NUMPY_SOURCE_FILE"
        pip download numpy --dest . --no-cache-dir
        pip wheel numpy --no-deps --wheel-dir .
    fi
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
if [ -f "$SCIPY_SOURCE_FILE" ]; then
    log_info "Using local source: scipy.tar.gz"
    pip wheel "$SCIPY_SOURCE_FILE" --no-deps --wheel-dir .
else
    log_warning "scipy source not found locally, downloading..."
    pip download "scipy>=1.8.0,<1.17.0" --dest . --no-cache-dir
    pip wheel scipy --no-deps --wheel-dir .
fi
pip install --find-links . --no-index scipy*.whl
log_success "scipy installed"

# Build pandas (with meson.build fix)
log_info "Building pandas (applying meson.build fix)..."
if [ -f "$PANDAS_SOURCE_FILE" ]; then
    log_info "Using local source: pandas.tar.gz"
    # Fix meson.build version detection issue
    WORK_DIR=$(mktemp -d)
    cp "$PANDAS_SOURCE_FILE" "$WORK_DIR/"
    cd "$WORK_DIR"
    tar -xzf pandas.tar.gz
    PANDAS_DIR=$(ls -d pandas-* | head -1)
    if [ -f "$PANDAS_DIR/meson.build" ]; then
        PANDAS_VERSION=$(echo "$PANDAS_DIR" | sed 's/pandas-//')
        sed -i "s/version: run_command.*/version: '$PANDAS_VERSION',/" "$PANDAS_DIR/meson.build"
        tar -czf pandas.tar.gz "$PANDAS_DIR/"
    fi
    pip wheel pandas.tar.gz --no-deps --wheel-dir "$WHEELS_DIR"
    cd "$WHEELS_DIR"
    rm -rf "$WORK_DIR"
    pip install --find-links . --no-index pandas*.whl
    log_success "pandas installed"
else
    log_warning "pandas source not found locally, downloading..."
    pip download "pandas<2.3.0" --dest . --no-cache-dir
    PANDAS_SOURCE=$(ls pandas-*.tar.gz | head -1)
    if [ -n "$PANDAS_SOURCE" ]; then
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
fi

# Build scikit-learn (use pre-fixed tarball)
log_info "Building scikit-learn..."
if [ -f "$SCIKIT_LEARN_SOURCE_FILE" ]; then
    log_info "Using local source: scikit-learn.tar.gz"
    pip wheel "$SCIKIT_LEARN_SOURCE_FILE" --no-deps --no-build-isolation --wheel-dir .
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

if [ -f "$JITER_SOURCE_FILE" ]; then
    log_info "Using local source: jiter.tar.gz"
    pip wheel "$JITER_SOURCE_FILE" --no-deps --wheel-dir .
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
if [ -f "$PYARROW_SOURCE_FILE" ]; then
    log_info "Using local source: pyarrow.tar.gz"
    export ARROW_HOME=$PREFIX
    pip wheel "$PYARROW_SOURCE_FILE" --no-deps --wheel-dir .
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
if [ -f "$PSUTIL_SOURCE_FILE" ]; then
    log_info "Using local source: psutil.tar.gz"
    pip wheel "$PSUTIL_SOURCE_FILE" --no-deps --wheel-dir .
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

if [ -f "$GRPCIO_SOURCE_FILE" ]; then
    log_info "Using local source: grpcio.tar.gz"
    # Build wheel from local source
    pip wheel "$GRPCIO_SOURCE_FILE" --no-deps --no-build-isolation --wheel-dir .
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

if [ -f "$PILLOW_SOURCE_FILE" ]; then
    log_info "Using local source: pillow.tar.gz"
    pip wheel "$PILLOW_SOURCE_FILE" --no-deps --wheel-dir .
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
    
    # Build tokenizers
    if [ -f "$TOKENIZERS_SOURCE_FILE" ]; then
        log_info "Using local source for tokenizers: tokenizers.tar.gz"
        pip wheel "$TOKENIZERS_SOURCE_FILE" --no-deps --wheel-dir . 2>/dev/null && log_success "tokenizers built" || log_warning "Skipping tokenizers (build failed)"
    else
        log_warning "tokenizers source not found locally, downloading..."
        pip download tokenizers --dest . --no-cache-dir
        pip wheel tokenizers --no-deps --wheel-dir . 2>/dev/null && log_success "tokenizers built" || log_warning "Skipping tokenizers (may have wheel or build failed)"
    fi
    
    # Build safetensors
    if [ -f "$SAFETENSORS_SOURCE_FILE" ]; then
        log_info "Using local source for safetensors: safetensors.tar.gz"
        pip wheel "$SAFETENSORS_SOURCE_FILE" --no-deps --wheel-dir . 2>/dev/null && log_success "safetensors built" || log_warning "Skipping safetensors (build failed)"
    else
        log_warning "safetensors source not found locally, downloading..."
        pip download safetensors --dest . --no-cache-dir
        pip wheel safetensors --no-deps --wheel-dir . 2>/dev/null && log_success "safetensors built" || log_warning "Skipping safetensors (may have wheel or build failed)"
    fi
    
    # Build cryptography
    if [ -f "$CRYPTOGRAPHY_SOURCE_FILE" ]; then
        log_info "Using local source for cryptography: cryptography.tar.gz"
        pip wheel "$CRYPTOGRAPHY_SOURCE_FILE" --no-deps --wheel-dir . 2>/dev/null && log_success "cryptography built" || log_warning "Skipping cryptography (build failed)"
    else
        log_warning "cryptography source not found locally, downloading..."
        pip download cryptography --dest . --no-cache-dir
        pip wheel cryptography --no-deps --wheel-dir . 2>/dev/null && log_success "cryptography built" || log_warning "Skipping cryptography (may have wheel or build failed)"
    fi
    
    # Build pydantic-core
    if [ -f "$PYDANTIC_CORE_SOURCE_FILE" ]; then
        log_info "Using local source for pydantic-core: pydantic-core.tar.gz"
        pip wheel "$PYDANTIC_CORE_SOURCE_FILE" --no-deps --wheel-dir . 2>/dev/null && log_success "pydantic-core built" || log_warning "Skipping pydantic-core (build failed)"
    else
        log_warning "pydantic-core source not found locally, downloading..."
        pip download pydantic-core --dest . --no-cache-dir
        pip wheel pydantic-core --no-deps --wheel-dir . 2>/dev/null && log_success "pydantic-core built" || log_warning "Skipping pydantic-core (may have wheel or build failed)"
    fi
    
    # Build orjson
    if [ -f "$ORJSON_SOURCE_FILE" ]; then
        log_info "Using local source for orjson: orjson.tar.gz"
        pip wheel "$ORJSON_SOURCE_FILE" --no-deps --wheel-dir . 2>/dev/null && log_success "orjson built" || log_warning "Skipping orjson (build failed)"
    else
        log_warning "orjson source not found locally, downloading..."
        pip download orjson --dest . --no-cache-dir
        pip wheel orjson --no-deps --wheel-dir . 2>/dev/null && log_success "orjson built" || log_warning "Skipping orjson (may have wheel or build failed)"
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
