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
    
    # #region agent log
    DEBUG_LOG="${SCRIPT_DIR:-$HOME}/.cursor/debug.log"
    mkdir -p "$(dirname "$DEBUG_LOG")" 2>/dev/null || true
    echo "{\"sessionId\":\"debug-session\",\"runId\":\"run1\",\"hypothesisId\":\"A\",\"location\":\"installdroidrun.sh:45\",\"message\":\"python_pkg_installed entry\",\"data\":{\"pkg_name\":\"$pkg_name\",\"version_spec\":\"$version_spec\"},\"timestamp\":$(date +%s000)}" >> "$DEBUG_LOG" 2>/dev/null || true
    # #endregion
    
    # First try: Use python3 -m pip to check (ensures we use system pip)
    # Normalize package name for import check (replace dashes with underscores)
    local import_name=$(echo "$pkg_name" | tr '-' '_')
    
    # Try importing the package directly (fastest check)
    if python3 -c "import $import_name" 2>/dev/null; then
        # Package is importable, now check version if needed
        if [ -n "$version_spec" ] && [[ "$version_spec" != "$pkg_name" ]] && [[ "$version_spec" =~ [[:punct:]] ]] && (echo "$version_spec" | grep -qE '[<>=]'); then
            # Need to check version - use pip show to get version and compare
            local pip_show_output
            pip_show_output=$(python3 -m pip show "$pkg_name" 2>&1)
            if [ $? -eq 0 ]; then
                # Use pip install --dry-run to check if requirement is satisfied
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
            fi
        else
            # No version requirement, package is installed
            return 0
        fi
    fi
    
    # Fallback: Use pip show to check if package is installed (more reliable for some packages)
    local pip_show_output
    pip_show_output=$(python3 -m pip show "$pkg_name" 2>&1)
    local pip_show_exit=$?
    
    # #region agent log
    DEBUG_LOG="${SCRIPT_DIR:-$HOME}/.cursor/debug.log"
    echo "{\"sessionId\":\"debug-session\",\"runId\":\"run1\",\"hypothesisId\":\"A\",\"location\":\"installdroidrun.sh:52\",\"message\":\"pip show result\",\"data\":{\"pkg_name\":\"$pkg_name\",\"exit_code\":$pip_show_exit,\"output\":\"$(echo "$pip_show_output" | head -3 | tr '\n' ';')\"},\"timestamp\":$(date +%s000)}" >> "$DEBUG_LOG" 2>/dev/null || true
    # #endregion
    
    if [ $pip_show_exit -ne 0 ]; then
        # #region agent log
        DEBUG_LOG="${SCRIPT_DIR:-$HOME}/.cursor/debug.log"
        echo "{\"sessionId\":\"debug-session\",\"runId\":\"run1\",\"hypothesisId\":\"A\",\"location\":\"installdroidrun.sh:56\",\"message\":\"pip show failed, returning 1\",\"data\":{\"pkg_name\":\"$pkg_name\"},\"timestamp\":$(date +%s000)}" >> "$DEBUG_LOG" 2>/dev/null || true
        # #endregion
        return 1
    fi
    
    # If version spec is provided and contains version requirements, check if installed version satisfies it
    if [ -n "$version_spec" ] && [[ "$version_spec" != "$pkg_name" ]] && [[ "$version_spec" =~ [[:punct:]] ]] && (echo "$version_spec" | grep -qE '[<>=]'); then
        # Use pip install with --dry-run to check if requirement is satisfied
        # This uses pip's own requirement resolver which is most reliable
        local pip_output
        pip_output=$(python3 -m pip install --dry-run --no-deps "$version_spec" 2>&1)
        local pip_dry_run_exit=$?
        
        # #region agent log
        DEBUG_LOG="${SCRIPT_DIR:-$HOME}/.cursor/debug.log"
        echo "{\"sessionId\":\"debug-session\",\"runId\":\"run1\",\"hypothesisId\":\"B\",\"location\":\"installdroidrun.sh:66\",\"message\":\"pip install --dry-run result\",\"data\":{\"version_spec\":\"$version_spec\",\"exit_code\":$pip_dry_run_exit,\"output\":\"$(echo "$pip_output" | tr '\n' ';' | head -c 500)\"},\"timestamp\":$(date +%s000)}" >> "$DEBUG_LOG" 2>/dev/null || true
        # #endregion
        
        # If pip says "Requirement already satisfied", the version requirement is met
        if echo "$pip_output" | grep -q "Requirement already satisfied"; then
            # #region agent log
            DEBUG_LOG="${SCRIPT_DIR:-$HOME}/.cursor/debug.log"
            echo "{\"sessionId\":\"debug-session\",\"runId\":\"run1\",\"hypothesisId\":\"B\",\"location\":\"installdroidrun.sh:71\",\"message\":\"grep found 'Requirement already satisfied', returning 0\",\"data\":{\"version_spec\":\"$version_spec\"},\"timestamp\":$(date +%s000)}" >> "$DEBUG_LOG" 2>/dev/null || true
            # #endregion
            return 0
        fi
        
        # If pip would install/upgrade, the requirement is not satisfied
        if echo "$pip_output" | grep -qE "(Would install|Would upgrade)"; then
            # #region agent log
            DEBUG_LOG="${SCRIPT_DIR:-$HOME}/.cursor/debug.log"
            echo "{\"sessionId\":\"debug-session\",\"runId\":\"run1\",\"hypothesisId\":\"B\",\"location\":\"installdroidrun.sh:78\",\"message\":\"grep found 'Would install/upgrade', returning 1\",\"data\":{\"version_spec\":\"$version_spec\"},\"timestamp\":$(date +%s000)}" >> "$DEBUG_LOG" 2>/dev/null || true
            # #endregion
            return 1
        fi
        
        # If output is unclear, assume requirement is satisfied (better to skip than rebuild unnecessarily)
        # This handles edge cases where pip output format might differ
        # #region agent log
        DEBUG_LOG="${SCRIPT_DIR:-$HOME}/.cursor/debug.log"
        echo "{\"sessionId\":\"debug-session\",\"runId\":\"run1\",\"hypothesisId\":\"B\",\"location\":\"installdroidrun.sh:85\",\"message\":\"unclear output, assuming satisfied, returning 0\",\"data\":{\"version_spec\":\"$version_spec\"},\"timestamp\":$(date +%s000)}" >> "$DEBUG_LOG" 2>/dev/null || true
        # #endregion
        return 0
    fi
    
    # If no version requirement or just package name, package is installed
    # #region agent log
    DEBUG_LOG="${SCRIPT_DIR:-$HOME}/.cursor/debug.log"
    echo "{\"sessionId\":\"debug-session\",\"runId\":\"run1\",\"hypothesisId\":\"A\",\"location\":\"installdroidrun.sh:91\",\"message\":\"no version requirement, returning 0\",\"data\":{\"pkg_name\":\"$pkg_name\",\"version_spec\":\"$version_spec\"},\"timestamp\":$(date +%s000)}" >> "$DEBUG_LOG" 2>/dev/null || true
    # #endregion
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
    log_info "Running: python3 -m pip download \"$version_spec\" --dest . --no-cache-dir --no-binary :all:"
    local download_output=$(python3 -m pip download "$version_spec" --dest . --no-cache-dir --no-binary :all: 2>&1)
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
    # #region agent log
    DEBUG_LOG="${SCRIPT_DIR:-$HOME}/.cursor/debug.log"
    echo "{\"sessionId\":\"debug-session\",\"runId\":\"run1\",\"hypothesisId\":\"C\",\"location\":\"installdroidrun.sh:285\",\"message\":\"build_package checking if installed\",\"data\":{\"pkg_name\":\"$pkg_name\",\"version_spec\":\"$version_spec\"},\"timestamp\":$(date +%s000)}" >> "$DEBUG_LOG" 2>/dev/null || true
    # #endregion
    
    if python_pkg_installed "$pkg_name" "$version_spec"; then
        local check_result=0
        # #region agent log
        DEBUG_LOG="${SCRIPT_DIR:-$HOME}/.cursor/debug.log"
        echo "{\"sessionId\":\"debug-session\",\"runId\":\"run1\",\"hypothesisId\":\"C\",\"location\":\"installdroidrun.sh:290\",\"message\":\"python_pkg_installed returned 0, skipping build\",\"data\":{\"pkg_name\":\"$pkg_name\",\"version_spec\":\"$version_spec\"},\"timestamp\":$(date +%s000)}" >> "$DEBUG_LOG" 2>/dev/null || true
        # #endregion
        log_success "$pkg_name is already installed and satisfies version requirement ($version_spec), skipping build"
        return 0
    else
        local check_result=1
        # #region agent log
        DEBUG_LOG="${SCRIPT_DIR:-$HOME}/.cursor/debug.log"
        echo "{\"sessionId\":\"debug-session\",\"runId\":\"run1\",\"hypothesisId\":\"C\",\"location\":\"installdroidrun.sh:297\",\"message\":\"python_pkg_installed returned 1, will build\",\"data\":{\"pkg_name\":\"$pkg_name\",\"version_spec\":\"$version_spec\"},\"timestamp\":$(date +%s000)}" >> "$DEBUG_LOG" 2>/dev/null || true
        # #endregion
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
        # First check local WHEELS_DIR
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
        # #region agent log
        DEBUG_LOG="${SCRIPT_DIR:-$HOME}/.cursor/debug.log"
        echo "{\"sessionId\":\"debug-session\",\"runId\":\"run1\",\"hypothesisId\":\"E\",\"location\":\"installdroidrun.sh:315\",\"message\":\"calling download_and_fix_source\",\"data\":{\"pkg_name\":\"$pkg_name\",\"version_spec\":\"$version_spec\",\"fix_type\":\"$fix_type\"},\"timestamp\":$(date +%s000)}" >> "$DEBUG_LOG" 2>/dev/null || true
        # #endregion
        # Use a temp file to capture the return value while letting logs flow through
        local result_file=$(mktemp)
        # Run function, capture stdout to file, but let stderr (logs) flow through
        if download_and_fix_source "$pkg_name" "$version_spec" "$fix_type" > "$result_file" 2>&1; then
            # #region agent log
            DEBUG_LOG="${SCRIPT_DIR:-$HOME}/.cursor/debug.log"
            echo "{\"sessionId\":\"debug-session\",\"runId\":\"run1\",\"hypothesisId\":\"E\",\"location\":\"installdroidrun.sh:322\",\"message\":\"download_and_fix_source succeeded\",\"data\":{\"pkg_name\":\"$pkg_name\"},\"timestamp\":$(date +%s000)}" >> "$DEBUG_LOG" 2>/dev/null || true
            # #endregion
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
            # #region agent log
            DEBUG_LOG="${SCRIPT_DIR:-$HOME}/.cursor/debug.log"
            local error_content=$(cat "$result_file" 2>/dev/null | head -10 | tr '\n' ';' | head -c 300)
            echo "{\"sessionId\":\"debug-session\",\"runId\":\"run1\",\"hypothesisId\":\"E\",\"location\":\"installdroidrun.sh:393\",\"message\":\"download_and_fix_source failed\",\"data\":{\"pkg_name\":\"$pkg_name\",\"error_preview\":\"$error_content\"},\"timestamp\":$(date +%s000)}" >> "$DEBUG_LOG" 2>/dev/null || true
            # #endregion
            log_error "Failed to download and fix $pkg_name source"
            rm -f "$result_file"
            return 1
        fi
    fi
    
    # Build wheel - ensure we're in WHEELS_DIR and use absolute path
    log_info "Building $pkg_name wheel (pip will download source automatically)..."
    cd "$WHEELS_DIR"
    local wheels_dir_abs=$(cd "$WHEELS_DIR" && pwd)
    local pip_wheel_output
    pip_wheel_output=$(python3 -m pip wheel "$source_arg" --no-deps $build_opts --wheel-dir "$wheels_dir_abs" 2>&1) || {
        log_error "Failed to build $pkg_name wheel"
        echo "$pip_wheel_output" | grep -v "Looking in indexes" | grep -v "Collecting" | while read line; do log_error "  $line"; done
        [ -n "$temp_dir" ] && rm -rf "$temp_dir"
        return 1
    }
    # Display output (filtering out noise)
    echo "$pip_wheel_output" | grep -v "Looking in indexes" | grep -v "Collecting" | while read line; do log_info "  $line"; done || true
    
    # Find the wheel file - check WHEELS_DIR first, then extract from pip output if needed
    local wheel_file=""
    wheel_file=$(ls -1 "$wheels_dir_abs"/${wheel_pattern} 2>/dev/null | head -1)
    
    # If not found in WHEELS_DIR, try to extract from pip output (it might show where it was stored)
    if [ -z "$wheel_file" ] || [ ! -f "$wheel_file" ]; then
        # Try to extract wheel path from pip output
        local stored_path=$(echo "$pip_wheel_output" | grep -o "Stored in directory: [^ ]*" | cut -d' ' -f4- | head -1)
        if [ -n "$stored_path" ]; then
            wheel_file=$(find "$stored_path" -name "${wheel_pattern}" 2>/dev/null | head -1)
            # If found in cache, copy it to WHEELS_DIR
            if [ -n "$wheel_file" ] && [ -f "$wheel_file" ]; then
                log_info "Found wheel in cache, copying to WHEELS_DIR..."
                cp "$wheel_file" "$wheels_dir_abs/" 2>/dev/null || true
                wheel_file="$wheels_dir_abs/$(basename "$wheel_file")"
            fi
        fi
    fi
    
    # Final check - if still not found, try pattern match in WHEELS_DIR
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
    
    # Cleanup temp directory if used (do this before changing directory)
    [ -n "$temp_dir" ] && rm -rf "$temp_dir"
    
    # Install wheel - change to HOME directory to avoid "directory not found" errors
    log_info "Installing $pkg_name wheel..."
    local pip_install_output
    pip_install_output=$(cd "$HOME" && python3 -m pip install --find-links "$wheels_dir_abs" --no-index "$wheel_file" 2>&1) || {
        log_error "Failed to install $pkg_name wheel"
        echo "$pip_install_output" | grep -v "Looking in indexes" | grep -v "Collecting" | while read line; do log_error "  $line"; done
        return 1
    }
    # Display output (filtering out warnings and noise)
    echo "$pip_install_output" | grep -v "Looking in indexes" | grep -v "Collecting" | grep -v "The folder you are executing pip from" | while read line; do log_info "  $line"; done || true
    
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
    # Install wheel and setuptools only if needed
    if ! python_pkg_installed "wheel" "wheel" || ! python_pkg_installed "setuptools" "setuptools"; then
        python3 -m pip install --upgrade wheel setuptools --quiet
    fi
    
    # Install Cython only if needed
    if ! python_pkg_installed "Cython" "Cython"; then
        python3 -m pip install Cython --quiet
    fi
    
    # Install meson-python only if needed
    if ! python_pkg_installed "meson-python" "meson-python<0.19.0,>=0.16.0"; then
        python3 -m pip install "meson-python<0.19.0,>=0.16.0" --quiet
    fi
    
    # Install maturin only if needed
    if ! python_pkg_installed "maturin" "maturin<2,>=1.9.4"; then
        python3 -m pip install "maturin<2,>=1.9.4" --quiet
    fi
    
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
    log_error "Failed to build scipy - this is required, exiting"
    exit 1
