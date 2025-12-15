#!/data/data/com.termux/files/usr/bin/bash
# install-droidrun-dependencies.sh
# Step-by-step installation of all droidrun[google] dependencies
# Preserves all wheel files and provides detailed progress logging

# Note: We don't use 'set -e' because we want to continue on non-critical failures
# Critical failures (numpy, scipy, pandas) will exit explicitly

# Configuration
SCRIPT_START_TIME=$(date +%s)
LOG_FILE="$HOME/wheels/install-dependencies.log"
WHEELS_DIR="$HOME/wheels"
TOTAL_STEPS=12
CURRENT_STEP=0
SUCCESS_COUNT=0
FAILED_COUNT=0
SKIPPED_COUNT=0
FAILED_PACKAGES=()

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Create wheels directory and log file
mkdir -p "$WHEELS_DIR"
touch "$LOG_FILE"

# Logging function
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local log_entry="[$timestamp] [$level] $message"
    
    echo "$log_entry" >> "$LOG_FILE"
    
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
        "STEP")
            echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo -e "${BLUE}[STEP $CURRENT_STEP/$TOTAL_STEPS]${NC} $message"
            echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            ;;
        *)
            echo "$message"
            ;;
    esac
}

# Function to get elapsed time
get_elapsed_time() {
    local start_time=$1
    local end_time=$(date +%s)
    local elapsed=$((end_time - start_time))
    local minutes=$((elapsed / 60))
    local seconds=$((elapsed % 60))
    printf "%02d:%02d" "$minutes" "$seconds"
}

# Function to check if package is already installed
is_package_installed() {
    local package_name="$1"
    pip show "$package_name" &>/dev/null
}

# Function to get installed version
get_installed_version() {
    local package_name="$1"
    pip show "$package_name" 2>/dev/null | grep "^Version:" | awk '{print $2}' || echo "not installed"
}

