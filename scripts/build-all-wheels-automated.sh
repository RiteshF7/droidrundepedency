#!/data/data/com.termux/files/usr/bin/bash
# build-all-wheels-automated.sh
# Automated wheel builder for all droidrun dependencies
# Modular structure with separate scripts for each phase
#
# Flow:
# 1. Export all paths, configs, and tasks
# 2. pkg update and upgrade
# 3. Install python pip using pkg
# 4. Install all pkg dependencies in correct sequence
# 5. Detect architecture
# 6. Check pip for available wheels and install them
# 7. Build remaining packages from source
# 8. Use pip as fallback for any remaining packages
# 9. Export all wheels to wheels_${ARCH}

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_SCRIPTS_DIR="$SCRIPT_DIR/build"

# Source configuration and common functions
source "$BUILD_SCRIPTS_DIR/config.sh"
source "$BUILD_SCRIPTS_DIR/common.sh"

# Create necessary directories
mkdir -p "$WHEELS_DIR" "$EXPORT_DIR" "$SOURCES_DIR"
touch "$BUILD_LOG"

# Main function
main() {
    log "INFO" "=========================================="
    log "INFO" "Automated Wheel Builder for droidrun"
    log "INFO" "Architecture: $ARCH ($PLATFORM_TAG)"
    log "INFO" "Python: $PYTHON_VERSION ($PYTHON_TAG)"
    log "INFO" "Sources: $SOURCES_DIR"
    log "INFO" "Wheels: $WHEELS_DIR"
    log "INFO" "Export: $EXPORT_DIR"
    log "INFO" "=========================================="
    
    # Step 1: Export all paths, configs, and tasks (already done via config.sh)
    log "INFO" "Step 1: Configuration loaded"
    log "INFO" "  - Architecture: $ARCH"
    log "INFO" "  - Platform tag: $PLATFORM_TAG"
    log "INFO" "  - Python version: $PYTHON_VERSION"
    log "INFO" "  - Sources directory: $SOURCES_DIR"
    log "INFO" "  - Wheels directory: $WHEELS_DIR"
    log "INFO" "  - Export directory: $EXPORT_DIR"
    
    # Step 2 & 3: pkg update, upgrade, and install python/pip
    log "INFO" "Step 2-3: Installing system packages (update, upgrade, python, pip)..."
    source "$BUILD_SCRIPTS_DIR/install-system-deps.sh"
    install_all_system_deps
    
    # Step 4: Setup build environment
    log "INFO" "Step 4: Setting up build environment..."
    setup_build_environment
    
    # Step 5: Detect architecture (already done in config.sh)
    log "INFO" "Step 5: Architecture detected: $ARCH ($PLATFORM_TAG)"
    
    # Step 6: Check pip for available wheels and install existing wheels
    log "INFO" "Step 6: Detecting and installing available wheels..."
    source "$BUILD_SCRIPTS_DIR/detect-wheels.sh"
    
    # Get list of packages that need building
    local need_build_packages
    need_build_packages=$(detect_and_install_wheels)
    
    # Convert to array - handle both direct output and file
    local need_build_array=()
    if [ -f "$WHEELS_DIR/need_build.txt" ]; then
        while IFS= read -r line; do
            [ -n "$line" ] && need_build_array+=("$line")
        done < "$WHEELS_DIR/need_build.txt"
    else
        while IFS= read -r line; do
            [ -n "$line" ] && need_build_array+=("$line")
        done <<< "$need_build_packages"
    fi
    
    # Step 7: Build remaining packages from source
    if [ ${#need_build_array[@]} -gt 0 ]; then
        log "INFO" "Step 7: Building packages from source..."
        log "INFO" "Packages to build: ${need_build_array[*]}"
        
        source "$BUILD_SCRIPTS_DIR/build-wheels.sh"
        
        # Install build tools first
        install_build_tools
        
        # Try building from source first
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
            
            if ! build_with_deps "$pkg_name" "$version" "$constraint"; then
                failed_builds+=("$pkg_name")
            fi
        done
        
        # Step 8: Use pip as fallback for failed builds
        if [ ${#failed_builds[@]} -gt 0 ]; then
            log "INFO" "Step 8: Using pip as fallback for packages that couldn't be built..."
            log "INFO" "Packages for fallback: ${failed_builds[*]}"
            fallback_pip_install "${failed_builds[@]}"
        fi
    else
        log "INFO" "Step 7: All packages installed from wheels, no building needed"
    fi
    
    # Step 9: Export all wheels
    log "INFO" "Step 9: Exporting all wheels..."
    source "$BUILD_SCRIPTS_DIR/export-wheels.sh"
    export_all_wheels
    
    log "SUCCESS" "=========================================="
    log "SUCCESS" "Build complete!"
    log "SUCCESS" "Wheels exported to: $EXPORT_DIR"
    log "SUCCESS" "Manifest: $WHEEL_MANIFEST"
    log "SUCCESS" "Total wheels: $(ls -1 "$EXPORT_DIR"/*.whl 2>/dev/null | wc -l)"
    log "SUCCESS" "=========================================="
}

# Run main function
main "$@"
