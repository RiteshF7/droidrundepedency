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

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if package is installed
pkg_installed() {
    pkg list-installed 2>/dev/null | grep -q "^$1 " || return 1
}

# Check if Python package is already installed and satisfies version requirement
python_pkg_installed() {
    local pkg_name=$1
    local version_spec=$2
    
    # Use pip show to check if package is installed
    if ! pip show "$pkg_name" &>/dev/null; then
        return 1
    fi
    
    # If version spec is provided and contains version requirements, check if installed version satisfies it
    if [ -n "$version_spec" ] && [[ "$version_spec" != "$pkg_name" ]] && [[ "$version_spec" =~ [<>=] ]]; then
        # Use pip install with --dry-run to check if requirement is satisfied
        # This uses pip's own requirement resolver which is most reliable
        local pip_output
        pip_output=$(pip install --dry-run --no-deps "$version_spec" 2>&1)
        
        # If pip says "Requirement already satisfied", the version requirement is met
        if echo "$pip_output" | grep -q "Requirement already satisfied"; then
            return 0
        fi
        
        # If pip would install/upgrade, the requirement is not satisfied
        if echo "$pip_output" | grep -qE "(Would install|Would upgrade)"; then
            return 1
        fi
        
        # If output is unclear, assume requirement is satisfied (better to skip than rebuild unnecessarily)
        # This handles edge cases where pip output format might differ
        return 0
    fi
    
    # If no version requirement or just package name, package is installed
    return 0
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

# Helper function to download and fix source for packages that need fixes
# Returns path to fixed source file
download_and_fix_source() {
    local pkg_name=$1
    local version_spec=$2
    local fix_type=$3  # "pandas" or "scikit-learn"
    
    log_info "=== download_and_fix_source called ==="
    log_info "Parameters: pkg_name=$pkg_name, version_spec=$version_spec, fix_type=$fix_type"
    log_info "Downloading $pkg_name source ($version_spec)..."
    WORK_DIR=$(mktemp -d)
    log_info "Working directory: $WORK_DIR"
    cd "$WORK_DIR"
    
    # Download source using pip (with verbose output)
    log_info "Running: pip download \"$version_spec\" --dest . --no-cache-dir --no-binary :all:"
    local download_output=$(pip download "$version_spec" --dest . --no-cache-dir --no-binary :all: 2>&1)
    local download_exit_code=$?
    
    if [ $download_exit_code -ne 0 ]; then
        log_error "Failed to download $pkg_name source (exit code: $download_exit_code)"
        log_error "pip download output:"
        echo "$download_output" | while read line; do
            log_error "  $line"
        done
        log_info "Contents of working directory:"
        ls -la "$WORK_DIR" | while read line; do
            log_info "  $line"
        done || true
        rm -rf "$WORK_DIR"
        return 1
    fi
    
    log_info "pip download completed successfully"
    log_info "Contents of working directory after download:"
    ls -la "$WORK_DIR" | while read line; do
        log_info "  $line"
    done || true
    
    # Find downloaded file
    log_info "Searching for source file: ${pkg_name}-*.tar.gz"
    local source_file=$(ls ${pkg_name}-*.tar.gz 2>/dev/null | head -1)
    if [ -z "$source_file" ]; then
        log_error "Downloaded source file not found for $pkg_name"
        log_error "Expected pattern: ${pkg_name}-*.tar.gz"
        log_error "Files in directory:"
        ls -la "$WORK_DIR" | while read line; do
            log_error "  $line"
        done || true
        rm -rf "$WORK_DIR"
        return 1
    fi
    
    log_success "Found source file: $source_file"
    
    log_info "Extracting $pkg_name source..."
    if ! tar -xzf "$source_file" 2>&1 | while read line; do log_info "  $line"; done; then
        log_error "Failed to extract $source_file"
        rm -rf "$WORK_DIR"
        return 1
    fi
    
    local pkg_dir=$(ls -d ${pkg_name}-* 2>/dev/null | head -1)
    if [ -z "$pkg_dir" ]; then
        log_error "Extracted package directory not found for $pkg_name"
        log_error "Expected pattern: ${pkg_name}-*"
        log_error "Contents after extraction:"
        ls -la "$WORK_DIR" | while read line; do
            log_error "  $line"
        done || true
        rm -rf "$WORK_DIR"
        return 1
    fi
    
    log_success "Extracted to directory: $pkg_dir"
    
    if [ "$fix_type" = "pandas" ]; then
        # Fix pandas meson.build
        log_info "Checking for meson.build in $pkg_dir..."
        if [ -f "$pkg_dir/meson.build" ]; then
            local pkg_version=$(echo "$pkg_dir" | sed "s/${pkg_name}-//")
            log_info "Fixing meson.build: replacing version detection with '$pkg_version'"
            if sed -i "s/version: run_command.*/version: '$pkg_version',/" "$pkg_dir/meson.build" 2>&1; then
                log_success "meson.build fixed"
            else
                log_error "Failed to fix meson.build"
                rm -rf "$WORK_DIR"
                return 1
            fi
        else
            log_warning "meson.build not found in $pkg_dir (may not be needed)"
        fi
    elif [ "$fix_type" = "scikit-learn" ]; then
        # Fix scikit-learn version.py and meson.build
        if [ -f "$pkg_dir/sklearn/_build_utils/version.py" ]; then
            if ! head -1 "$pkg_dir/sklearn/_build_utils/version.py" | grep -q "^#!/"; then
                log_info "Fixing sklearn/_build_utils/version.py: adding shebang"
                sed -i '1i#!/usr/bin/env python3' "$pkg_dir/sklearn/_build_utils/version.py"
                log_success "version.py fixed"
            fi
        fi
        if [ -f "$pkg_dir/meson.build" ]; then
            local pkg_version=$(echo "$pkg_dir" | sed "s/${pkg_name}-//")
            log_info "Fixing meson.build: replacing version extraction with '$pkg_version'"
            sed -i "s/version: run_command.*/version: '$pkg_version',/" "$pkg_dir/meson.build" 2>/dev/null || \
            sed -i "s/version:.*/version: '$pkg_version',/" "$pkg_dir/meson.build"
            log_success "meson.build fixed"
        fi
    fi
    
    # Repackage fixed source
    log_info "Repackaging fixed source..."
    log_info "Creating archive: $source_file from $pkg_dir/"
    if ! tar -czf "$source_file" "$pkg_dir/" 2>&1 | while read line; do log_info "  $line"; done; then
        log_error "Failed to repackage $pkg_name source"
        rm -rf "$WORK_DIR"
        return 1
    fi
    
    if [ ! -f "$source_file" ]; then
        log_error "Repackaged file not created: $source_file"
        rm -rf "$WORK_DIR"
        return 1
    fi
    
    log_success "Repackaged source file created: $WORK_DIR/$source_file"
    echo "$WORK_DIR/$source_file"
}

# Generic function to build and install a package
# Usage: build_package <pkg_name> <version_spec> [options]
# Options: --no-build-isolation, --fix-source=<type>, --pre-check, --env-var=<key=value>, --post-install=<cmd>
build_package() {
    local pkg_name=$1
    local version_spec=$2
    shift 2
    local build_opts=""
    local fix_type=""
    local pre_check=false
    local env_vars=()
    local post_install=""
    local wheel_pattern="${pkg_name}*.whl"
    
    # Parse options
    while [[ $# -gt 0 ]]; do
        case $1 in
            --no-build-isolation)
                build_opts="--no-build-isolation"
                shift
                ;;
            --fix-source=*)
                fix_type="${1#*=}"
                shift
                ;;
            --pre-check)
                pre_check=true
                shift
                ;;
            --env-var=*)
                env_vars+=("${1#*=}")
                shift
                ;;
            --post-install=*)
                post_install="${1#*=}"
                shift
                ;;
            --wheel-pattern=*)
                wheel_pattern="${1#*=}"
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                return 1
                ;;
        esac
    done
    
    # Check if package is already installed and satisfies version requirement
    if python_pkg_installed "$pkg_name" "$version_spec"; then
        log_success "$pkg_name is already installed and satisfies version requirement ($version_spec), skipping build"
        return 0
    else
        log_info "$pkg_name not installed or version requirement ($version_spec) not satisfied, will build"
    fi
    
    log_info "Building $pkg_name..."
    cd "$WHEELS_DIR"
    
    # Set environment variables if specified
    for env_var in "${env_vars[@]}"; do
        export "$env_var"
    done
    
    # Pre-check for pre-built wheels (e.g., pyarrow)
    if [ "$pre_check" = true ]; then
        log_info "Checking for pre-built $pkg_name wheel..."
        pip download "$version_spec" --dest . --no-cache-dir 2>&1 | grep -v "Looking in indexes" | grep -v "Collecting" | while read line; do log_info "  $line"; done || true
        if pip install --find-links . --no-index ${wheel_pattern} 2>/dev/null; then
            log_success "$pkg_name installed (pre-built wheel)"
            return 0
        fi
        log_info "No pre-built wheel found, building from source..."
    fi
    
    # Download and fix source if needed
    local source_arg="$version_spec"
    local temp_dir=""
    if [ -n "$fix_type" ]; then
        # Use a temp file to capture the return value while letting logs flow through
        local result_file=$(mktemp)
        # Run function, capture stdout to file, but let stderr (logs) flow through
        if download_and_fix_source "$pkg_name" "$version_spec" "$fix_type" > "$result_file" 2>&1; then
            local fixed_source=$(cat "$result_file" 2>/dev/null | tail -1)
            rm -f "$result_file"
            if [ -n "$fixed_source" ] && [ -f "$fixed_source" ]; then
                source_arg="$fixed_source"
                temp_dir="$(dirname "$fixed_source")"
            else
                log_error "Failed to download and fix $pkg_name source - no valid file returned"
                return 1
            fi
        else
            log_error "Failed to download and fix $pkg_name source"
            rm -f "$result_file"
            return 1
        fi
    fi
    
    # Build wheel
    log_info "Building $pkg_name wheel (pip will download source automatically)..."
    if pip wheel "$source_arg" --no-deps $build_opts --wheel-dir . 2>&1 | grep -v "Looking in indexes" | grep -v "Collecting" | while read line; do log_info "  $line"; done; then
        log_success "$pkg_name wheel built successfully"
    else
        log_error "Failed to build $pkg_name wheel"
        [ -n "$temp_dir" ] && rm -rf "$temp_dir"
        return 1
    fi
    
    # Cleanup temp directory if used
    [ -n "$temp_dir" ] && rm -rf "$temp_dir"
    
    # Install wheel
    log_info "Installing $pkg_name wheel..."
    pip install --find-links . --no-index ${wheel_pattern}
    
    # Post-install commands
    if [ -n "$post_install" ]; then
        eval "$post_install"
    fi
    
    log_success "$pkg_name installed"
    return 0
}

