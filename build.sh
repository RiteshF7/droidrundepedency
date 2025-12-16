#!/usr/bin/env bash
# DroidRun WHL Builder for Android/Termux
# Main build script to generate wheel files for droidrun dependencies
# Includes all prerequisites and fixes from DEPENDENCIES.md

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="${SCRIPT_DIR}/depedencies/source"
WHEELS_DIR="${WHEELS_DIR:-${HOME}/wheels}"

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
echo -e "${BLUE}DroidRun WHL Builder for Android/Termux${NC}"
echo -e "${BLUE}========================================${NC}"
echo

# ============================================
# 1. Setup PREFIX and check Termux environment
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
# 2. Check and install system dependencies
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
    
    # Auto-install if running non-interactively (no TTY) or CI mode
    if [ ! -t 0 ] || [ "${CI:-}" = "true" ] || [ "${AUTO_INSTALL:-}" = "true" ]; then
        log_info "Non-interactive mode: Auto-installing missing packages..."
        pkg update -y
        pkg install -y "${MISSING_PKGS[@]}"
        log_success "System packages installed"
    else
        echo
        read -p "Install missing packages? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log_info "Installing system packages..."
            pkg update -y
            pkg install -y "${MISSING_PKGS[@]}"
            log_success "System packages installed"
        else
            log_error "Cannot proceed without required system packages"
            exit 1
        fi
    fi
else
    log_success "All system dependencies are installed"
fi

# ============================================
# 3. Setup build environment variables
# ============================================
log_info "Setting up build environment..."

# Set PREFIX (already set above)
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
mkdir -p "$WHEELS_DIR"

# Package-specific environment variables (will be set per-package in build_wheels.py)
# These are documented here for reference:
# - pyarrow: ARROW_HOME=$PREFIX
# - pillow: PKG_CONFIG_PATH, LDFLAGS, CPPFLAGS
# - grpcio: GRPC_PYTHON_BUILD_SYSTEM_* variables

log_success "Build environment configured"

# ============================================
# 4. Create gfortran symlink for scipy compatibility
# ============================================
if [ ! -f "$PREFIX/bin/gfortran" ]; then
    log_info "Creating gfortran symlink (required for scipy/scikit-learn)..."
    ln -sf "$PREFIX/bin/flang" "$PREFIX/bin/gfortran"
    log_success "gfortran symlink created"
else
    log_success "gfortran symlink already exists"
fi

# ============================================
# 5. Check Python and pip
# ============================================
if ! command_exists python3; then
    log_error "python3 is not installed"
    log_error "Install with: pkg install python"
    exit 1
fi

if ! command_exists pip; then
    log_error "pip is not installed"
    log_error "Install with: pkg install python-pip"
    exit 1
fi

PYTHON_VERSION=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>/dev/null || echo "unknown")
log_success "Python $PYTHON_VERSION found"

# ============================================
# 6. Install/upgrade build tools
# ============================================
log_info "Installing/upgrading build tools..."

pip install --upgrade pip wheel setuptools --quiet

# Install build tools required for wheel building
BUILD_TOOLS=(
    "Cython"
    "meson-python<0.19.0,>=0.16.0"
    "maturin<2,>=1.9.4"
)

for tool in "${BUILD_TOOLS[@]}"; do
    log_info "Installing $tool..."
    pip install "$tool" --quiet || {
        log_warning "Failed to install $tool, continuing..."
    }
done

log_success "Build tools installed"

# ============================================
# 6b. Install Python package dependencies (prerequisites)
# ============================================
log_info "Installing Python package prerequisites..."

# Install scikit-learn dependencies (required before building scikit-learn)
# These are runtime dependencies that scikit-learn needs during build
SCIKIT_LEARN_DEPS=(
    "joblib>=1.3.0"
    "threadpoolctl>=3.2.0"
)

for dep in "${SCIKIT_LEARN_DEPS[@]}"; do
    log_info "Installing $dep (required for scikit-learn)..."
    pip install "$dep" --quiet || {
        log_warning "Failed to install $dep, continuing..."
    }
done

log_success "Python package prerequisites installed"

# ============================================
# 7. Download and extract source.7z if needed
# ============================================
DEPENDENCIES_DIR="${SCRIPT_DIR}/depedencies"
SOURCE_7Z="${DEPENDENCIES_DIR}/source.7z"
GITHUB_REPO="${GITHUB_REPO:-RiteshF7/droidrundepedency}"
GITHUB_RELEASE_TAG="${GITHUB_RELEASE_TAG:-latest}"

# Create source directory if it doesn't exist
mkdir -p "$SOURCE_DIR"

# Check if source packages already exist
SOURCE_COUNT=$(find "$SOURCE_DIR" -maxdepth 1 -type f \( -name "*.tar.gz" -o -name "*.zip" \) ! -name "*sources.tar.gz" ! -name "*home_sources.tar.gz" ! -name "*test_*" 2>/dev/null | wc -l)

