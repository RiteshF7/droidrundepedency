#!/data/data/com.termux/files/usr/bin/bash
# build-all-wheels-automated.sh
# Automated wheel builder for all droidrun dependencies
# - Auto-detects architecture
# - Checks for existing wheels
# - Builds transitive dependencies first
# - Uses source files from sources/ folder
# - Applies all fixes and patches automatically
# - Exports all wheels to export/ folder

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Auto-detect architecture
ARCH=$(uname -m)
case "$ARCH" in
    aarch64|arm64)
        ARCH="aarch64"
        PLATFORM_TAG="linux_aarch64"
        ;;
    x86_64|amd64)
        ARCH="x86_64"
        PLATFORM_TAG="linux_x86_64"
        ;;
    *)
        echo "ERROR: Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

# Directory configuration
SOURCES_DIR="${SOURCES_DIR:-$PROJECT_ROOT/sources}"
WHEELS_DIR="${WHEELS_DIR:-$HOME/wheels}"
EXPORT_DIR="${EXPORT_DIR:-$PROJECT_ROOT/wheels_export/${ARCH}}"
BUILD_LOG="${BUILD_LOG:-$WHEELS_DIR/build-all-wheels.log}"
WHEEL_MANIFEST="${WHEEL_MANIFEST:-$EXPORT_DIR/wheel-manifest.txt}"

# Python version detection
PYTHON_VERSION=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
PYTHON_TAG="cp${PYTHON_VERSION//./}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Create directories
mkdir -p "$WHEELS_DIR" "$EXPORT_DIR" "$SOURCES_DIR"
touch "$BUILD_LOG"

# Logging function
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local log_entry="[$timestamp] [$level] $message"
    
    echo "$log_entry" >> "$BUILD_LOG"
    
    case "$level" in
        "INFO")
            echo -e "${BLUE}[INFO]${NC} $message"
            ;;
        "SUCCESS")
            echo -e "${GREEN}[SUCCESS]${NC} $message"
            ;;
        "ERROR")
            echo -e "${RED}[ERROR]${NC} $message"
            ;;
        "WARNING")
            echo -e "${YELLOW}[WARNING]${NC} $message"
            ;;
    esac
}

# Setup build environment
setup_build_environment() {
    log "INFO" "Setting up build environment for $ARCH..."
    
    export PREFIX=${PREFIX:-/data/data/com.termux/files/usr}
    export NINJAFLAGS="-j2"
    export MAKEFLAGS="-j2"
    export MAX_JOBS=2
    export CMAKE_PREFIX_PATH=$PREFIX
    export CMAKE_INCLUDE_PATH=$PREFIX/include
    export CC=$PREFIX/bin/clang
    export CXX=$PREFIX/bin/clang++
    export TMPDIR=$HOME/tmp
    mkdir -p $TMPDIR
    
    # Create gfortran symlink if needed
    if [ ! -f "$PREFIX/bin/gfortran" ] && [ -f "$PREFIX/bin/flang" ]; then
        ln -sf $PREFIX/bin/flang $PREFIX/bin/gfortran
        log "INFO" "Created gfortran symlink"
    fi
    
    log "SUCCESS" "Build environment configured"
}

# Check if wheel exists for this architecture
wheel_exists() {
    local pkg_name="$1"
    local pkg_version="${2:-}"
    
    # Check in wheels directory
    if [ -n "$pkg_version" ]; then
        if ls "$WHEELS_DIR/${pkg_name}-${pkg_version}"-*"${PLATFORM_TAG}.whl" 2>/dev/null | grep -q .; then
            return 0
        fi
    fi
    
    # Check any version
    if ls "$WHEELS_DIR/${pkg_name}-"*"${PLATFORM_TAG}.whl" 2>/dev/null | grep -q .; then
        return 0
    fi
    
    # Check in export directory
    if ls "$EXPORT_DIR/${pkg_name}-"*"${PLATFORM_TAG}.whl" 2>/dev/null | grep -q .; then
        return 0
    fi
    
    return 1
}

# Find source file for package
find_source_file() {
    local pkg_name="$1"
    local pkg_version="${2:-}"
    
    # Try exact match first
    if [ -n "$pkg_version" ]; then
        # Try various naming patterns
        for pattern in "${pkg_name}-${pkg_version}.tar.gz" "${pkg_name}-${pkg_version}.zip" \
                      "${pkg_name}-${pkg_version}-fixed.tar.gz" "${pkg_name}_${pkg_version}.tar.gz"; do
            if [ -f "$SOURCES_DIR/$pattern" ]; then
                echo "$SOURCES_DIR/$pattern"
                return 0
            fi
        done
    fi
    
    # Try any version
    for pattern in "${pkg_name}-"*.tar.gz "${pkg_name}-"*.zip "${pkg_name}_"*.tar.gz; do
        if ls "$SOURCES_DIR/$pattern" 2>/dev/null | head -1 | grep -q .; then
            ls "$SOURCES_DIR/$pattern" 2>/dev/null | head -1
            return 0
        fi
    done
    
    return 1
}