# Function to fix grpcio wheel after building
fix_grpcio_wheel() {
    local wheel_file=$(ls grpcio-*.whl | head -1)
    if [ -z "$wheel_file" ]; then
        log_error "grpcio wheel not found"
        return 1
    fi
    
    log_info "Fixing grpcio wheel: $wheel_file"
    
    # Extract wheel
    unzip -q "$wheel_file" -d grpcio_extract
    
    # Find and patch the .so file
    local so_file=$(find grpcio_extract -name "cygrpc*.so" | head -1)
    if [ -z "$so_file" ]; then
        log_error "cygrpc*.so not found in wheel"
        rm -rf grpcio_extract
        return 1
    fi
    
    # Add abseil libraries to NEEDED list and set RPATH
    patchelf --add-needed libabsl_flags_internal.so "$so_file"
    patchelf --add-needed libabsl_flags.so "$so_file"
    patchelf --add-needed libabsl_flags_commandlineflag.so "$so_file"
    patchelf --add-needed libabsl_flags_reflection.so "$so_file"
    patchelf --set-rpath "$PREFIX/lib" "$so_file"
    
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
PYEOF
    cd ..
    
    # Replace original wheel with fixed one
    rm -rf grpcio_extract
    rm "$wheel_file"
    mv grpcio-fixed.whl "$wheel_file"
    log_success "grpcio wheel fixed"
}

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}droidrun Installation Script${NC}"
echo -e "${BLUE}========================================${NC}"
echo

