#!/usr/bin/env bash
# Common functions and setup for droidrun installation phases
# This file should be sourced by all phase scripts

set -euo pipefail

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Package name (can be changed for different Termux variants)
PACKAGE_NAME="${PACKAGE_NAME:-com.termux}"

# Detect environment (Termux, WSL, or other)
IS_TERMUX=false
# Check for TERMUX_VERSION environment variable (most reliable indicator)
if [ -n "${TERMUX_VERSION:-}" ]; then
    IS_TERMUX=true
# Also check for Termux PREFIX directory and verify it's actually Termux
elif [ -d "/data/data/com.termux/files/usr" ] && [ -f "/data/data/com.termux/files/usr/bin/pkg" ]; then
    IS_TERMUX=true
fi

# Setup PREFIX
if [ -z "${PREFIX:-}" ]; then
    if [ "$IS_TERMUX" = true ]; then
        export PREFIX="/data/data/${PACKAGE_NAME}/files/usr"
    else
        # For non-Termux environments (WSL/testing), use standard prefix
        export PREFIX="${PREFIX:-/usr}"
    fi
fi

# Setup script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Progress tracking and logging
PROGRESS_FILE="${HOME}/.droidrun_install_progress"
ENV_FILE="${HOME}/.droidrun_install_env"
LOG_FILE="${HOME}/.droidrun_install.log"
ERROR_LOG_FILE="${HOME}/.droidrun_install_errors.log"

# Initialize log files
touch "$LOG_FILE"
touch "$ERROR_LOG_FILE"

# Enhanced logging functions that also write to log file
log_info() {
    local msg="$1"
    echo -e "${BLUE}[INFO]${NC} $msg" | tee -a "$LOG_FILE"
}

log_success() {
    local msg="$1"
    echo -e "${GREEN}[✓]${NC} $msg" | tee -a "$LOG_FILE"
}

log_warning() {
    local msg="$1"
    echo -e "${YELLOW}[⚠]${NC} $msg" | tee -a "$LOG_FILE" | tee -a "$ERROR_LOG_FILE"
}

log_error() {
    local msg="$1"
    echo -e "${RED}[✗]${NC} $msg" | tee -a "$LOG_FILE" | tee -a "$ERROR_LOG_FILE" >&2
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if package is installed
pkg_installed() {
    local pkg_name=$1
    if [ "$IS_TERMUX" = true ]; then
        # Termux: use pkg command
        if command_exists pkg; then
            pkg list-installed 2>/dev/null | grep -q "^$pkg_name " || return 1
        else
            return 1
        fi
    else
        # Non-Termux environments: try to detect package using system package manager
        # For testing purposes, we'll check if common commands exist
        case "$pkg_name" in
            python|python-pip)
                command_exists python3 && return 0 || return 1
                ;;
            rust)
                command_exists rustc && return 0 || return 1
                ;;
            clang)
                command_exists clang && return 0 || return 1
                ;;
            cmake)
                command_exists cmake && return 0 || return 1
                ;;
            make)
                command_exists make && return 0 || return 1
                ;;
            *)
                # For other packages, assume not installed in non-Termux (for testing)
                return 1
                ;;
        esac
    fi
}

# Check if Python package is already installed and satisfies version requirement
python_pkg_installed() {
    local pkg_name=$1
    local version_spec=$2
    
    # Normalize package name for import check (replace dashes with underscores)
    local import_name=$(echo "$pkg_name" | tr '-' '_')
    
    # Try importing the package directly (fastest check)
    if python3 -c "import $import_name" 2>/dev/null; then
        # Package is importable, now check version if needed
        if [ -n "$version_spec" ] && [[ "$version_spec" != "$pkg_name" ]] && [[ "$version_spec" =~ [[:punct:]] ]] && (echo "$version_spec" | grep -qE '[<>=]'); then
            # Need to check version - use pip install --dry-run to check if requirement is satisfied
            local pip_output
            pip_output=$(python3 -m pip install --dry-run --no-deps "$version_spec" 2>&1)
            if echo "$pip_output" | grep -q "Requirement already satisfied"; then
                return 0
            fi
            if echo "$pip_output" | grep -qE "(Would install|Would upgrade)"; then
                return 1
            fi
            # If unclear, assume satisfied
            return 0
        else
            # No version requirement, package is installed
            return 0
        fi
    fi
    
    # Fallback: Use pip show to check if package is installed (more reliable for some packages)
    local pip_show_output
    pip_show_output=$(python3 -m pip show "$pkg_name" 2>&1)
    local pip_show_exit=$?
    
    if [ $pip_show_exit -ne 0 ]; then
        return 1
    fi
    
    # If version spec is provided and contains version requirements, check if installed version satisfies it
    if [ -n "$version_spec" ] && [[ "$version_spec" != "$pkg_name" ]] && [[ "$version_spec" =~ [[:punct:]] ]] && (echo "$version_spec" | grep -qE '[<>=]'); then
        # Use pip install with --dry-run to check if requirement is satisfied
        local pip_output
        pip_output=$(python3 -m pip install --dry-run --no-deps "$version_spec" 2>&1)
        
        # If pip says "Requirement already satisfied", the version requirement is met
        if echo "$pip_output" | grep -q "Requirement already satisfied"; then
            return 0
        fi
        
        # If pip would install/upgrade, the requirement is not satisfied
        if echo "$pip_output" | grep -qE "(Would install|Would upgrade)"; then
            return 1
        fi
        
        # If output is unclear, assume requirement is satisfied
        return 0
    fi
    
    # If no version requirement or just package name, package is installed
    return 0
}

