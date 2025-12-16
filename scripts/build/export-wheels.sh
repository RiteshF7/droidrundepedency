#!/data/data/com.termux/files/usr/bin/bash
# export-wheels.sh
# Exports all built wheels to wheels_${ARCH} directory

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"
source "$SCRIPT_DIR/common.sh"

# Export all wheels
export_all_wheels() {
    log "INFO" "=========================================="
    log "INFO" "Exporting all wheels to $EXPORT_DIR"
    log "INFO" "=========================================="
    
    # Create export directory
    mkdir -p "$EXPORT_DIR"
    
    # Copy wheels from WHEELS_DIR
    local wheel_count=0
    if [ -d "$WHEELS_DIR" ]; then
        while IFS= read -r wheel; do
            if [[ "$wheel" == *"${PLATFORM_TAG}.whl" ]]; then
                cp "$wheel" "$EXPORT_DIR/" 2>/dev/null && {
                    wheel_count=$((wheel_count + 1))
                    log "INFO" "Exported: $(basename "$wheel")"
                }
            fi
        done < <(find "$WHEELS_DIR" -name "*.whl" 2>/dev/null)
    fi
    
    # Also check project wheels directories
    local project_wheels_dir="$PROJECT_ROOT/depedencies/wheels"
    if [ "$ARCH" = "aarch64" ] && [ -d "$project_wheels_dir/arch64_wheels" ]; then
        while IFS= read -r wheel; do
            if [[ "$wheel" == *"${PLATFORM_TAG}.whl" ]]; then
                local wheel_name=$(basename "$wheel")
                if [ ! -f "$EXPORT_DIR/$wheel_name" ]; then
                    cp "$wheel" "$EXPORT_DIR/" 2>/dev/null && {
                        wheel_count=$((wheel_count + 1))
                        log "INFO" "Exported: $wheel_name"
                    }
                fi
            fi
        done < <(find "$project_wheels_dir/arch64_wheels" -name "*.whl" 2>/dev/null)
    elif [ "$ARCH" = "x86_64" ] && [ -d "$project_wheels_dir/_x86_64_wheels" ]; then
        while IFS= read -r wheel; do
            if [[ "$wheel" == *"${PLATFORM_TAG}.whl" ]]; then
                local wheel_name=$(basename "$wheel")
                if [ ! -f "$EXPORT_DIR/$wheel_name" ]; then
                    cp "$wheel" "$EXPORT_DIR/" 2>/dev/null && {
                        wheel_count=$((wheel_count + 1))
                        log "INFO" "Exported: $wheel_name"
                    }
                fi
            fi
        done < <(find "$project_wheels_dir/_x86_64_wheels" -name "*.whl" 2>/dev/null)
    fi
    
    # Create manifest
    log "INFO" "Creating wheel manifest..."
    {
        echo "# Wheel Manifest for $ARCH"
        echo "# Generated: $(date)"
        echo "# Python: $PYTHON_VERSION"
        echo "# Platform: $PLATFORM_TAG"
        echo ""
        echo "## Built Wheels:"
        ls -1 "$EXPORT_DIR"/*.whl 2>/dev/null | while read -r wheel; do
            echo "  - $(basename "$wheel")"
        done
        echo ""
        echo "## Total Wheels: $(ls -1 "$EXPORT_DIR"/*.whl 2>/dev/null | wc -l)"
    } > "$WHEEL_MANIFEST"
    
    log "SUCCESS" "Exported $wheel_count wheels to $EXPORT_DIR"
    log "SUCCESS" "Manifest created: $WHEEL_MANIFEST"
    
    # List all exported wheels
    local total_wheels=$(ls -1 "$EXPORT_DIR"/*.whl 2>/dev/null | wc -l)
    log "INFO" "Total wheels in export directory: $total_wheels"
}

# Run if executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    export_all_wheels
fi

