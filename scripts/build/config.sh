#!/data/data/com.termux/files/usr/bin/bash
# config.sh
# Configuration file for build-all-wheels-automated.sh
# Contains all paths, configs, and constants

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_SCRIPTS_DIR="$SCRIPT_DIR"

# Calculate PROJECT_ROOT - config.sh is in scripts/build/, so go up 2 levels
# But if called from main script, it's in scripts/, so go up 1 level
if [[ "$SCRIPT_DIR" == *"/build" ]]; then
    PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
else
    PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
fi

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
# Set SOURCES_DIR with fallbacks
if [ -z "${SOURCES_DIR:-}" ]; then
    # Try default path first
    SOURCES_DIR="/data/data/com.termux/files/home/droidrunBuild/sources/source"
    # Fallback to project sources if default doesn't exist
    if [ ! -d "$SOURCES_DIR" ]; then
        SOURCES_DIR="$PROJECT_ROOT/depedencies/source"
    fi
    # Fallback to sources directory
    if [ ! -d "$SOURCES_DIR" ]; then
        SOURCES_DIR="$PROJECT_ROOT/sources"
    fi
    # Final fallback - just use the default path even if it doesn't exist yet
    if [ ! -d "$SOURCES_DIR" ]; then
        SOURCES_DIR="/data/data/com.termux/files/home/droidrunBuild/sources/source"
    fi
fi
WHEELS_DIR="${WHEELS_DIR:-$HOME/wheels}"
EXPORT_DIR="${EXPORT_DIR:-$PROJECT_ROOT/wheels_${ARCH}}"
BUILD_LOG="${BUILD_LOG:-$WHEELS_DIR/build-all-wheels.log}"
WHEEL_MANIFEST="${WHEEL_MANIFEST:-$EXPORT_DIR/wheel-manifest.txt}"

# Python version detection
PYTHON_VERSION=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>/dev/null || echo "3.12")
PYTHON_TAG="cp${PYTHON_VERSION//./}"

# Colors for logging
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# System dependencies from DEPENDENCIES.md (in installation order)
# Each entry: package_name:prerequisite1,prerequisite2
declare -A SYSTEM_DEPS=(
    ["python"]=""
    ["python-pip"]="python"
    ["autoconf"]=""
    ["automake"]="autoconf"
    ["libtool"]=""
    ["make"]=""
    ["binutils"]=""
    ["clang"]=""
    ["cmake"]=""
    ["ninja"]=""
    ["rust"]=""
    ["flang"]=""
    ["blas-openblas"]=""
    ["libjpeg-turbo"]=""
    ["libpng"]=""
    ["libtiff"]=""
    ["libwebp"]=""
    ["freetype"]=""
    ["libarrow-cpp"]=""
    ["openssl"]=""
    ["libc++"]=""
    ["zlib"]=""
    ["protobuf"]=""
    ["libprotobuf"]="protobuf"
    ["abseil-cpp"]=""
    ["c-ares"]=""
    ["libre2"]=""
    ["patchelf"]=""
    ["p7zip"]=""
)

# Python packages from DEPENDENCIES.md (in build order with constraints)
declare -A PYTHON_PACKAGES=(
    # Phase 1: Build tools
    ["Cython"]=""
    ["meson-python"]="<0.19.0,>=0.16.0"
    ["maturin"]="<2,>=1.9.4"
    
    # Phase 2: Foundation
    ["numpy"]=">=1.26.0"
    
    # Phase 3: Scientific stack
    ["scipy"]=">=1.8.0,<1.17.0"
    ["pandas"]="<2.3.0"
    ["scikit-learn"]=">=1.0.0"
    
    # Phase 4: Rust packages
    ["jiter"]="==0.12.0"
    
    # Phase 5: Other compiled
    ["pyarrow"]=""
    ["psutil"]=""
    ["grpcio"]=""
    ["pillow"]=""
    
    # Phase 6: Optional compiled
    ["tokenizers"]=""
    ["safetensors"]=""
    ["cryptography"]=""
    ["pydantic-core"]=""
    ["orjson"]=""
)

# Package-specific system dependencies
declare -A PKG_SYSTEM_DEPS=(
    ["numpy"]="patchelf"
    ["scipy"]="flang blas-openblas"
    ["jiter"]="rust"
    ["pyarrow"]="libarrow-cpp"
    ["grpcio"]="patchelf abseil-cpp"
    ["pillow"]="libjpeg-turbo libpng libtiff libwebp freetype"
)

# Transitive dependencies (Python packages that depend on others)
declare -A PYTHON_TRANSITIVE_DEPS=(
    ["scipy"]="numpy"
    ["pandas"]="numpy"
    ["scikit-learn"]="numpy scipy"
    ["pyarrow"]="numpy"
)

# GitHub release configuration for source downloads
# Default to the current repository
GITHUB_REPO="${GITHUB_REPO:-RiteshF7/droidrundepedency}"
GITHUB_RELEASE_TAG="${GITHUB_RELEASE_TAG:-latest}"
SOURCE_ARCHIVE_NAME="${SOURCE_ARCHIVE_NAME:-sources.tar.gz}"

# Export all variables
export SCRIPT_DIR BUILD_SCRIPTS_DIR PROJECT_ROOT
export ARCH PLATFORM_TAG
export SOURCES_DIR WHEELS_DIR EXPORT_DIR BUILD_LOG WHEEL_MANIFEST
export PYTHON_VERSION PYTHON_TAG
export RED GREEN YELLOW BLUE NC
export GITHUB_REPO GITHUB_RELEASE_TAG SOURCE_ARCHIVE_NAME

