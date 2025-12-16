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

# Main function
main() {
    log "INFO" "=========================================="
    log "INFO" "Building packages from source"
    log "INFO" "Architecture: $ARCH ($PLATFORM_TAG)"
    log "INFO" "Sources directory: $SOURCES_DIR"
    log "INFO" "=========================================="
    
    # Create sources directory if it doesn't exist
    mkdir -p "$SOURCES_DIR"
    
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
    
    # Try building from source
    local failed_builds=()
    for pkg_name in "${need_build_array[@]}"; do
        if [ -z "$pkg_name" ]; then
            continue
        fi
        
        # Skip if already installed
        if is_package_installed "$pkg_name"; then
            log "INFO" "$pkg_name is already installed, skipping build"
            continue
        fi
        
        local constraint="${PYTHON_PACKAGES[$pkg_name]:-}"
        local version=""
        
        # Extract version from constraint if it's ==
        if [[ "$constraint" == ==* ]]; then
            version="${constraint#==}"
        fi
        
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
        
        log "INFO" "Building $pkg_name${version:+ $version}..."
        if ! build_with_deps "$pkg_name" "$version" "$constraint"; then
            log "WARNING" "Failed to build $pkg_name, will try pip fallback"
            failed_builds+=("$pkg_name")
        fi
    done
    
    # Use pip as fallback for failed builds
    if [ ${#failed_builds[@]} -gt 0 ]; then
        log "INFO" "=========================================="
        log "INFO" "Using pip as fallback for packages that couldn't be built"
        log "INFO" "Packages for fallback: ${failed_builds[*]}"
        log "INFO" "=========================================="
        fallback_pip_install "${failed_builds[@]}"
    else
        log "SUCCESS" "All packages built successfully!"
    fi
    
    log "SUCCESS" "=========================================="
    log "SUCCESS" "Build process complete!"
    log "SUCCESS" "Built wheels are in: $WHEELS_DIR"
    log "SUCCESS" "=========================================="
}

# Run main function
main "$@"