fi

# Build pandas using the tested build_pandas.sh script
if python_pkg_installed "pandas" "pandas<2.3.0"; then
    log_success "pandas is already installed and satisfies version requirement (pandas<2.3.0), skipping build"
else
    log_info "pandas not installed or version requirement (pandas<2.3.0) not satisfied, will build"
    
    # Pre-install pandas dependencies before building
    log_info "Pre-installing pandas runtime dependencies..."
    PANDAS_DEPS=(
        "python-dateutil>=2.8.2"
        "pytz>=2020.1"
        "tzdata>=2022.7"
    )
    
    for dep in "${PANDAS_DEPS[@]}"; do
        dep_name=$(echo "$dep" | sed 's/[<>=].*//')
        if ! python_pkg_installed "$dep_name" "$dep"; then
            log_info "Installing $dep..."
            pip_output=$(python3 -m pip install "$dep" 2>&1)
            pip_exit=$?
            
            # Display output (filtering out noise)
            echo "$pip_output" | grep -v "Looking in indexes" | grep -v "Collecting" | grep -v "The folder you are executing pip from" | while read line; do log_info "  $line"; done || true
            
            if [ $pip_exit -eq 0 ]; then
                log_success "$dep installed"
            else
                log_warning "Failed to install $dep (exit code: $pip_exit), but continuing..."
                # Show error details
                echo "$pip_output" | grep -i "error\|failed\|exception" | head -5 | while read line; do log_warning "    $line"; done || true
            fi
        else
            log_info "$dep_name already installed"
        fi
    done
    
    log_info "Building pandas using build_pandas.sh..."
    
    # Check if build_pandas.sh exists
    BUILD_PANDAS_SCRIPT="${SCRIPT_DIR}/build_pandas.sh"
    if [ ! -f "$BUILD_PANDAS_SCRIPT" ]; then
        # Try alternative locations
        BUILD_PANDAS_SCRIPT="${HOME}/droidrundepedency/build_pandas.sh"
        if [ ! -f "$BUILD_PANDAS_SCRIPT" ]; then
            BUILD_PANDAS_SCRIPT="./build_pandas.sh"
        fi
    fi
    
    if [ ! -f "$BUILD_PANDAS_SCRIPT" ]; then
        log_error "build_pandas.sh not found. Expected locations:"
        log_error "  ${SCRIPT_DIR}/build_pandas.sh"
        log_error "  ${HOME}/droidrundepedency/build_pandas.sh"
        log_error "  ./build_pandas.sh"
        log_error "Falling back to build_package method..."
        if ! build_package "pandas" "pandas<2.3.0" --fix-source=pandas; then
            log_error "Failed to build pandas - this is required, exiting"
            exit 1
        fi
    else
        log_info "Using build script: $BUILD_PANDAS_SCRIPT"
        # Make script executable
        chmod +x "$BUILD_PANDAS_SCRIPT" 2>/dev/null || true
        
        # Run build_pandas.sh with same environment variables
        if bash "$BUILD_PANDAS_SCRIPT"; then
            log_success "pandas built and installed successfully using build_pandas.sh"
        else
            log_error "Failed to build pandas using build_pandas.sh - this is required, exiting"
            exit 1
        fi
    fi
