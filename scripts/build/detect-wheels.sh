#!/data/data/com.termux/files/usr/bin/bash
# detect-wheels.sh
# Detects available wheels from pip and existing wheel files
# Installs wheels that are available and don't need building

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"
source "$SCRIPT_DIR/common.sh"

# Check if pip has a wheel available for current architecture
check_pip_wheel_available() {
    local pkg_name="$1"
    local pkg_version="${2:-}"
    local constraint="${3:-}"
    
    local PIP_CMD=$(get_pip_cmd)
    local spec="$pkg_name"
    
    if [ -n "$pkg_version" ]; then
        spec="$pkg_name==$pkg_version"
    elif [ -n "$constraint" ]; then
        spec="$pkg_name$constraint"
    fi
    
    # Try to download wheel only (no source)
    local temp_dir=$(mktemp -d)
    local result=1
    
    if [[ "$PIP_CMD" == *"python3 -m pip"* ]]; then
        if python3 -m pip download --only-binary=:all: --platform "$PLATFORM_TAG" \
            --python-version "$PYTHON_VERSION" --dest "$temp_dir" "$spec" \
            >/dev/null 2>&1; then
            result=0
        fi
    else
        if $PIP_CMD download --only-binary=:all: --platform "$PLATFORM_TAG" \
            --python-version "$PYTHON_VERSION" --dest "$temp_dir" "$spec" \
            >/dev/null 2>&1; then
            result=0
        fi
    fi
    
    rm -rf "$temp_dir"
    return $result
}

