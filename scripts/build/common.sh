#!/data/data/com.termux/files/usr/bin/bash
# common.sh
# Common functions used across build scripts

# Source config if not already sourced
if [ -z "${ARCH:-}" ]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    source "$SCRIPT_DIR/config.sh"
fi

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

# Get pip command (helper function)
get_pip_cmd() {
    if command -v pip3 >/dev/null 2>&1; then
        echo "pip3"
    elif command -v pip >/dev/null 2>&1; then
        echo "pip"
    elif [ -x "$PREFIX/bin/pip3" ]; then
        echo "$PREFIX/bin/pip3"
    elif [ -x "$PREFIX/bin/pip" ]; then
        echo "$PREFIX/bin/pip"
    elif command -v python3 >/dev/null 2>&1; then
        echo "python3 -m pip"
    else
        echo "pip3"  # fallback
    fi
}

# Setup build environment
setup_build_environment() {
    log "INFO" "Setting up build environment for $ARCH..."
    
    export PREFIX=${PREFIX:-/data/data/com.termux/files/usr}
    export HOME=${HOME:-/data/data/com.termux/files/home}
    export PATH=$PREFIX/bin:$PATH
    export NINJAFLAGS="-j2"
    export MAKEFLAGS="-j2"
    export MAX_JOBS=2
    export CMAKE_PREFIX_PATH=$PREFIX
    export CMAKE_INCLUDE_PATH=$PREFIX/include
    export CC=$PREFIX/bin/clang
    export CXX=$PREFIX/bin/clang++
    export TMPDIR=$HOME/tmp
    mkdir -p "$TMPDIR"
    
    # Create gfortran symlink if needed
    if [ ! -f "$PREFIX/bin/gfortran" ] && [ -f "$PREFIX/bin/flang" ]; then
        ln -sf "$PREFIX/bin/flang" "$PREFIX/bin/gfortran" 2>/dev/null || true
        log "INFO" "Created gfortran symlink"
    fi
    
    # Verify pip is available
    local PIP_CMD=$(get_pip_cmd)
    if [[ "$PIP_CMD" == *"python3 -m pip"* ]]; then
        if ! python3 -m pip --version >/dev/null 2>&1; then
            log "ERROR" "pip not found. Please install Python: pkg install -y python python-pip"
            exit 1
        fi
    else
        if ! $PIP_CMD --version >/dev/null 2>&1; then
            log "ERROR" "pip not found. Please install Python: pkg install -y python python-pip"
            exit 1
        fi
    fi
    log "INFO" "Using pip: $PIP_CMD"
    
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
    
    # Check in project wheels directories
    local project_wheels_dir="$PROJECT_ROOT/depedencies/wheels"
    if [ "$ARCH" = "aarch64" ]; then
        if ls "$project_wheels_dir/arch64_wheels/${pkg_name}-"*"${PLATFORM_TAG}.whl" 2>/dev/null | grep -q .; then
            return 0
        fi
    elif [ "$ARCH" = "x86_64" ]; then
        if ls "$project_wheels_dir/_x86_64_wheels/${pkg_name}-"*"${PLATFORM_TAG}.whl" 2>/dev/null | grep -q .; then
            return 0
        fi
    fi
    
    return 1
}

# Find source file for package
find_source_file() {
    local pkg_name="$1"
    local pkg_version="${2:-}"
    
    # Try exact match first
    if [ -n "$pkg_version" ]; then
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

# Check if package is installed via pip
is_package_installed() {
    local pkg_name="$1"
    local PIP_CMD=$(get_pip_cmd)
    
    if [[ "$PIP_CMD" == *"python3 -m pip"* ]]; then
        python3 -m pip show "$pkg_name" >/dev/null 2>&1
    else
        $PIP_CMD show "$pkg_name" >/dev/null 2>&1
    fi
}