if [ "$SOURCE_COUNT" -eq 0 ]; then
    log_warning "No source packages found in $SOURCE_DIR"
    
    # Check if source.7z exists locally
    if [ -f "$SOURCE_7Z" ]; then
        log_info "Found source.7z locally ($(du -h "$SOURCE_7Z" | cut -f1)), extracting..."
    else
        log_info "source.7z not found locally, downloading from GitHub releases..."
        
        # Get latest release tag if needed
        if [ "$GITHUB_RELEASE_TAG" = "latest" ]; then
            log_info "Fetching latest release tag from $GITHUB_REPO..."
            if command_exists curl; then
                RELEASE_TAG=$(curl -sL "https://api.github.com/repos/${GITHUB_REPO}/releases/latest" | grep -o '"tag_name": "[^"]*' | cut -d'"' -f4)
            elif command_exists wget; then
                RELEASE_TAG=$(wget -qO- "https://api.github.com/repos/${GITHUB_REPO}/releases/latest" | grep -o '"tag_name": "[^"]*' | cut -d'"' -f4)
            else
                log_error "Neither curl nor wget is available. Cannot download source.7z"
                exit 1
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
        
        # Create depedencies directory if it doesn't exist
        mkdir -p "$DEPENDENCIES_DIR"
        
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
    
    # Extract source.7z to the correct directory
    if [ -f "$SOURCE_7Z" ]; then
        log_info "Extracting source.7z to $SOURCE_DIR..."
        
        # Ensure source directory exists and is empty (except for build_wheels.py)
        mkdir -p "$SOURCE_DIR"
        
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
        # Handle case where files are in a subdirectory
        EXTRACTED_FILES=$(find "$TEMP_EXTRACT_DIR" -type f \( -name "*.tar.gz" -o -name "*.zip" \) ! -name "*sources.tar.gz" ! -name "*home_sources.tar.gz" ! -name "*test_*" 2>/dev/null)
        
        if [ -z "$EXTRACTED_FILES" ]; then
            # Check if files are in a subdirectory
            SUBDIR=$(find "$TEMP_EXTRACT_DIR" -mindepth 1 -maxdepth 1 -type d | head -1)
            if [ -n "$SUBDIR" ]; then
                log_info "Files extracted to subdirectory, moving to $SOURCE_DIR..."
                # Move all files from subdirectory to SOURCE_DIR
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
    log_success "Found $SOURCE_COUNT source packages in $SOURCE_DIR (already extracted)"
fi

# ============================================
# 8. Verify build script exists
# ============================================
BUILD_SCRIPT="${SOURCE_DIR}/build_wheels.py"
if [ ! -f "$BUILD_SCRIPT" ]; then
    log_error "build_wheels.py not found in $SOURCE_DIR"
    exit 1
fi

# ============================================
# 8. Verify build script exists
# ============================================
BUILD_SCRIPT="${SOURCE_DIR}/build_wheels.py"
if [ ! -f "$BUILD_SCRIPT" ]; then
    log_error "build_wheels.py not found in $SOURCE_DIR"
    exit 1
fi

# ============================================
# 9. Display configuration summary
# ============================================
echo
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Build Configuration${NC}"
echo -e "${BLUE}========================================${NC}"
echo "Source directory: $SOURCE_DIR"
echo "Wheels directory: $WHEELS_DIR"
echo "Python version: $PYTHON_VERSION"
echo "PREFIX: $PREFIX"
echo "Parallelism: 2 jobs (NINJAFLAGS=$NINJAFLAGS)"
echo "Source packages: $SOURCE_COUNT"
echo -e "${BLUE}========================================${NC}"
echo

# ============================================
# 10. Build wheels from all sources (with dependency resolution)
# ============================================
log_info "Starting wheel build process..."
log_info "Building wheels from all sources in dependency order..."
echo

# List all source packages that will be built
log_info "Source packages found:"
find "$SOURCE_DIR" -maxdepth 1 -type f \( -name "*.tar.gz" -o -name "*.zip" \) ! -name "*sources.tar.gz" ! -name "*home_sources.tar.gz" ! -name "*test_*" -exec basename {} \; 2>/dev/null | sort | while read -r pkg; do
    echo "  - $pkg"
done
echo

# Change to source directory
cd "$SOURCE_DIR"

# Run the build script which handles:
# - Scanning all source packages in the source directory
# - Building dependency graph from known dependencies
# - Topologically sorting packages to determine build order
# - Building each package in correct order (dependencies first)
# - Applying Termux-specific fixes (pandas, scikit-learn, grpcio, etc.)
# - Installing built wheels so dependent packages can use them
log_info "Running build_wheels.py..."
log_info "This will:"
log_info "  1. Scan all source packages"
log_info "  2. Resolve dependencies (e.g., numpy → scipy, pandas, scikit-learn)"
log_info "  3. Build packages in dependency order"
log_info "  4. Apply Termux-specific fixes automatically"
echo

python3 build_wheels.py --source-dir "$SOURCE_DIR" --wheels-dir "$WHEELS_DIR"

BUILD_EXIT_CODE=$?

echo
if [ $BUILD_EXIT_CODE -eq 0 ]; then
    echo -e "${BLUE}========================================${NC}"
    log_success "Build complete!"
    echo -e "${BLUE}========================================${NC}"
    echo "Wheels are available in: $WHEELS_DIR"
    
    # Count built wheels
    WHEEL_COUNT=$(find "$WHEELS_DIR" -maxdepth 1 -name "*.whl" 2>/dev/null | wc -l)
    echo "Total wheels built: $WHEEL_COUNT"
    echo
    echo "To use the wheels:"
    echo "  pip install <package> --find-links $WHEELS_DIR --no-index"
else
    echo -e "${BLUE}========================================${NC}"
    log_error "Build failed with exit code $BUILD_EXIT_CODE"
    echo -e "${BLUE}========================================${NC}"
    echo "Check the build logs for details"
    echo "See docs/TROUBLESHOOTING.md for common issues"
    exit $BUILD_EXIT_CODE
fi