fi

# Build scikit-learn using the tested build_scikit_learn.sh script
if python_pkg_installed "scikit-learn" "scikit-learn"; then
    log_success "scikit-learn is already installed, skipping build"
else
    log_info "scikit-learn not installed, will build"
    
    # Pre-install scikit-learn runtime dependencies before building
    log_info "Pre-installing scikit-learn runtime dependencies..."
    SCIKIT_LEARN_DEPS=(
        "joblib>=1.3.0"
        "threadpoolctl>=3.2.0"
    )
    
    for dep in "${SCIKIT_LEARN_DEPS[@]}"; do
        dep_name=$(echo "$dep" | sed 's/[<>=].*//')
        if ! python_pkg_installed "$dep_name" "$dep"; then
            log_info "Installing $dep..."
            scikit_dep_output=$(python3 -m pip install "$dep" 2>&1)
            scikit_dep_exit=$?
            if [ $scikit_dep_exit -ne 0 ]; then
                log_warning "Failed to install $dep (exit code: $scikit_dep_exit)"
                echo "$scikit_dep_output" | grep -v "Looking in indexes" | grep -v "Collecting" | grep -v "The folder you are executing pip from" | while read line; do log_warning "  $line"; done
            else
                log_success "$dep installed"
            fi
        else
            log_info "$dep_name already installed"
        fi
    done
    
    log_info "Building scikit-learn using build_scikit_learn.sh..."
    
    # Find build_scikit_learn.sh
    BUILD_SCIKIT_LEARN_SCRIPT=""
    if [ -f "${SCRIPT_DIR}/build_scikit_learn.sh" ]; then
        BUILD_SCIKIT_LEARN_SCRIPT="${SCRIPT_DIR}/build_scikit_learn.sh"
    elif [ -f "${HOME}/droidrundepedency/build_scikit_learn.sh" ]; then
        BUILD_SCIKIT_LEARN_SCRIPT="${HOME}/droidrundepedency/build_scikit_learn.sh"
    elif [ -f "./build_scikit_learn.sh" ]; then
        BUILD_SCIKIT_LEARN_SCRIPT="./build_scikit_learn.sh"
    fi
    
    if [ -n "$BUILD_SCIKIT_LEARN_SCRIPT" ]; then
        log_info "Using build script: $BUILD_SCIKIT_LEARN_SCRIPT"
        # Make script executable
        chmod +x "$BUILD_SCIKIT_LEARN_SCRIPT" 2>/dev/null || true
        
        # Run build_scikit_learn.sh with same environment variables
        if bash "$BUILD_SCIKIT_LEARN_SCRIPT"; then
            log_success "scikit-learn built and installed successfully using build_scikit_learn.sh"
        else
            log_warning "Failed to build scikit-learn using build_scikit_learn.sh - continuing without it"
            log_warning "Some droidrun features may not work without scikit-learn"
        fi
    else
        log_warning "build_scikit_learn.sh not found, falling back to generic build_package for scikit-learn"
        if ! build_package "scikit-learn" "scikit-learn" --fix-source=scikit-learn --no-build-isolation --wheel-pattern="scikit_learn*.whl"; then
            log_warning "Failed to build scikit-learn - continuing without it"
            log_warning "Some droidrun features may not work without scikit-learn"
        fi
    fi
