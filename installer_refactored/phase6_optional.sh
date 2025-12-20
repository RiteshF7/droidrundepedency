#!/usr/bin/env bash
# Phase 6: Additional Compiled (optional)
# Installs tokenizers, safetensors, cryptography, pydantic-core, orjson

set -euo pipefail

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# Initialize logging
init_logging

log_info "=========================================="
log_info "Phase 6: Optional Packages Installation"
log_info "=========================================="

# Check if phase is already complete
if is_phase_complete "6"; then
    log_success "Phase 6 already completed (skipping)"
    exit 0
fi

# Load environment if available
load_env_vars

# Setup build environment
setup_build_environment

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
    mark_phase_complete "6"
    save_env_vars
    exit 0
fi

log_info "Installing missing optional packages: ${missing_packages[*]}"

# First, try to find and install pre-built wheels from dependencies folder
DEPENDENCIES_WHEELS_DIRS=(
    "${SCRIPT_DIR}/../depedencies/wheels"
    "${HOME}/droidrundepedency/depedencies/wheels"
    "${HOME}/depedencies/wheels"
)

for DEPENDENCIES_WHEELS_DIR in "${DEPENDENCIES_WHEELS_DIRS[@]}"; do
    if [ -d "$DEPENDENCIES_WHEELS_DIR" ]; then
        log_info "Found dependencies folder: $DEPENDENCIES_WHEELS_DIR"
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
    mark_phase_complete "6"
    save_env_vars
    exit 0
fi

# Try installing packages individually to handle failures gracefully
log_info "Attempting to install ${#packages_to_install[@]} package(s) individually..."
installed_count=0
failed_packages=()

for pkg in "${packages_to_install[@]}"; do
    log_info "Attempting to install $pkg..."
    if python3 -m pip install --find-links "$WHEELS_DIR" "$pkg" 2>&1 | tee -a "$LOG_FILE"; then
        if python_pkg_installed "$pkg" "$pkg"; then
            log_success "$pkg installed successfully"
            installed_count=$((installed_count + 1))
            continue
        fi
    fi
    log_warning "$pkg installation failed, will try building from source"
    failed_packages+=("$pkg")
done

if [ $installed_count -eq ${#packages_to_install[@]} ]; then
    log_success "Phase 6 complete: All optional packages installed (pre-built wheels)"
    mark_phase_complete "6"
    save_env_vars
    exit 0
elif [ ${#failed_packages[@]} -gt 0 ]; then
    log_info "Some packages need building from source: ${failed_packages[*]}"
    packages_to_install=("${failed_packages[@]}")
    
    built_packages=()
    
    # Build each missing package (continue on failure)
    log_info "Processing ${#packages_to_install[@]} package(s) to build from source: ${packages_to_install[*]}"
    pkg_count=0
    for pkg in "${packages_to_install[@]}"; do
        pkg_count=$((pkg_count + 1))
        log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        log_info "Processing package $pkg_count/${#packages_to_install[@]}: $pkg"
        log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        # Special handling for tokenizers - prefer pre-built wheel due to Android pthread limitations
        if [ "$pkg" = "tokenizers" ]; then
            # First try to install from pre-built wheel
            tokenizers_wheel=$(find "$WHEELS_DIR" -name "tokenizers*.whl" 2>/dev/null | head -1)
            if [ -n "$tokenizers_wheel" ] && [ -f "$tokenizers_wheel" ]; then
                log_info "Installing $pkg from pre-built wheel: $(basename "$tokenizers_wheel")"
                if python3 -m pip install --find-links "$WHEELS_DIR" --no-index "$tokenizers_wheel"; then
                    log_success "$pkg installed from pre-built wheel"
                    built_packages+=("$pkg")
                    continue
                else
                    log_warning "Failed to install $pkg from pre-built wheel, will try building from source"
                fi
            fi
            # If wheel installation failed, try building with special flags
            log_info "Building $pkg with special compiler flags for Android/Termux compatibility..."
            log_warning "NOTE: tokenizers build will likely fail on Android due to missing pthread_cond_clockwait"
            log_warning "This is expected - use pre-built wheel from dependencies folder instead"
            if build_package "$pkg" "$pkg" --env-var="CXXFLAGS=-D_GNU_SOURCE"; then
                built_packages+=("$pkg")
            else
                log_warning "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                log_warning "Skipping $pkg (build failed - pthread_cond_clockwait not available on Android)"
                log_warning "This is EXPECTED behavior on Android/Termux"
                log_warning "Solution: Use pre-built wheel from depedencies/wheels/_x86_64_wheels/tokenizers*.whl"
                log_warning "The script will continue with remaining packages..."
                log_warning "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                echo "Error details logged to: $ERROR_LOG_FILE" | tee -a "$LOG_FILE"
            fi
        else
            if build_package "$pkg" "$pkg"; then
                built_packages+=("$pkg")
            else
                log_warning "Skipping $pkg (build failed)"
                log_info "Error details should be shown above. Continuing with next package..."
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
            wheels_dir_abs=$(cd "$WHEELS_DIR" && pwd)
            cd "$HOME" && python3 -m pip install --find-links "$wheels_dir_abs" --no-index "${wheel_files[@]}" 2>/dev/null || true
        fi
    fi
    
    log_success "Phase 6 complete: Optional packages processed"
fi

mark_phase_complete "6"
save_env_vars

log_success "Phase 6 completed successfully"