# Install system dependencies for a package
install_system_deps() {
    local pkg_name="$1"
    
    case "$pkg_name" in
        numpy)
            pkg install -y patchelf 2>/dev/null || true
            ;;
        pandas|scikit-learn)
            # Already handled in Phase 1
            ;;
        scipy)
            pkg install -y flang blas-openblas 2>/dev/null || true
            ln -sf $PREFIX/bin/flang $PREFIX/bin/gfortran 2>/dev/null || true
            ;;
        jiter)
            pkg install -y rust 2>/dev/null || true
            ;;
        pyarrow)
            pkg install -y libarrow-cpp 2>/dev/null || true
            export ARROW_HOME=$PREFIX
            ;;
        grpcio)
            pkg install -y patchelf abseil-cpp 2>/dev/null || true
            export GRPC_PYTHON_BUILD_SYSTEM_OPENSSL=1
            export GRPC_PYTHON_BUILD_SYSTEM_ZLIB=1
            export GRPC_PYTHON_BUILD_SYSTEM_CARES=1
            export GRPC_PYTHON_BUILD_SYSTEM_RE2=1
            export GRPC_PYTHON_BUILD_SYSTEM_ABSL=1
            export GRPC_PYTHON_BUILD_WITH_CYTHON=1
            ;;
        pillow)
            pkg install -y libjpeg-turbo libpng libtiff libwebp freetype 2>/dev/null || true
            export PKG_CONFIG_PATH=$PREFIX/lib/pkgconfig:$PKG_CONFIG_PATH
            export LDFLAGS="-L$PREFIX/lib"
            export CPPFLAGS="-I$PREFIX/include"
            ;;
    esac
}

# Apply fixes to source before building
apply_fixes() {
    local pkg_name="$1"
    local source_file="$2"
    local extract_dir="$3"
    
    case "$pkg_name" in
        pandas)
            log "INFO" "Applying pandas meson.build fix..."
            if [ -f "$extract_dir/meson.build" ]; then
                sed -i "s/version: run_command.*/version: '2.2.3',/" "$extract_dir/meson.build" || true
                log "SUCCESS" "Fixed pandas meson.build"
            fi
            ;;
        scikit-learn)
            log "INFO" "Applying scikit-learn fixes..."
            if [ -f "$extract_dir/sklearn/_build_utils/version.py" ]; then
                chmod +x "$extract_dir/sklearn/_build_utils/version.py"
                if ! head -1 "$extract_dir/sklearn/_build_utils/version.py" | grep -q "^#!"; then
                    sed -i '1i#!/usr/bin/env python3' "$extract_dir/sklearn/_build_utils/version.py"
                fi
            fi
            if [ -f "$extract_dir/meson.build" ]; then
                # Extract version and hardcode it
                if [ -f "$extract_dir/sklearn/_build_utils/version.py" ]; then
                    VERSION=$(python3 "$extract_dir/sklearn/_build_utils/version.py" 2>/dev/null || echo "1.9.dev0")
                    sed -i "4s|.*|  version: '$VERSION',|" "$extract_dir/meson.build" || true
                fi
            fi
            log "SUCCESS" "Fixed scikit-learn"
            ;;
    esac
}