# Validate tar.gz file integrity
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
    
    # Download source using pip
    log_info "Running: python3 -m pip download \"$version_spec\" --dest . --no-cache-dir --no-binary :all:"
    local download_output=$(python3 -m pip download "$version_spec" --dest . --no-cache-dir --no-binary :all: 2>&1)
    local download_exit_code=$?
    
    if [ $download_exit_code -ne 0 ]; then
        log_error "Failed to download $pkg_name source (exit code: $download_exit_code)"
        log_error "pip download output:"
        echo "$download_output" | while read line; do
            log_error "  $line"
        done
        rm -rf "$WORK_DIR"
        return 1
    fi
    
    log_info "pip download completed successfully"
    
    # Find downloaded file
    log_info "Searching for source file: ${pkg_name}-*.tar.gz"
    local source_file=$(ls ${pkg_name}-*.tar.gz 2>/dev/null | head -1)
    if [ -z "$source_file" ]; then
        log_error "Downloaded source file not found for $pkg_name"
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
    
    # Pre-check for pre-built wheels
    if [ "$pre_check" = true ]; then
        log_info "Checking for pre-built $pkg_name wheel..."
        local_wheel=$(find "$WHEELS_DIR" -name "${wheel_pattern}" 2>/dev/null | head -1)
        if [ -n "$local_wheel" ] && [ -f "$local_wheel" ]; then
            log_info "Found pre-built wheel: $(basename "$local_wheel")"
            local_wheel_abs=$(cd "$(dirname "$local_wheel")" && pwd)/$(basename "$local_wheel")
            local wheels_dir_abs=$(cd "$WHEELS_DIR" && pwd)
            if cd "$HOME" && python3 -m pip install --find-links "$wheels_dir_abs" --no-index "$local_wheel_abs" 2>/dev/null; then
                log_success "$pkg_name installed (pre-built wheel)"
                return 0
            fi
        fi
        # Try downloading from PyPI
        cd "$WHEELS_DIR"
        python3 -m pip download "$version_spec" --dest . --no-cache-dir 2>&1 | grep -v "Looking in indexes" | grep -v "Collecting" | while read line; do log_info "  $line"; done || true
        downloaded_wheel=$(ls -1 ${wheel_pattern} 2>/dev/null | head -1)
        if [ -n "$downloaded_wheel" ] && [ -f "$downloaded_wheel" ]; then
            downloaded_wheel_abs=$(cd "$(dirname "$downloaded_wheel")" && pwd)/$(basename "$downloaded_wheel")
            wheels_dir_abs=$(cd "$WHEELS_DIR" && pwd)
            if cd "$HOME" && python3 -m pip install --find-links "$wheels_dir_abs" --no-index "$downloaded_wheel_abs" 2>/dev/null; then
                log_success "$pkg_name installed (pre-built wheel)"
                return 0
            fi
        fi
        log_info "No pre-built wheel found, building from source..."
    fi
    
    # Download and fix source if needed
    local source_arg="$version_spec"
    local temp_dir=""
    if [ -n "$fix_type" ]; then
        local result_file=$(mktemp)
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
    cd "$WHEELS_DIR"
    local wheels_dir_abs=$(cd "$WHEELS_DIR" && pwd)
    local temp_log_file=$(mktemp)
    
    if ! python3 -m pip wheel "$source_arg" --no-deps $build_opts --wheel-dir "$wheels_dir_abs" > "$temp_log_file" 2>&1; then
        pip_wheel_exit=$?
        log_error "Failed to build $pkg_name wheel (exit code: $pip_wheel_exit)"
        echo "=== Build Error for $pkg_name at $(date) ===" >> "$ERROR_LOG_FILE"
        echo "Exit code: $pip_wheel_exit" >> "$ERROR_LOG_FILE"
        echo "Command: python3 -m pip wheel $source_arg --no-deps $build_opts --wheel-dir $wheels_dir_abs" >> "$ERROR_LOG_FILE"
        echo "--- Error lines ---" >> "$ERROR_LOG_FILE"
        grep -iE "error|failed|exception|traceback" "$temp_log_file" >> "$ERROR_LOG_FILE" || true
        echo "--- Last 20 lines of output ---" >> "$ERROR_LOG_FILE"
        tail -20 "$temp_log_file" >> "$ERROR_LOG_FILE" || true
        echo "=== End of error for $pkg_name ===" >> "$ERROR_LOG_FILE"
        echo "" >> "$ERROR_LOG_FILE"
        
        grep -iE "error|failed|exception|traceback" "$temp_log_file" | head -30 | while read line; do 
            log_error "  $line"
        done || true
        log_error "Last 10 lines of build output:"
        tail -10 "$temp_log_file" | while read line; do 
            log_error "  $line"
        done || true
        log_error "Full error details saved to: $ERROR_LOG_FILE"
        rm -f "$temp_log_file"
        [ -n "$temp_dir" ] && rm -rf "$temp_dir"
        return 1
    fi
    
    # Display relevant output
    grep -vE "(Looking in indexes|Collecting|^$)" "$temp_log_file" | tail -30 | while read line; do 
        if ! echo "$line" | grep -qiE "error|failed|exception"; then
            log_info "  $line"
        fi
    done || true
    rm -f "$temp_log_file"
    
    # Find the wheel file
    local wheel_file=""
    wheel_file=$(ls -1 "$wheels_dir_abs"/${wheel_pattern} 2>/dev/null | head -1)
    
    if [ -z "$wheel_file" ] || [ ! -f "$wheel_file" ]; then
        wheel_file=$(find "$wheels_dir_abs" -maxdepth 1 -name "${wheel_pattern}" 2>/dev/null | head -1)
    fi
    
    if [ -z "$wheel_file" ] || [ ! -f "$wheel_file" ]; then
        log_error "Wheel file not found after build: ${wheel_pattern}"
        log_error "Searched in: $wheels_dir_abs"
        [ -n "$temp_dir" ] && rm -rf "$temp_dir"
        return 1
    fi
    
    # Ensure absolute path
    wheel_file=$(cd "$(dirname "$wheel_file")" && pwd)/$(basename "$wheel_file")
    
    log_success "$pkg_name wheel built successfully"
    
    # Cleanup temp directory if used
    [ -n "$temp_dir" ] && rm -rf "$temp_dir"
    
    # Install wheel
    log_info "Installing $pkg_name wheel..."
    local pip_install_output
    pip_install_output=$(cd "$HOME" && python3 -m pip install --find-links "$wheels_dir_abs" --no-index "$wheel_file" 2>&1) || {
        log_error "Failed to install $pkg_name wheel"
        echo "$pip_install_output" | grep -v "Looking in indexes" | grep -v "Collecting" | while read line; do log_error "  $line"; done
        return 1
    }
    echo "$pip_install_output" | grep -v "Looking in indexes" | grep -v "Collecting" | grep -v "The folder you are executing pip from" | while read line; do log_info "  $line"; done || true
    
    # Post-install commands
    if [ -n "$post_install" ]; then
        eval "$post_install"
    fi
    
    log_success "$pkg_name installed"
    return 0
}