# Get dependencies for a package using pip show
get_package_dependencies() {
    local pkg_name="$1"
    local PIP_CMD=$(get_pip_cmd)
    local deps=""
    
    # Try to get dependencies from pip show
    if [[ "$PIP_CMD" == *"python3 -m pip"* ]]; then
        deps=$(python3 -m pip show "$pkg_name" 2>/dev/null | grep "^Requires:" | cut -d: -f2 | tr ',' '\n' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//' | cut -d' ' -f1)
    else
        deps=$($PIP_CMD show "$pkg_name" 2>/dev/null | grep "^Requires:" | cut -d: -f2 | tr ',' '\n' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//' | cut -d' ' -f1)
    fi
    
    echo "$deps"
}

# Find existing wheel files in project directories
find_existing_wheels() {
    local pkg_name="$1"
    local found_wheels=()
    
    # Check in project wheels directories
    local project_wheels_dir="$PROJECT_ROOT/depedencies/wheels"
    
    if [ "$ARCH" = "aarch64" ]; then
        local arch_dir="$project_wheels_dir/arch64_wheels"
        if [ -d "$arch_dir" ]; then
            while IFS= read -r wheel; do
                if [[ "$wheel" == *"$pkg_name"* ]] && [[ "$wheel" == *"${PLATFORM_TAG}.whl" ]]; then
                    found_wheels+=("$wheel")
                fi
            done < <(find "$arch_dir" -name "*.whl" 2>/dev/null)
        fi
    elif [ "$ARCH" = "x86_64" ]; then
        local arch_dir="$project_wheels_dir/_x86_64_wheels"
        if [ -d "$arch_dir" ]; then
            while IFS= read -r wheel; do
                if [[ "$wheel" == *"$pkg_name"* ]] && [[ "$wheel" == *"${PLATFORM_TAG}.whl" ]]; then
                    found_wheels+=("$wheel")
                fi
            done < <(find "$arch_dir" -name "*.whl" 2>/dev/null)
        fi
    fi
    
    # Check in WHEELS_DIR
    if [ -d "$WHEELS_DIR" ]; then
        while IFS= read -r wheel; do
            if [[ "$wheel" == *"$pkg_name"* ]] && [[ "$wheel" == *"${PLATFORM_TAG}.whl" ]]; then
                found_wheels+=("$wheel")
            fi
        done < <(find "$WHEELS_DIR" -name "*.whl" 2>/dev/null)
    fi
    
    # Check in EXPORT_DIR
    if [ -d "$EXPORT_DIR" ]; then
        while IFS= read -r wheel; do
            if [[ "$wheel" == *"$pkg_name"* ]] && [[ "$wheel" == *"${PLATFORM_TAG}.whl" ]]; then
                found_wheels+=("$wheel")
            fi
        done < <(find "$EXPORT_DIR" -name "*.whl" 2>/dev/null)
    fi
    
    printf '%s\n' "${found_wheels[@]}"
}

# Install wheel from file
install_wheel_file() {
    local wheel_file="$1"
    local PIP_CMD=$(get_pip_cmd)
    
    log "INFO" "Installing wheel: $(basename "$wheel_file")"
    
    if [[ "$PIP_CMD" == *"python3 -m pip"* ]]; then
        python3 -m pip install --no-deps "$wheel_file" >> "$BUILD_LOG" 2>&1
    else
        $PIP_CMD install --no-deps "$wheel_file" >> "$BUILD_LOG" 2>&1
    fi
}

# Install package from pip if wheel is available
install_from_pip_if_available() {
    local pkg_name="$1"
    local constraint="${2:-}"
    local PIP_CMD=$(get_pip_cmd)
    
    local spec="$pkg_name"
    if [ -n "$constraint" ]; then
        spec="$pkg_name$constraint"
    fi
    
    log "INFO" "Checking if pip has wheel for $spec..."
    
    if check_pip_wheel_available "$pkg_name" "" "$constraint"; then
        log "INFO" "Installing $spec from pip (wheel available)..."
        
        if [[ "$PIP_CMD" == *"python3 -m pip"* ]]; then
            python3 -m pip install "$spec" >> "$BUILD_LOG" 2>&1
        else
            $PIP_CMD install "$spec" >> "$BUILD_LOG" 2>&1
        fi
        
        if [ $? -eq 0 ]; then
            log "SUCCESS" "Installed $spec from pip"
            return 0
        else
            log "WARNING" "Failed to install $spec from pip"
            return 1
        fi
    else
        log "INFO" "No wheel available for $spec on pip, will need to build"
        return 1
    fi
}

# Detect and install available wheels
detect_and_install_wheels() {
    log "INFO" "=========================================="
    log "INFO" "Detecting and installing available wheels"
    log "INFO" "Architecture: $ARCH ($PLATFORM_TAG)"
    log "INFO" "=========================================="
    
    local installed_packages=()
    local need_build=()
    
    # First, check for existing wheel files and install them
    log "INFO" "Checking for existing wheel files..."
    for pkg_name in "${!PYTHON_PACKAGES[@]}"; do
        local constraint="${PYTHON_PACKAGES[$pkg_name]}"
        
        # Skip if already installed
        if is_package_installed "$pkg_name"; then
            log "INFO" "$pkg_name is already installed, skipping"
            installed_packages+=("$pkg_name")
            continue
        fi
        
        # Check for existing wheel files
        local existing_wheels=$(find_existing_wheels "$pkg_name")
        if [ -n "$existing_wheels" ]; then
            local first_wheel=$(echo "$existing_wheels" | head -1)
            log "INFO" "Found existing wheel for $pkg_name: $(basename "$first_wheel")"
            if install_wheel_file "$first_wheel"; then
                installed_packages+=("$pkg_name")
                # Copy wheel to WHEELS_DIR for tracking
                mkdir -p "$WHEELS_DIR"
                cp "$first_wheel" "$WHEELS_DIR/" 2>/dev/null || true
                continue
            fi
        fi
        
        # Check if pip has wheel available
        if install_from_pip_if_available "$pkg_name" "$constraint"; then
            installed_packages+=("$pkg_name")
        else
            need_build+=("$pkg_name")
        fi
    done
    
    # Install transitive dependencies for installed packages
    log "INFO" "Installing transitive dependencies..."
    for pkg_name in "${installed_packages[@]}"; do
        local deps="${PYTHON_TRANSITIVE_DEPS[$pkg_name]:-}"
        if [ -n "$deps" ]; then
            for dep in $deps; do
                if ! is_package_installed "$dep"; then
                    log "INFO" "Installing transitive dependency: $dep"
                    install_from_pip_if_available "$dep" "" || true
                fi
            done
        fi
    done
    
    log "SUCCESS" "Wheel detection complete"
    log "INFO" "Installed packages: ${#installed_packages[@]}"
    log "INFO" "Packages needing build: ${#need_build[@]}"
    
    # Store need_build array in a file for retrieval
    local need_build_file="$WHEELS_DIR/need_build.txt"
    printf '%s\n' "${need_build[@]}" > "$need_build_file"
    
    # Return list of packages that need building
    printf '%s\n' "${need_build[@]}"
}

# Run if executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    detect_and_install_wheels
fi