# ============================================
# Setup PREFIX and check Termux environment
# ============================================
if [ -z "${PREFIX:-}" ]; then
    export PREFIX="/data/data/${PACKAGE_NAME}/files/usr"
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

export PREFIX=${PREFIX:-/data/data/${PACKAGE_NAME}/files/usr}

# Set build parallelization based on available system memory
get_total_mem_mb() {
    if [ -r /proc/meminfo ]; then
        awk '/MemTotal/ { printf "%.0f", $2/1024 }' /proc/meminfo
    else
        # Fallback: unknown memory
        echo 0
    fi
}

MEM_MB=$(get_total_mem_mb)

if [ "$MEM_MB" -ge 3500 ]; then
    # 3.5 GB+ RAM: up to 4 jobs
    JOBS=4
elif [ "$MEM_MB" -ge 2000 ]; then
    # 2-3.5 GB RAM: up to 2 jobs
    JOBS=2
else
    # <2GB RAM: single job to avoid OOM
    JOBS=1
fi

export NINJAFLAGS="-j$JOBS"
export MAKEFLAGS="-j$JOBS"
export MAX_JOBS=$JOBS

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

# Check and install build tools only if needed
build_tools_needed=false
for tool in "wheel" "setuptools" "Cython" "meson-python" "maturin"; do
    if ! python_pkg_installed "$tool" "$tool"; then
        build_tools_needed=true
        break
    fi