# Function to mark phase as complete
mark_phase_complete() {
    local phase=$1
    local timestamp=$(date +%s)
    touch "$PROGRESS_FILE"
    if grep -q "PHASE_${phase}_COMPLETE=" "$PROGRESS_FILE" 2>/dev/null; then
        sed -i "/^PHASE_${phase}_COMPLETE=/d" "$PROGRESS_FILE"
    fi
    echo "PHASE_${phase}_COMPLETE=$timestamp" >> "$PROGRESS_FILE"
    formatted_date=$(date -d "@$timestamp" 2>/dev/null || date -r "$timestamp" 2>/dev/null || echo "$timestamp")
    log_info "Progress saved: Phase $phase completed at $formatted_date"
}

# Function to check if phase is complete
is_phase_complete() {
    local phase=$1
    if [ -f "$PROGRESS_FILE" ]; then
        grep -q "PHASE_${phase}_COMPLETE=" "$PROGRESS_FILE" && return 0
    fi
    return 1
}

# Function to check if phase should be skipped (respects FORCE_RERUN)
should_skip_phase() {
    local phase=$1
    
    # If FORCE_RERUN is set, don't skip
    if [ -n "${FORCE_RERUN:-}" ]; then
        log_warning "FORCE_RERUN is set - Phase $phase will be rerun even if previously completed"
        # Clear phase completion status
        if [ -f "$PROGRESS_FILE" ]; then
            sed -i "/^PHASE_${phase}_COMPLETE=/d" "$PROGRESS_FILE" 2>/dev/null || true
            log_info "Phase $phase completion status cleared"
        fi
        return 1  # Don't skip
    fi
    
    # Check if phase is complete
    if is_phase_complete "$phase"; then
        return 0  # Skip (phase is complete)
    fi
    
    return 1  # Don't skip (phase not complete or force rerun)
}