fi

log_success "Phase 3 complete: Scientific stack installed"

# ============================================
# Phase 4: Rust Packages (jiter)
# ============================================
log_info "Phase 4: Building jiter..."
JITER_BUILT=false
for attempt in 1 2; do
    if [ $attempt -gt 1 ]; then
        log_info "Retrying jiter build (attempt $attempt)..."
        rm -f jiter*.whl 2>/dev/null || true
    fi
    
    if build_package "jiter" "jiter==0.12.0"; then
        JITER_BUILT=true
        break
    else
        log_warning "jiter build failed (attempt $attempt)"
        if [ $attempt -lt 2 ]; then
            log_info "Waiting 5 seconds before retry..."
            sleep 5
        fi
    fi
done

if [ "$JITER_BUILT" = false ]; then
    log_warning "jiter build failed after retries - continuing without it"
    log_warning "Some droidrun features may not work without jiter"
else
    log_success "jiter installed successfully"
fi
log_success "Phase 4 complete: jiter processed"

# ============================================
# Phase 5: Other Compiled Packages
# ============================================
log_info "Phase 5: Building other compiled packages..."

# Build pyarrow (optional - continue on failure)
if ! build_package "pyarrow" "pyarrow" --pre-check --env-var="ARROW_HOME=$PREFIX"; then
    log_warning "pyarrow build failed - continuing without it"
    log_warning "Some droidrun features may not work without pyarrow"