done

if [ "$build_tools_needed" = true ]; then
    pip install --upgrade wheel setuptools --quiet
    pip install Cython "meson-python<0.19.0,>=0.16.0" "maturin<2,>=1.9.4" --quiet
    log_success "Phase 1 complete: Build tools installed"
else
    log_success "Phase 1 complete: Build tools already installed"
fi

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
# Install dependencies first if needed
if ! python_pkg_installed "joblib" "joblib>=1.3.0" || ! python_pkg_installed "threadpoolctl" "threadpoolctl>=3.2.0"; then
    log_info "Installing scikit-learn dependencies..."
    pip install "joblib>=1.3.0" "threadpoolctl>=3.2.0" --quiet
else
    log_info "scikit-learn dependencies already installed"
fi

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
fi

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

# List of optional packages
optional_packages=("tokenizers" "safetensors" "cryptography" "pydantic-core" "orjson")
missing_packages=()

# Check which packages are missing
for pkg in "${optional_packages[@]}"; do
    if ! python_pkg_installed "$pkg" "$pkg"; then
        missing_packages+=("$pkg")
    fi
done

if [ ${#missing_packages[@]} -eq 0 ]; then
    log_success "Phase 6 complete: All optional packages already installed"
else
    log_info "Installing missing optional packages: ${missing_packages[*]}"
    # These usually have pre-built wheels, try install first
    if pip install "${missing_packages[@]}" --find-links "$WHEELS_DIR" 2>/dev/null; then
        log_success "Phase 6 complete: Optional packages installed (pre-built wheels)"
    else
        log_info "Some packages need building from source..."
        
        built_packages=()
        
        # Build each missing package (continue on failure)
        for pkg in "${missing_packages[@]}"; do
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