# Function to install a package with wheel building
install_package_with_wheel() {
    local package_name="$1"
    local version_constraint="${2:-}"
    local package_spec="$package_name"
    local step_start_time=$(date +%s)
    local build_required=true
    local wheel_created=false
    
    CURRENT_STEP=$((CURRENT_STEP + 1))
    
    if [ -n "$version_constraint" ]; then
        package_spec="$package_name$version_constraint"
    fi
    
    log "STEP" "$package_name - Starting installation"
    log "INFO" "Package spec: $package_spec"
    
    # Check if already installed with correct version
    if is_package_installed "$package_name"; then
        local installed_version=$(get_installed_version "$package_name")
        log "INFO" "Package $package_name is already installed (version: $installed_version)"
        
        # For packages with constraints, check if version matches using Python packaging
        if [ -n "$version_constraint" ]; then
            # Extract version numbers from constraint (e.g., ">=1.8.0,<1.17.0")
            local min_version=$(echo "$version_constraint" | grep -oP '>=\K[0-9.]+' | head -1)
            local max_version=$(echo "$version_constraint" | grep -oP '<\K[0-9.]+' | head -1)
            
            if [ -n "$min_version" ] || [ -n "$max_version" ]; then
                # Use Python to check version constraint
                local version_check=$(python3 -c "
import sys
from packaging import version
installed = '$installed_version'
min_v = '$min_version' if '$min_version' else '0'
max_v = '$max_version' if '$max_version' else '999'
try:
    v = version.parse(installed)
    min_ok = version.parse(min_v) <= v if min_v != '0' else True
    max_ok = v < version.parse(max_v) if max_v != '999' else True
    if min_ok and max_ok:
        print('OK')
    else:
        print('FAIL')
except:
    print('FAIL')
" 2>/dev/null || echo "FAIL")
                
                if [ "$version_check" = "OK" ]; then
                    log "INFO" "Installed version $installed_version satisfies constraint $version_constraint - skipping"
                    SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
                    return 0
                else
                    log "WARNING" "Installed version $installed_version may not satisfy $version_constraint - will reinstall"
                fi
            else
                log "WARNING" "Could not parse version constraint $version_constraint - will reinstall"
            fi
        else
            log "INFO" "Skipping $package_name - already installed"
            SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
            return 0
        fi
    fi
    fi
    
    cd "$WHEELS_DIR" || exit 1
    
    # Step 1: Download source distribution
    log "INFO" "Downloading $package_spec..."
    if pip download "$package_spec" --dest . --no-cache-dir 2>&1 | tee -a "$LOG_FILE"; then
        log "INFO" "Download completed"
    else
        log "ERROR" "Failed to download $package_spec"
        FAILED_COUNT=$((FAILED_COUNT + 1))
        FAILED_PACKAGES+=("$package_name (download failed)")
        return 1
    fi
    
    # Step 2: Build wheel from source
    local source_file=""
    # Find the downloaded source file (most recent)
    source_file=$(ls -t ${package_name}-*.tar.gz 2>/dev/null | head -1)
    
    if [ -z "$source_file" ] || [ ! -f "$source_file" ]; then
        log "WARNING" "No source file found for $package_name, checking for pre-built wheel..."
        # Check if there's already a wheel
        local existing_wheel=$(ls ${package_name}-*.whl 2>/dev/null | head -1)
        if [ -n "$existing_wheel" ]; then
            log "INFO" "Using existing wheel: $existing_wheel"
            build_required=false
        else
            log "ERROR" "No source file or wheel found for $package_name"
            FAILED_COUNT=$((FAILED_COUNT + 1))
            FAILED_PACKAGES+=("$package_name (no source/wheel)")
            return 1
        fi
    fi
    
    if [ "$build_required" = true ]; then
        log "INFO" "Building wheel from $source_file (this may take a while)..."
        local build_start=$(date +%s)
        
        if pip wheel --no-deps --wheel-dir . "$source_file" 2>&1 | tee -a "$LOG_FILE"; then
            local build_time=$(get_elapsed_time "$build_start")
            log "INFO" "Wheel built successfully (time: $build_time)"
            wheel_created=true
        else
            log "ERROR" "Failed to build wheel for $package_name"
            FAILED_COUNT=$((FAILED_COUNT + 1))
            FAILED_PACKAGES+=("$package_name (build failed)")
            return 1
        fi
    fi
    
    # Step 3: Install from wheel
    local wheel_file=$(ls -t ${package_name}-*.whl 2>/dev/null | head -1)
    if [ -z "$wheel_file" ] || [ ! -f "$wheel_file" ]; then
        log "ERROR" "No wheel file found for $package_name after build"
        FAILED_COUNT=$((FAILED_COUNT + 1))
        FAILED_PACKAGES+=("$package_name (no wheel file)")
        return 1
    fi
    
    log "INFO" "Installing from wheel: $wheel_file"
    
    # Uninstall old version if exists (for packages that might have version conflicts)
    if [[ "$package_name" == "pandas" ]]; then
        log "INFO" "Uninstalling any existing pandas version..."
        pip uninstall -y pandas 2>/dev/null || true
    fi
    
    if pip install --find-links . --no-index "$wheel_file" 2>&1 | tee -a "$LOG_FILE"; then
        local installed_version=$(get_installed_version "$package_name")
        local total_time=$(get_elapsed_time "$step_start_time")
        log "SUCCESS" "$package_name installed successfully (Version: $installed_version, Time: $total_time)"
        
        if [ "$wheel_created" = true ]; then
            log "INFO" "Wheel file preserved: $wheel_file"
        fi
        
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
        return 0
    else
        log "ERROR" "Failed to install $package_name from wheel"
        FAILED_COUNT=$((FAILED_COUNT + 1))
        FAILED_PACKAGES+=("$package_name (installation failed)")
        return 1
    fi
}

# Function to install pure Python package (no build needed)
install_pure_python_package() {
    local package_name="$1"
    local version_constraint="${2:-}"
    local package_spec="$package_name"
    local step_start_time=$(date +%s)
    
    CURRENT_STEP=$((CURRENT_STEP + 1))
    
    if [ -n "$version_constraint" ]; then
        package_spec="$package_name$version_constraint"
    fi
    
    log "STEP" "$package_name - Installing pure Python package"
    
    if is_package_installed "$package_name"; then
        local installed_version=$(get_installed_version "$package_name")
        log "INFO" "Package $package_name is already installed (version: $installed_version)"
        SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
        return 0
    fi
    
    log "INFO" "Installing $package_spec..."
    if pip install "$package_spec" 2>&1 | tee -a "$LOG_FILE"; then
        local installed_version=$(get_installed_version "$package_name")
        local total_time=$(get_elapsed_time "$step_start_time")
        log "SUCCESS" "$package_name installed successfully (Version: $installed_version, Time: $total_time)"
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
        return 0
    else
        log "ERROR" "Failed to install $package_name"
        FAILED_COUNT=$((FAILED_COUNT + 1))
        FAILED_PACKAGES+=("$package_name (installation failed)")
        return 1
    fi
}

# Main installation function
main() {
    local script_start=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  Installing droidrun[google] Dependencies${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    log "INFO" "Installation started at $script_start"
    log "INFO" "Wheels directory: $WHEELS_DIR"
    log "INFO" "Log file: $LOG_FILE"
    echo ""
    
    # Phase 1: System Setup
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}Phase 1: System Setup${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    log "INFO" "Setting up environment..."
    
    # Set parallelism limits
    export NINJAFLAGS="-j2"
    export MAKEFLAGS="-j2"
    export MAX_JOBS=2
    log "INFO" "Set parallelism limits: NINJAFLAGS=$NINJAFLAGS, MAKEFLAGS=$MAKEFLAGS"
    
    # Check for gfortran symlink
    if [ ! -f "$PREFIX/bin/gfortran" ]; then
        if [ -f "$PREFIX/bin/flang" ]; then
            ln -sf "$PREFIX/bin/flang" "$PREFIX/bin/gfortran"
            log "INFO" "Created gfortran symlink to flang"
        else
            log "WARNING" "flang not found, gfortran symlink not created"
        fi
    else
        log "INFO" "gfortran symlink already exists"
    fi
    
    # Upgrade pip and build tools
    log "INFO" "Upgrading pip and build tools..."
    pip install --upgrade pip wheel build setuptools 2>&1 | tee -a "$LOG_FILE" || {
        log "WARNING" "Failed to upgrade some build tools, continuing..."
    }
    
    echo ""
    
    # Phase 2: Core Dependencies
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}Phase 2: Core Dependencies${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # 1. numpy
    install_package_with_wheel "numpy" "" || {
        log "ERROR" "CRITICAL: numpy installation failed. Cannot continue."
        exit 1
    }
    
    # 2. patchelf (try wheel first, then build if needed)
    CURRENT_STEP=$((CURRENT_STEP + 1))
    log "STEP" "patchelf - Checking for pre-built wheel"
    if ls "$WHEELS_DIR"/patchelf-*.whl 2>/dev/null | head -1 | read wheel_file; then
        log "INFO" "Found pre-built wheel: $wheel_file"
        if pip install --find-links "$WHEELS_DIR" --no-index "$wheel_file" 2>&1 | tee -a "$LOG_FILE"; then
            log "SUCCESS" "patchelf installed from pre-built wheel"
            SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
        else
            log "WARNING" "Failed to install from wheel, will try building..."
            install_package_with_wheel "patchelf" ""
        fi
    else
        log "INFO" "No pre-built wheel found, will build from source"
        install_package_with_wheel "patchelf" ""
    fi
    
    # 3. Cython
    install_pure_python_package "Cython" ">=3.0.10"
    
    # 4. meson-python
    install_pure_python_package "meson-python" "<0.19.0,>=0.16.0"
    
    echo ""
    
    # Phase 3: Scientific Computing Stack
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}Phase 3: Scientific Computing Stack${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # 5. scipy (check if already installed with correct version first)
    if is_package_installed "scipy"; then
        local scipy_version=$(get_installed_version "scipy")
        log "INFO" "scipy version $scipy_version is installed"
        # Check if version satisfies >=1.8.0,<1.17.0 using Python
        local version_check=$(python3 -c "
import sys
from packaging import version
installed = '$scipy_version'
try:
    v = version.parse(installed)
    if version.parse('1.8.0') <= v < version.parse('1.17.0'):
        print('OK')
    else:
        print('FAIL')
except:
    print('FAIL')
" 2>/dev/null || echo "FAIL")
        if [ "$version_check" = "OK" ]; then
            log "INFO" "scipy $scipy_version satisfies constraint >=1.8.0,<1.17.0 - skipping"
            SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
        else
            log "WARNING" "scipy $scipy_version may not satisfy constraint - will reinstall"
            install_package_with_wheel "scipy" ">=1.8.0,<1.17.0" || {
                log "ERROR" "CRITICAL: scipy installation failed. Cannot continue."
                exit 1
            }
        fi
    else
        install_package_with_wheel "scipy" ">=1.8.0,<1.17.0" || {
            log "ERROR" "CRITICAL: scipy installation failed. Cannot continue."
            exit 1
        }
    fi
    
    # 6. pandas (with version constraint and uninstall old version)
    CURRENT_STEP=$((CURRENT_STEP + 1))
    log "STEP" "pandas - Installing with version constraint <2.3.0"
    
    # Uninstall any existing pandas first
    if is_package_installed "pandas"; then
        local current_version=$(get_installed_version "pandas")
        log "INFO" "Uninstalling existing pandas (version: $current_version)..."
        pip uninstall -y pandas 2>/dev/null || true
    fi
    
    # Download with constraint
    cd "$WHEELS_DIR" || exit 1
    log "INFO" "Downloading pandas<2.3.0..."
    if pip download "pandas<2.3.0" --dest . --no-cache-dir 2>&1 | tee -a "$LOG_FILE"; then
        # Find the downloaded pandas file (should be 2.2.x)
        local pandas_file=$(ls -t pandas-2.2.*.tar.gz 2>/dev/null | head -1)
        if [ -z "$pandas_file" ]; then
            pandas_file=$(ls -t pandas-*.tar.gz 2>/dev/null | head -1)
        fi
        
        if [ -n "$pandas_file" ] && [ -f "$pandas_file" ]; then
            log "INFO" "Building wheel from $pandas_file..."
            local build_start=$(date +%s)
            if pip wheel --no-deps --wheel-dir . "$pandas_file" 2>&1 | tee -a "$LOG_FILE"; then
                local build_time=$(get_elapsed_time "$build_start")
                log "INFO" "Wheel built successfully (time: $build_time)"
                
                local wheel_file=$(ls -t pandas-2.2.*.whl 2>/dev/null | head -1)
                if [ -z "$wheel_file" ]; then
                    wheel_file=$(ls -t pandas-*.whl 2>/dev/null | head -1)
                fi
                
                if [ -n "$wheel_file" ] && [ -f "$wheel_file" ]; then
                    log "INFO" "Installing from wheel: $wheel_file"
                    if pip install --find-links . --no-index "$wheel_file" 2>&1 | tee -a "$LOG_FILE"; then
                        local installed_version=$(get_installed_version "pandas")
                        log "SUCCESS" "pandas installed successfully (Version: $installed_version)"
                        log "INFO" "Wheel file preserved: $wheel_file"
                        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
                    else
                        log "ERROR" "Failed to install pandas from wheel"
                        FAILED_COUNT=$((FAILED_COUNT + 1))
                        FAILED_PACKAGES+=("pandas (installation failed)")
                        exit 1
                    fi
                else
                    log "ERROR" "No wheel file found after build"
                    FAILED_COUNT=$((FAILED_COUNT + 1))
                    FAILED_PACKAGES+=("pandas (no wheel file)")
                    exit 1
                fi
            else
                log "ERROR" "Failed to build pandas wheel"
                FAILED_COUNT=$((FAILED_COUNT + 1))
                FAILED_PACKAGES+=("pandas (build failed)")
                exit 1
            fi
        else
            log "ERROR" "No pandas source file found after download"
            FAILED_COUNT=$((FAILED_COUNT + 1))
            FAILED_PACKAGES+=("pandas (download failed)")
            exit 1
        fi
    else
        log "ERROR" "Failed to download pandas"
        FAILED_COUNT=$((FAILED_COUNT + 1))
        FAILED_PACKAGES+=("pandas (download failed)")
        exit 1
    fi
    
    # 7. scikit-learn (special handling for meson build issue)
    CURRENT_STEP=$((CURRENT_STEP + 1))
    log "STEP" "scikit-learn - Installing with meson build fix"
    
    if is_package_installed "scikit-learn"; then
        local installed_version=$(get_installed_version "scikit-learn")
        log "INFO" "Package scikit-learn is already installed (version: $installed_version)"
        SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
    else
        cd "$WHEELS_DIR" || exit 1
        
        log "INFO" "Downloading scikit-learn..."
        if pip download "scikit-learn" --dest . --no-cache-dir 2>&1 | tee -a "$LOG_FILE"; then
            log "INFO" "Download completed"
            
            local source_file=$(ls -t scikit-learn-*.tar.gz 2>/dev/null | head -1)
            if [ -n "$source_file" ] && [ -f "$source_file" ]; then
                log "INFO" "Extracting source to fix meson build issue..."
                local extract_dir="$WHEELS_DIR/scikit-learn-extract-$$"
                mkdir -p "$extract_dir" || {
                    log "ERROR" "Failed to create extract directory"
                    FAILED_COUNT=$((FAILED_COUNT + 1))
                    FAILED_PACKAGES+=("scikit-learn (extract dir failed)")
                    cd "$HOME" || exit 1
                    return 1
                }
                tar -xzf "$source_file" -C "$extract_dir" 2>/dev/null || {
                    log "ERROR" "Failed to extract source"
                    rm -rf "$extract_dir"
                    FAILED_COUNT=$((FAILED_COUNT + 1))
                    FAILED_PACKAGES+=("scikit-learn (extraction failed)")
                    cd "$HOME" || exit 1
                    return 1
                }
                
                local sklearn_dir=$(ls -d "$extract_dir"/scikit-learn-* 2>/dev/null | head -1)
                if [ -n "$sklearn_dir" ] && [ -d "$sklearn_dir" ]; then
                    # Fix the version.py script to be executable and have correct shebang
                    local version_script="$sklearn_dir/sklearn/_build_utils/version.py"
                    if [ -f "$version_script" ]; then
                        log "INFO" "Fixing version.py script permissions..."
                        chmod +x "$version_script"
                        # Ensure it has Python shebang
                        if ! head -1 "$version_script" | grep -q "^#!"; then
                            sed -i '1i#!/usr/bin/env python3' "$version_script"
                        fi
                    fi
                    
                    # Recreate tarball with fixed permissions
                    log "INFO" "Recreating source tarball with fixes..."
                    cd "$extract_dir" || exit 1
                    tar -czf "$WHEELS_DIR/$source_file" "$(basename "$sklearn_dir")" 2>/dev/null || {
                        log "ERROR" "Failed to recreate tarball"
                        FAILED_COUNT=$((FAILED_COUNT + 1))
                        FAILED_PACKAGES+=("scikit-learn (tarball recreation failed)")
                        cd "$HOME" || exit 1
                        return 1
                    }
                    cd "$WHEELS_DIR" || exit 1
                fi
                # Clean up extract directory
                rm -rf "$extract_dir" 2>/dev/null || true
                
                log "INFO" "Building wheel from fixed source (this may take a while)..."
                local build_start=$(date +%s)
                
                # Set PYTHON explicitly for meson
                export PYTHON=$(which python3)
                
                if pip wheel --no-deps --wheel-dir . "$source_file" 2>&1 | tee -a "$LOG_FILE"; then
                    local build_time=$(get_elapsed_time "$build_start")
                    log "INFO" "Wheel built successfully (time: $build_time)"
                    
                    local wheel_file=$(ls -t scikit-learn-*.whl 2>/dev/null | head -1)
                    if [ -n "$wheel_file" ] && [ -f "$wheel_file" ]; then
                        log "INFO" "Installing from wheel: $wheel_file"
                        if pip install --find-links . --no-index "$wheel_file" 2>&1 | tee -a "$LOG_FILE"; then
                            local installed_version=$(get_installed_version "scikit-learn")
                            log "SUCCESS" "scikit-learn installed successfully (Version: $installed_version)"
                            log "INFO" "Wheel file preserved: $wheel_file"
                            SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
                            cd "$HOME" || exit 1
                            return 0
                        else
                            log "ERROR" "Failed to install scikit-learn from wheel"
                            FAILED_COUNT=$((FAILED_COUNT + 1))
                            FAILED_PACKAGES+=("scikit-learn (installation failed)")
                            cd "$HOME" || exit 1
                            return 1
                        fi
                    else
                        log "ERROR" "No wheel file found after build"
                        FAILED_COUNT=$((FAILED_COUNT + 1))
                        FAILED_PACKAGES+=("scikit-learn (no wheel file)")
                        cd "$HOME" || exit 1
                        return 1
                    fi
                else
                    log "ERROR" "Failed to build scikit-learn wheel"
                    FAILED_COUNT=$((FAILED_COUNT + 1))
                    FAILED_PACKAGES+=("scikit-learn (build failed)")
                    cd "$HOME" || exit 1
                    return 1
                fi
            else
                log "ERROR" "No source file found for scikit-learn"
                FAILED_COUNT=$((FAILED_COUNT + 1))
                FAILED_PACKAGES+=("scikit-learn (no source file)")
                cd "$HOME" || exit 1
                return 1
            fi
        else
            log "ERROR" "Failed to download scikit-learn"
            FAILED_COUNT=$((FAILED_COUNT + 1))
            FAILED_PACKAGES+=("scikit-learn (download failed)")
            cd "$HOME" || exit 1
            return 1
        fi
    fi
    
    echo ""
    
    # Phase 4: Rust-Based Packages
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}Phase 4: Rust-Based Packages${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # 8. maturin
    install_pure_python_package "maturin" "<2,>=1.9.4"
    
    # 9. jiter
    install_package_with_wheel "jiter" ""
    
    echo ""
    
    # Phase 5: Other Dependencies
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}Phase 5: Other Dependencies${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # 10. pyarrow
    install_package_with_wheel "pyarrow" ""
    
    # 11. psutil
    install_package_with_wheel "psutil" ""
    
    echo ""
    
    # Phase 6: Main Package
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}Phase 6: Installing droidrun[google]${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    CURRENT_STEP=$((CURRENT_STEP + 1))
    log "STEP" "droidrun[google] - Installing main package"
    
    cd "$HOME" || exit 1
    
    log "INFO" "Installing droidrun[google] using pre-built wheels..."
    if pip install 'droidrun[google]' --find-links "$WHEELS_DIR" 2>&1 | tee -a "$LOG_FILE"; then
        local installed_version=$(get_installed_version "droidrun")
        log "SUCCESS" "droidrun[google] installed successfully (Version: $installed_version)"
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
    else
        log "ERROR" "Failed to install droidrun[google]"
        FAILED_COUNT=$((FAILED_COUNT + 1))
        FAILED_PACKAGES+=("droidrun[google] (installation failed)")
    fi
    
    echo ""
    
    # Summary Report
    local script_end_time=$(date +%s)
    local total_time=$(get_elapsed_time "$SCRIPT_START_TIME")
    local wheel_count=$(ls -1 "$WHEELS_DIR"/*.whl 2>/dev/null | wc -l)
    
    echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  Installation Summary${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    log "INFO" "Total packages processed: $TOTAL_STEPS"
    log "INFO" "Successfully installed: $SUCCESS_COUNT"
    log "INFO" "Failed: $FAILED_COUNT"
    log "INFO" "Skipped: $SKIPPED_COUNT"
    log "INFO" "Total time: $total_time"
    log "INFO" "Wheel files in directory: $wheel_count"
    log "INFO" "Wheels location: $WHEELS_DIR"
    
    if [ ${#FAILED_PACKAGES[@]} -gt 0 ]; then
        echo ""
        echo -e "${RED}Failed Packages:${NC}"
        for pkg in "${FAILED_PACKAGES[@]}"; do
            echo -e "  ${RED}✗${NC} $pkg"
        done
    fi
    
    echo ""
    echo -e "${BLUE}Wheel Files Created:${NC}"
    ls -lh "$WHEELS_DIR"/*.whl 2>/dev/null | awk '{print "  " $9 " (" $5 ")"}' || echo "  No wheel files found"
    
    echo ""
    if [ $FAILED_COUNT -eq 0 ]; then
        echo -e "${GREEN}✓ All dependencies installed successfully!${NC}"
        log "INFO" "Installation completed successfully at $(date '+%Y-%m-%d %H:%M:%S')"
    else
        echo -e "${YELLOW}⚠ Installation completed with $FAILED_COUNT failure(s)${NC}"
        log "WARNING" "Installation completed with failures at $(date '+%Y-%m-%d %H:%M:%S')"
        echo ""
        echo -e "${YELLOW}Review the log file for details: $LOG_FILE${NC}"
    fi
    
    echo ""
    echo -e "${BLUE}Next Steps:${NC}"
    echo "  1. Verify installation: pip list | grep -E 'pandas|numpy|scipy|scikit-learn|jiter|droidrun'"
    echo "  2. Test imports: python -c 'import pandas, numpy, scipy, sklearn, jiter, droidrun'"
    echo "  3. Check log file: $LOG_FILE"
    echo ""
}

# Run main function
main "$@"