fi

# Build psutil (optional - continue on failure)
if ! build_package "psutil" "psutil"; then
    log_warning "psutil build failed - continuing without it"
    log_warning "Some droidrun features may not work without psutil"
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
    grpcio_wheel_output=$(python3 -m pip wheel grpcio --no-deps --no-build-isolation --wheel-dir . 2>&1) || {
        log_error "Failed to build grpcio wheel"
        echo "$grpcio_wheel_output" | grep -v "Looking in indexes" | grep -v "Collecting" | grep -v "The folder you are executing pip from" | while read line; do log_error "  $line"; done
        exit 1
    }
    # Display output (filtering out noise)
    echo "$grpcio_wheel_output" | grep -v "Looking in indexes" | grep -v "Collecting" | grep -v "The folder you are executing pip from" | while read line; do log_info "  $line"; done || true
    
    # Verify wheel was created and get absolute path
    grpcio_wheel=$(ls -1 grpcio*.whl 2>/dev/null | head -1)
    if [ -z "$grpcio_wheel" ] || [ ! -f "$grpcio_wheel" ]; then
        log_error "grpcio wheel file not found after build"
        exit 1
    fi
    
    log_success "grpcio wheel built successfully"

    # Fix grpcio wheel (needs to be in WHEELS_DIR)
    cd "$WHEELS_DIR"
    if ! fix_grpcio_wheel; then
        log_error "Failed to fix grpcio wheel"
        exit 1
    fi

    # Get absolute paths before changing directory
    grpcio_wheel=$(ls -1 grpcio*.whl 2>/dev/null | head -1)
    if [ -z "$grpcio_wheel" ] || [ ! -f "$grpcio_wheel" ]; then
        log_error "grpcio wheel file not found after fix"
        exit 1
    fi
    grpcio_wheel_abs=$(cd "$(dirname "$grpcio_wheel")" && pwd)/$(basename "$grpcio_wheel")
    wheels_dir_abs=$(cd "$WHEELS_DIR" && pwd)

    # Install grpcio dependencies first (typing-extensions is required)
    log_info "Installing grpcio dependencies..."
    if ! python_pkg_installed "typing-extensions" "typing-extensions>=4.12"; then
        log_info "Installing typing-extensions (required by grpcio)..."
        typing_ext_output=$(cd "$HOME" && python3 -m pip install "typing-extensions>=4.12" 2>&1)
        typing_ext_exit=$?
        
        # Display output (filtering out noise)
        echo "$typing_ext_output" | grep -v "Looking in indexes" | grep -v "Collecting" | grep -v "The folder you are executing pip from" | while read line; do log_info "  $line"; done || true
        
        if [ $typing_ext_exit -ne 0 ]; then
            log_error "Failed to install typing-extensions (exit code: $typing_ext_exit) - this is required for grpcio"
            echo "$typing_ext_output" | grep -i "error\|failed\|exception" | head -5 | while read line; do log_error "    $line"; done || true
            exit 1
        else
            # Verify it's actually installed and importable
            if python3 -c "import typing_extensions" 2>/dev/null; then
                log_success "typing-extensions installed and verified"
            else
                log_error "typing-extensions installation succeeded but package is not importable"
                exit 1
            fi
        fi
    else
        log_info "typing-extensions already installed"
        # Verify it's importable
        if ! python3 -c "import typing_extensions" 2>/dev/null; then
            log_warning "typing-extensions appears installed but not importable, reinstalling..."
            typing_ext_output=$(cd "$HOME" && python3 -m pip install --force-reinstall "typing-extensions>=4.12" 2>&1)
            typing_ext_exit=$?
            if [ $typing_ext_exit -ne 0 ]; then
                log_error "Failed to reinstall typing-extensions"
                exit 1
            fi
        fi
    fi

    # Install the fixed wheel - change to HOME directory to avoid "directory not found" errors
    # Use --no-deps since we've already installed typing-extensions
    log_info "Installing grpcio wheel (dependencies already installed)..."
    grpcio_install_output=$(cd "$HOME" && python3 -m pip install --no-deps "$grpcio_wheel_abs" 2>&1) || {
        log_error "Failed to install grpcio wheel"
        echo "$grpcio_install_output" | grep -v "Looking in indexes" | grep -v "Collecting" | grep -v "The folder you are executing pip from" | while read line; do log_error "  $line"; done
        exit 1
    }
    # Display output (filtering out warnings)
    echo "$grpcio_install_output" | grep -v "Looking in indexes" | grep -v "Collecting" | grep -v "The folder you are executing pip from" | while read line; do log_info "  $line"; done || true