# Build wheel for a package
build_wheel() {
    local pkg_name="$1"
    local pkg_version="${2:-}"
    local pkg_constraint="${3:-}"
    
    log "INFO" "Building wheel for $pkg_name${pkg_version:+ $pkg_version}..."
    
    # Check if already built
    if wheel_exists "$pkg_name" "$pkg_version"; then
        log "WARNING" "Wheel for $pkg_name already exists, skipping build"
        return 0
    fi
    
    # Find source file
    local source_file=$(find_source_file "$pkg_name" "$pkg_version")
    if [ -z "$source_file" ]; then
        log "ERROR" "Source file not found for $pkg_name in $SOURCES_DIR"
        return 1
    fi
    
    log "INFO" "Using source file: $(basename "$source_file")"
    
    # Install system dependencies
    install_system_deps "$pkg_name"
    
    # Extract and apply fixes if needed
    local temp_dir="$WHEELS_DIR/tmp_${pkg_name}_$$"
    mkdir -p "$temp_dir"
    
    if [[ "$source_file" == *.tar.gz ]]; then
        tar -xzf "$source_file" -C "$temp_dir"
    elif [[ "$source_file" == *.zip ]]; then
        unzip -q "$source_file" -d "$temp_dir"
    fi
    
    local extract_dir=$(ls -d "$temp_dir"/*/ 2>/dev/null | head -1 || echo "$temp_dir")
    
    # Apply fixes
    apply_fixes "$pkg_name" "$source_file" "$extract_dir"
    
    # Repackage if fixes were applied
    if [ "$pkg_name" = "pandas" ] || [ "$pkg_name" = "scikit-learn" ]; then
        cd "$temp_dir"
        local fixed_source="$WHEELS_DIR/$(basename "$source_file" | sed 's/\.tar\.gz$/-fixed.tar.gz/')"
        if [[ "$source_file" == *.tar.gz ]]; then
            tar -czf "$fixed_source" "$(basename "$extract_dir")"
        fi
        source_file="$fixed_source"
        cd - > /dev/null
    fi
    
    # Build wheel
    local build_flags="--no-deps --wheel-dir $WHEELS_DIR"
    
    # Special build flags for certain packages
    case "$pkg_name" in
        scikit-learn)
            build_flags="$build_flags --no-build-isolation"
            ;;
        grpcio)
            build_flags="$build_flags --no-build-isolation"
            ;;
    esac
    
    # Build from source file or extracted directory
    if [ -f "$source_file" ]; then
        pip wheel "$source_file" $build_flags || {
            log "ERROR" "Failed to build wheel for $pkg_name"
            rm -rf "$temp_dir"
            return 1
        }
    else
        cd "$extract_dir"
        pip wheel . $build_flags || {
            log "ERROR" "Failed to build wheel for $pkg_name"
            cd - > /dev/null
            rm -rf "$temp_dir"
            return 1
        }
        cd - > /dev/null
    fi
    
    # Special post-build fixes
    case "$pkg_name" in
        grpcio)
            log "INFO" "Applying grpcio wheel patch..."
            local wheel_file=$(ls "$WHEELS_DIR/grpcio-"*"${PLATFORM_TAG}.whl" 2>/dev/null | head -1)
            if [ -n "$wheel_file" ]; then
                local grpcio_extract="$WHEELS_DIR/grpcio_extract_$$"
                unzip -q "$wheel_file" -d "$grpcio_extract"
                local so_file=$(find "$grpcio_extract" -name "cygrpc*.so" | head -1)
                if [ -n "$so_file" ] && command -v patchelf >/dev/null 2>&1; then
                    patchelf --add-needed libabsl_flags_internal.so "$so_file" 2>/dev/null || true
                    patchelf --add-needed libabsl_flags.so "$so_file" 2>/dev/null || true
                    patchelf --add-needed libabsl_flags_commandlineflag.so "$so_file" 2>/dev/null || true
                    patchelf --add-needed libabsl_flags_reflection.so "$so_file" 2>/dev/null || true
                    patchelf --set-rpath "$PREFIX/lib" "$so_file" 2>/dev/null || true
                    
                    cd "$grpcio_extract"
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
                    cd - > /dev/null
                    mv "$WHEELS_DIR/grpcio-fixed.whl" "$wheel_file"
                    rm -rf "$grpcio_extract"
                    log "SUCCESS" "Patched grpcio wheel"
                fi
            fi
            ;;
    esac
    
    # Cleanup
    rm -rf "$temp_dir"
    
    # Install the wheel
    local built_wheel=$(ls "$WHEELS_DIR/${pkg_name}-"*"${PLATFORM_TAG}.whl" 2>/dev/null | head -1)
    if [ -n "$built_wheel" ]; then
        log "INFO" "Installing $pkg_name from wheel..."
        pip install --find-links "$WHEELS_DIR" --no-index "$built_wheel" || {
            log "WARNING" "Failed to install $pkg_name, continuing..."
        }
    fi
    
    log "SUCCESS" "Built and installed wheel for $pkg_name"
    return 0
}

# Get transitive dependencies for a package
get_transitive_deps() {
    local pkg_name="$1"
    
    # Define dependency tree based on DEPENDENCIES.md
    case "$pkg_name" in
        numpy)
            echo ""
            ;;
        scipy)
            echo "numpy"
            ;;
        pandas)
            echo "numpy"
            ;;
        scikit-learn)
            echo "numpy scipy"
            ;;
        jiter)
            echo ""
            ;;
        pyarrow)
            echo "numpy"
            ;;
        psutil)
            echo ""
            ;;
        grpcio)
            echo ""
            ;;
        pillow)
            echo ""
            ;;
        tokenizers|safetensors|cryptography|pydantic-core|orjson)
            echo ""
            ;;
        *)
            echo ""
            ;;
    esac
}

# Build package and its dependencies
build_with_deps() {
    local pkg_name="$1"
    local pkg_version="${2:-}"
    local pkg_constraint="${3:-}"
    
    # Get transitive dependencies
    local deps=$(get_transitive_deps "$pkg_name")
    
    # Build dependencies first
    for dep in $deps; do
        if ! wheel_exists "$dep"; then
            log "INFO" "Building transitive dependency: $dep"
            build_with_deps "$dep" "" ""
        else
            log "INFO" "Transitive dependency $dep already has wheel"
        fi
    done
    
    # Build the package itself
    build_wheel "$pkg_name" "$pkg_version" "$pkg_constraint"
}

# Main build function
main() {
    log "INFO" "=========================================="
    log "INFO" "Automated Wheel Builder for droidrun"
    log "INFO" "Architecture: $ARCH ($PLATFORM_TAG)"
    log "INFO" "Python: $PYTHON_VERSION ($PYTHON_TAG)"
    log "INFO" "Sources: $SOURCES_DIR"
    log "INFO" "Wheels: $WHEELS_DIR"
    log "INFO" "Export: $EXPORT_DIR"
    log "INFO" "=========================================="
    
    # Setup environment
    setup_build_environment
    
    # Phase 1: Install build tools
    log "INFO" "Phase 1: Installing build tools..."
    pip install --upgrade pip wheel setuptools 2>/dev/null || true
    pip install Cython "meson-python<0.19.0,>=0.16.0" "maturin<2,>=1.9.4" || {
        log "ERROR" "Failed to install build tools"
        exit 1
    }
    log "SUCCESS" "Build tools installed"
    
    # Phase 2: Foundation packages
    log "INFO" "Phase 2: Building foundation packages..."
    build_with_deps "numpy" "" ">=1.26.0"
    
    # Phase 3: Scientific stack
    log "INFO" "Phase 3: Building scientific stack..."
    build_with_deps "scipy" "" ">=1.8.0,<1.17.0"
    build_with_deps "pandas" "2.2.3" "<2.3.0"
    
    # Install scikit-learn dependencies first
    pip install joblib">=1.3.0" threadpoolctl">=3.2.0" 2>/dev/null || true
    build_with_deps "scikit-learn" "" ">=1.0.0"
    
    # Phase 4: Rust packages
    log "INFO" "Phase 4: Building Rust packages..."
    build_with_deps "jiter" "0.12.0" "==0.12.0"
    
    # Phase 5: Other compiled packages
    log "INFO" "Phase 5: Building other compiled packages..."
    build_with_deps "pyarrow" "" ""
    build_with_deps "psutil" "" ""
    build_with_deps "grpcio" "" ""
    build_with_deps "pillow" "" ""
    
    # Phase 6: Optional compiled packages
    log "INFO" "Phase 6: Building optional compiled packages..."
    for pkg in tokenizers safetensors cryptography pydantic-core orjson; do
        if ! wheel_exists "$pkg"; then
            build_with_deps "$pkg" "" ""
        fi
    done
    
    # Export all wheels
    log "INFO" "Exporting all wheels to $EXPORT_DIR..."
    mkdir -p "$EXPORT_DIR"
    cp "$WHEELS_DIR"/*"${PLATFORM_TAG}.whl" "$EXPORT_DIR/" 2>/dev/null || true
    
    # Create manifest
    log "INFO" "Creating wheel manifest..."
    {
        echo "# Wheel Manifest for $ARCH"
        echo "# Generated: $(date)"
        echo "# Python: $PYTHON_VERSION"
        echo "# Platform: $PLATFORM_TAG"
        echo ""
        echo "## Built Wheels:"
        ls -1 "$EXPORT_DIR"/*.whl 2>/dev/null | while read wheel; do
            echo "  - $(basename "$wheel")"
        done
        echo ""
        echo "## Total Wheels: $(ls -1 "$EXPORT_DIR"/*.whl 2>/dev/null | wc -l)"
    } > "$WHEEL_MANIFEST"
    
    log "SUCCESS" "=========================================="
    log "SUCCESS" "Build complete!"
    log "SUCCESS" "Wheels exported to: $EXPORT_DIR"
    log "SUCCESS" "Manifest: $WHEEL_MANIFEST"
    log "SUCCESS" "Total wheels: $(ls -1 "$EXPORT_DIR"/*.whl 2>/dev/null | wc -l)"
    log "SUCCESS" "=========================================="
}

# Run main function
main "$@"


