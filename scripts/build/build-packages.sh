#!/data/data/com.termux/files/usr/bin/bash
# build-packages.sh
# Builds packages from source that were detected as needing build
# This script reads from need_build.txt and builds each package

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source configuration and common functions
source "$SCRIPT_DIR/config.sh"
source "$SCRIPT_DIR/common.sh"
source "$SCRIPT_DIR/build-wheels.sh"
source "$SCRIPT_DIR/detect-wheels.sh"

# Main function
main() {
    log "INFO" "=========================================="
    log "INFO" "Building packages from source"
    log "INFO" "Architecture: $ARCH ($PLATFORM_TAG)"
    log "INFO" "Sources directory: $SOURCES_DIR"
    log "INFO" "=========================================="
    
    # Verify sources directory exists and has files
    if [ ! -d "$SOURCES_DIR" ]; then
        log "ERROR" "Sources directory does not exist: $SOURCES_DIR"
        log "ERROR" "Please run ./install-system-deps.sh first to download and extract sources"
        exit 1
    fi
    
    # Check if sources directory has any source files
    local source_count=$(find "$SOURCES_DIR" -maxdepth 1 -type f \( -name "*.tar.gz" -o -name "*.zip" \) 2>/dev/null | wc -l)
    if [ "$source_count" -eq 0 ]; then
        log "WARNING" "Sources directory is empty: $SOURCES_DIR"
        log "WARNING" "No source files found. Please run ./install-system-deps.sh to download sources"
        log "WARNING" "Continuing anyway, but builds may fail if sources are missing..."
    else
        log "INFO" "Found $source_count source files in $SOURCES_DIR"
    fi
    
    # Check if need_build.txt exists
    local need_build_file="$WHEELS_DIR/need_build.txt"
    if [ ! -f "$need_build_file" ]; then
        log "ERROR" "need_build.txt not found at $need_build_file"
        log "INFO" "Please run detect-wheels.sh first to generate the list"
        exit 1
    fi
    
    # Read packages that need building
    local need_build_array=()
    while IFS= read -r line; do
        [ -n "$line" ] && need_build_array+=("$line")
    done < "$need_build_file"
    
    if [ ${#need_build_array[@]} -eq 0 ]; then
        log "INFO" "No packages need building"
        exit 0
    fi
    
    log "INFO" "Packages to build: ${#need_build_array[@]}"
    log "INFO" "Package list: ${need_build_array[*]}"
    
    # Install build tools first (if not already installed)
    log "INFO" "Installing/upgrading build tools..."
    install_build_tools
    
    # Process packages with priority: existing wheel -> pip wheel -> source -> error
    local failed_packages=()
    local error_packages=()
    
    for pkg_name in "${need_build_array[@]}"; do
        if [ -z "$pkg_name" ]; then
            continue
        fi
        
        # Skip if already installed
        if is_package_installed "$pkg_name"; then
            log "INFO" "$pkg_name is already installed, skipping"
            continue
        fi
        
        local constraint="${PYTHON_PACKAGES[$pkg_name]:-}"
        local version=""
        
        # Extract version from constraint if it's ==
        if [[ "$constraint" == ==* ]]; then
            version="${constraint#==}"
        fi
        
        log "INFO" "Processing $pkg_name${version:+ $version}..."
        
        # Priority 1: Check if wheel already exists locally
        if wheel_exists "$pkg_name" "$version"; then
            log "INFO" "Wheel already exists for $pkg_name, installing from local wheel"
            # Install the existing wheel
            local existing_wheel=$(ls "$WHEELS_DIR/${pkg_name}-"*"${PLATFORM_TAG}.whl" 2>/dev/null | head -1)
            if [ -z "$existing_wheel" ]; then
                existing_wheel=$(ls "$EXPORT_DIR/${pkg_name}-"*"${PLATFORM_TAG}.whl" 2>/dev/null | head -1)
            fi
            if [ -n "$existing_wheel" ]; then
                log "INFO" "Installing $pkg_name from existing wheel: $(basename "$existing_wheel")"
                local PIP_CMD=$(get_pip_cmd)
                if [[ "$PIP_CMD" == *"python3 -m pip"* ]]; then
                    python3 -m pip install --find-links "$WHEELS_DIR" --no-index "$existing_wheel" >> "$BUILD_LOG" 2>&1 || {
                        log "ERROR" "Failed to install $pkg_name from existing wheel"
                        failed_packages+=("$pkg_name")
                    }
                else
                    $PIP_CMD install --find-links "$WHEELS_DIR" --no-index "$existing_wheel" >> "$BUILD_LOG" 2>&1 || {
                        log "ERROR" "Failed to install $pkg_name from existing wheel"
                        failed_packages+=("$pkg_name")
                    }
                fi
            fi
            continue
        fi
        
        # Priority 2: Check if wheel is available on pip server
        log "INFO" "Checking if wheel is available on pip server for $pkg_name..."
        if check_pip_wheel_available "$pkg_name" "$version" "$constraint"; then
            log "INFO" "Wheel available on pip server, installing $pkg_name from pip"
            local PIP_CMD=$(get_pip_cmd)
            local package_spec="$pkg_name"
            if [ -n "$constraint" ]; then
                package_spec="$pkg_name$constraint"
            elif [ -n "$version" ]; then
                package_spec="$pkg_name==$version"
            fi
            
            if [[ "$PIP_CMD" == *"python3 -m pip"* ]]; then
                python3 -m pip install "$package_spec" >> "$BUILD_LOG" 2>&1 || {
                    log "ERROR" "Failed to install $pkg_name from pip"
                    failed_packages+=("$pkg_name")
                }
            else
                $PIP_CMD install "$package_spec" >> "$BUILD_LOG" 2>&1 || {
                    log "ERROR" "Failed to install $pkg_name from pip"
                    failed_packages+=("$pkg_name")
                }
            fi
            continue
        fi
        
        # Priority 3: Check if source file is available in directory
        log "INFO" "No wheel available on pip server, checking for source file..."
        local source_file=$(find_source_file "$pkg_name" "$version")
        if [ -n "$source_file" ] && [ -f "$source_file" ]; then
            log "INFO" "Source file found for $pkg_name: $(basename "$source_file")"
            
            # Special handling for scikit-learn dependencies
            if [ "$pkg_name" = "scikit-learn" ]; then
                log "INFO" "Installing scikit-learn dependencies..."
                local PIP_CMD=$(get_pip_cmd)
                if [[ "$PIP_CMD" == *"python3 -m pip"* ]]; then
                    python3 -m pip install "joblib>=1.3.0" "threadpoolctl>=3.2.0" >> "$BUILD_LOG" 2>&1 || true
                else
                    $PIP_CMD install "joblib>=1.3.0" "threadpoolctl>=3.2.0" >> "$BUILD_LOG" 2>&1 || true
                fi
            fi
            
            log "INFO" "Building $pkg_name from source..."
            if build_with_deps "$pkg_name" "$version" "$constraint"; then
                log "SUCCESS" "Successfully built $pkg_name from source"
                continue
            else
                log "ERROR" "Failed to build $pkg_name from source"
                failed_packages+=("$pkg_name")
            fi
        else
            # Priority 4: No source file available - ERROR
            log "ERROR" "=========================================="
            log "ERROR" "No source file found for $pkg_name in $SOURCES_DIR"
            log "ERROR" "Source file is required but not available"
            log "ERROR" "Please ensure source.7z is extracted to $SOURCES_DIR"
            log "ERROR" "=========================================="
            error_packages+=("$pkg_name")
        fi
    done
    
    # Report results
    if [ ${#error_packages[@]} -gt 0 ]; then
        log "ERROR" "=========================================="
        log "ERROR" "Build failed: Missing source files"
        log "ERROR" "Packages with missing sources: ${error_packages[*]}"
        log "ERROR" "Please run ./install-system-deps.sh to download sources"
        log "ERROR" "=========================================="
        exit 1
    fi
    
    if [ ${#failed_packages[@]} -gt 0 ]; then
        log "WARNING" "=========================================="
        log "WARNING" "Some packages failed to install/build"
        log "WARNING" "Failed packages: ${failed_packages[*]}"
        log "WARNING" "=========================================="
    else
        log "SUCCESS" "All packages processed successfully!"
    fi
    
    log "SUCCESS" "=========================================="
    log "SUCCESS" "Build process complete!"
    log "SUCCESS" "Built wheels are in: $WHEELS_DIR"
    log "SUCCESS" "=========================================="
}

# Run main function
main "$@"