fi

# Set LD_LIBRARY_PATH for runtime (REQUIRED for grpcio to work)
export LD_LIBRARY_PATH=$PREFIX/lib:${LD_LIBRARY_PATH:-}
# Add to ~/.bashrc for permanent fix
if ! grep -q "LD_LIBRARY_PATH.*PREFIX/lib" ~/.bashrc 2>/dev/null; then
    echo "export LD_LIBRARY_PATH=\$PREFIX/lib:\$LD_LIBRARY_PATH" >> ~/.bashrc
fi

log_success "grpcio installed (wheel fixed)"

# Build Pillow (optional - continue on failure)
if ! build_package "pillow" "pillow" --env-var="PKG_CONFIG_PATH=$PREFIX/lib/pkgconfig:${PKG_CONFIG_PATH:-}" --env-var="LDFLAGS=-L$PREFIX/lib" --env-var="CPPFLAGS=-I$PREFIX/include"; then
    log_warning "pillow build failed - continuing without it"
    log_warning "Some droidrun features may not work without pillow"
fi

log_success "Phase 5 complete: Other compiled packages processed"

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
    
    # First, try to find and install pre-built wheels from dependencies folder
    # Check multiple possible locations for dependencies folder
    DEPENDENCIES_WHEELS_DIRS=(
        "${SCRIPT_DIR}/depedencies/wheels"
        "${HOME}/droidrundepedency/depedencies/wheels"
        "${HOME}/depedencies/wheels"
    )
    
    for DEPENDENCIES_WHEELS_DIR in "${DEPENDENCIES_WHEELS_DIRS[@]}"; do
        if [ -d "$DEPENDENCIES_WHEELS_DIR" ]; then
            log_info "Found dependencies folder: $DEPENDENCIES_WHEELS_DIR"
            # Try to find architecture-specific wheel directory
            ARCH_DIR=""
            if [ -d "${DEPENDENCIES_WHEELS_DIR}/_x86_64_wheels" ]; then
                ARCH_DIR="${DEPENDENCIES_WHEELS_DIR}/_x86_64_wheels"
            elif [ -d "${DEPENDENCIES_WHEELS_DIR}/arch64_wheels" ]; then
                ARCH_DIR="${DEPENDENCIES_WHEELS_DIR}/arch64_wheels"
            fi
            
            if [ -n "$ARCH_DIR" ]; then
                log_info "Checking for pre-built wheels in $ARCH_DIR..."
                # Copy matching wheels to WHEELS_DIR
                for pkg in "${missing_packages[@]}"; do
                    wheel_file=$(find "$ARCH_DIR" -name "${pkg}*.whl" 2>/dev/null | head -1)
                    if [ -n "$wheel_file" ] && [ -f "$wheel_file" ]; then
                        log_info "Found pre-built wheel for $pkg: $(basename "$wheel_file")"
                        cp "$wheel_file" "$WHEELS_DIR/" 2>/dev/null || true
                    fi
                done
            fi
            break  # Found and processed, no need to check other locations
        fi
    done
    
    # Filter out packages that are already installed
    packages_to_install=()
    for pkg in "${missing_packages[@]}"; do
        if python_pkg_installed "$pkg" "$pkg"; then
            log_info "$pkg is already installed, skipping"
        else
            packages_to_install+=("$pkg")
        fi
    done
    
    # If all packages are already installed, skip installation
    if [ ${#packages_to_install[@]} -eq 0 ]; then
        log_success "Phase 6 complete: All optional packages already installed"
    # Try installing with pre-built wheels first
    elif python3 -m pip install "${packages_to_install[@]}" --find-links "$WHEELS_DIR" 2>/dev/null; then
        log_success "Phase 6 complete: Optional packages installed (pre-built wheels)"
    else
        log_info "Some packages need building from source..."
        
        built_packages=()
        
        # Build each missing package (continue on failure)
        for pkg in "${packages_to_install[@]}"; do
            # Special handling for tokenizers - prefer pre-built wheel due to Android pthread limitations
            if [ "$pkg" = "tokenizers" ]; then
                # First try to install from pre-built wheel
                tokenizers_wheel=$(find "$WHEELS_DIR" -name "tokenizers*.whl" 2>/dev/null | head -1)
                if [ -n "$tokenizers_wheel" ] && [ -f "$tokenizers_wheel" ]; then
                    log_info "Installing $pkg from pre-built wheel: $(basename "$tokenizers_wheel")"
                    if python3 -m pip install --find-links "$WHEELS_DIR" --no-index "$tokenizers_wheel" 2>/dev/null; then
                        log_success "$pkg installed from pre-built wheel"
                        built_packages+=("$pkg")
                        continue
                    fi
                fi
                # If wheel installation failed, try building with special flags
                log_info "Building $pkg with special compiler flags for Android/Termux compatibility..."
                # Note: pthread_cond_clockwait is not available on Android, so building may fail
                # The pre-built wheel is strongly recommended
                if build_package "$pkg" "$pkg" --env-var="CXXFLAGS=-D_GNU_SOURCE" 2>&1 | grep -v "Looking in indexes" | grep -v "Collecting" | while read line; do log_info "  $line"; done; then
                    built_packages+=("$pkg")
                else
                    log_warning "Skipping $pkg (build failed - pthread_cond_clockwait not available on Android)"
                    log_info "Recommendation: Use pre-built wheel from dependencies folder"
                fi
            else
                if build_package "$pkg" "$pkg" 2>/dev/null; then
                    built_packages+=("$pkg")
                else
                    log_warning "Skipping $pkg (build failed)"
                fi
            fi
        done
        
        # Install any wheels that were built
        if [ ${#built_packages[@]} -gt 0 ]; then
            cd "$WHEELS_DIR"
            wheel_files=()
            for pkg in "${built_packages[@]}"; do
                found_wheel=$(ls -1 ${pkg}*.whl 2>/dev/null | head -1)
                if [ -n "$found_wheel" ] && [ -f "$found_wheel" ]; then
                    wheel_files+=("$(cd "$(dirname "$found_wheel")" && pwd)/$(basename "$found_wheel")")
                fi
            done
            if [ ${#wheel_files[@]} -gt 0 ]; then
                local wheels_dir_abs=$(cd "$WHEELS_DIR" && pwd)
                cd "$HOME" && python3 -m pip install --find-links "$wheels_dir_abs" --no-index "${wheel_files[@]}" 2>/dev/null || true
            fi
        fi
        
        log_success "Phase 6 complete: Optional packages processed"
    fi
fi

# ============================================
# Phase 7: Main Package + LLM Providers
# ============================================
log_info "Phase 7: Installing droidrun and LLM providers..."

cd "$HOME"

# Find install_droidrun_providers.sh script
PROVIDERS_SCRIPT=""
if [ -f "${SCRIPT_DIR}/install_droidrun_providers.sh" ]; then
    PROVIDERS_SCRIPT="${SCRIPT_DIR}/install_droidrun_providers.sh"
elif [ -f "${HOME}/droidrundepedency/install_droidrun_providers.sh" ]; then
    PROVIDERS_SCRIPT="${HOME}/droidrundepedency/install_droidrun_providers.sh"
elif [ -f "./install_droidrun_providers.sh" ]; then
    PROVIDERS_SCRIPT="./install_droidrun_providers.sh"
fi

if [ -n "$PROVIDERS_SCRIPT" ] && [ -f "$PROVIDERS_SCRIPT" ]; then
    log_info "Using provider installation script: $PROVIDERS_SCRIPT"
    # Make script executable
    chmod +x "$PROVIDERS_SCRIPT" 2>/dev/null || true
    
    # Run install_droidrun_providers.sh with same environment variables
    # The script will handle droidrun core installation and all providers
    if bash "$PROVIDERS_SCRIPT"; then
        log_success "Phase 7 complete: droidrun and providers installed"
    else
        log_error "Failed to install droidrun providers"
        log_error "Provider installation script failed"
        exit 1
    fi
else
    log_warning "install_droidrun_providers.sh not found, falling back to inline installation"
    log_warning "Expected locations:"
    log_warning "  ${SCRIPT_DIR}/install_droidrun_providers.sh"
    log_warning "  ${HOME}/droidrundepedency/install_droidrun_providers.sh"
    log_warning "  ./install_droidrun_providers.sh"
    
    # Fallback: Install droidrun core only (providers should be installed separately)
    if python_pkg_installed "droidrun" "droidrun"; then
        log_success "droidrun is already installed"
    else
        log_info "Installing droidrun core..."
        if python3 -m pip install droidrun --find-links "$WHEELS_DIR" 2>/dev/null; then
            log_success "droidrun core installed"
            log_warning "Run install_droidrun_providers.sh separately to install LLM providers"
        else
            log_error "Failed to install droidrun core"
            exit 1
        fi
    fi
    log_success "Phase 7 complete: droidrun core installed"
fi

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