# Function to save environment variables
save_env_vars() {
    cat > "$ENV_FILE" <<EOF
export PREFIX="${PREFIX}"
export WHEELS_DIR="${WHEELS_DIR}"
export SCRIPT_DIR="${SCRIPT_DIR}"
export PACKAGE_NAME="${PACKAGE_NAME}"
export CC="${CC:-}"
export CXX="${CXX:-}"
export CMAKE_PREFIX_PATH="${CMAKE_PREFIX_PATH:-}"
export CMAKE_INCLUDE_PATH="${CMAKE_INCLUDE_PATH:-}"
export TMPDIR="${TMPDIR:-}"
export NINJAFLAGS="${NINJAFLAGS:-}"
export MAKEFLAGS="${MAKEFLAGS:-}"
export MAX_JOBS="${MAX_JOBS:-}"
export LD_LIBRARY_PATH="${LD_LIBRARY_PATH:-}"
export GRPC_PYTHON_BUILD_SYSTEM_OPENSSL="${GRPC_PYTHON_BUILD_SYSTEM_OPENSSL:-}"
export GRPC_PYTHON_BUILD_SYSTEM_ZLIB="${GRPC_PYTHON_BUILD_SYSTEM_ZLIB:-}"
export GRPC_PYTHON_BUILD_SYSTEM_CARES="${GRPC_PYTHON_BUILD_SYSTEM_CARES:-}"
export GRPC_PYTHON_BUILD_SYSTEM_RE2="${GRPC_PYTHON_BUILD_SYSTEM_RE2:-}"
export GRPC_PYTHON_BUILD_SYSTEM_ABSL="${GRPC_PYTHON_BUILD_SYSTEM_ABSL:-}"
export GRPC_PYTHON_BUILD_WITH_CYTHON="${GRPC_PYTHON_BUILD_WITH_CYTHON:-}"
EOF
    log_info "Environment variables saved to $ENV_FILE"
}

# Function to load environment variables
load_env_vars() {
    if [ -f "$ENV_FILE" ]; then
        log_info "Loading environment variables from $ENV_FILE"
        source "$ENV_FILE"
        log_success "Environment variables loaded"
    fi
}

# Setup build environment
setup_build_environment() {
    log_info "Setting up build environment..."
    
    # PREFIX should already be set, but ensure it has a default
    if [ -z "${PREFIX:-}" ]; then
        if [ "$IS_TERMUX" = true ]; then
            export PREFIX="/data/data/${PACKAGE_NAME}/files/usr"
        else
            export PREFIX="/usr"
        fi
    fi
    
    # Set build parallelization based on available system memory
    get_total_mem_mb() {
        if [ -r /proc/meminfo ]; then
            awk '/MemTotal/ { printf "%.0f", $2/1024 }' /proc/meminfo
        else
            echo 0
        fi
    }
    
    MEM_MB=$(get_total_mem_mb)
    
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
    
    # CMAKE configuration
    export CMAKE_PREFIX_PATH=$PREFIX
    export CMAKE_INCLUDE_PATH=$PREFIX/include
    
    # Compiler environment variables
    export CC=$PREFIX/bin/clang
    export CXX=$PREFIX/bin/clang++
    
    # Temporary directory
    export TMPDIR=$HOME/tmp
    mkdir -p "$TMPDIR"
    
    # Ensure wheels directory exists
    WHEELS_DIR="${HOME}/wheels"
    mkdir -p "$WHEELS_DIR"
    
    log_success "Build environment configured"
    save_env_vars
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

# Initialize logging
init_logging() {
    if [ ! -f "$LOG_FILE" ] || [ ! -s "$LOG_FILE" ]; then
        echo "=== droidrun Installation Log - Started at $(date) ===" >> "$LOG_FILE"
    fi
    if [ ! -f "$ERROR_LOG_FILE" ] || [ ! -s "$ERROR_LOG_FILE" ]; then
        echo "=== Error Log - Started at $(date) ===" >> "$ERROR_LOG_FILE"
    fi
}

