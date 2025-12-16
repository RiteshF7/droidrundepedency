#!/data/data/com.termux/files/usr/bin/bash
# build-wheels.sh
# Builds wheels from source files

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"
source "$SCRIPT_DIR/common.sh"

# Install system dependencies for a package
install_package_system_deps() {
    local pkg_name="$1"
    local deps="${PKG_SYSTEM_DEPS[$pkg_name]:-}"
    
    if [ -z "$deps" ]; then
        return 0
    fi
    
    log "INFO" "Installing system dependencies for $pkg_name: $deps"
    for dep in $deps; do
        pkg install -y "$dep" >> "$BUILD_LOG" 2>&1 || true
    done
    
    # Set package-specific environment variables
    case "$pkg_name" in
        scipy)
            ln -sf "$PREFIX/bin/flang" "$PREFIX/bin/gfortran" 2>/dev/null || true
            ;;
        pyarrow)
            export ARROW_HOME=$PREFIX
            ;;
        grpcio)
            export GRPC_PYTHON_BUILD_SYSTEM_OPENSSL=1
            export GRPC_PYTHON_BUILD_SYSTEM_ZLIB=1
            export GRPC_PYTHON_BUILD_SYSTEM_CARES=1
            export GRPC_PYTHON_BUILD_SYSTEM_RE2=1
            export GRPC_PYTHON_BUILD_SYSTEM_ABSL=1
            export GRPC_PYTHON_BUILD_WITH_CYTHON=1
            ;;
        pillow)
            export PKG_CONFIG_PATH=$PREFIX/lib/pkgconfig:$PKG_CONFIG_PATH
            export LDFLAGS="-L$PREFIX/lib"
            export CPPFLAGS="-I$PREFIX/include"
            ;;
    esac
}

# Download source file for a package
download_source_file() {
    local pkg_name="$1"
    local pkg_version="${2:-}"
    local pkg_constraint="${3:-}"
    
    log "INFO" "Downloading source for $pkg_name${pkg_version:+ $pkg_version}..."
    
    # Create sources directory if it doesn't exist
    mkdir -p "$SOURCES_DIR"
    
    # Build package spec
    local package_spec="$pkg_name"
    if [ -n "$pkg_constraint" ]; then
        package_spec="$pkg_name$pkg_constraint"
    elif [ -n "$pkg_version" ]; then
        package_spec="$pkg_name==$pkg_version"
    fi
    
    # Download source distribution
    local PIP_CMD=$(get_pip_cmd)
    local download_dir="$SOURCES_DIR"
    
    log "INFO" "Downloading $package_spec to $download_dir..."
    if [[ "$PIP_CMD" == *"python3 -m pip"* ]]; then
        if ! python3 -m pip download "$package_spec" --dest "$download_dir" --no-binary :all: --no-cache-dir >> "$BUILD_LOG" 2>&1; then
            # Try without --no-binary flag if that fails
            log "WARNING" "Download with --no-binary failed, trying without..."
            if ! python3 -m pip download "$package_spec" --dest "$download_dir" --no-cache-dir >> "$BUILD_LOG" 2>&1; then
                log "ERROR" "Failed to download $package_spec"
                return 1
            fi
        fi
    else
        if ! $PIP_CMD download "$package_spec" --dest "$download_dir" --no-binary :all: --no-cache-dir >> "$BUILD_LOG" 2>&1; then
            # Try without --no-binary flag if that fails
            log "WARNING" "Download with --no-binary failed, trying without..."
            if ! $PIP_CMD download "$package_spec" --dest "$download_dir" --no-cache-dir >> "$BUILD_LOG" 2>&1; then
                log "ERROR" "Failed to download $package_spec"
                return 1
            fi
        fi
    fi
    
    # Verify download - find the downloaded source file
    local source_file=$(find_source_file "$pkg_name" "$pkg_version")
    if [ -z "$source_file" ]; then
        log "WARNING" "Downloaded file not found for $pkg_name, checking all files..."
        # List what was downloaded
        ls -lh "$download_dir"/*.{tar.gz,zip} 2>/dev/null | tail -5 >> "$BUILD_LOG" || true
        return 1
    fi
    
    log "SUCCESS" "Downloaded source file: $(basename "$source_file")"
    return 0
}

# Apply fixes to source before building
apply_fixes() {
    local pkg_name="$1"
    local source_file="$2"
    local extract_dir="$3"
    
    case "$pkg_name" in
        pandas)
            log "INFO" "Applying pandas meson.build fix..."
            if [ -f "$extract_dir/meson.build" ]; then
                sed -i "s/version: run_command.*/version: '2.2.3',/" "$extract_dir/meson.build" || true
                log "SUCCESS" "Fixed pandas meson.build"
            fi
            ;;
        scikit-learn)
            log "INFO" "Applying scikit-learn fixes..."
            if [ -f "$extract_dir/sklearn/_build_utils/version.py" ]; then
                chmod +x "$extract_dir/sklearn/_build_utils/version.py"
                if ! head -1 "$extract_dir/sklearn/_build_utils/version.py" | grep -q "^#!"; then
                    sed -i '1i#!/usr/bin/env python3' "$extract_dir/sklearn/_build_utils/version.py"
                fi
            fi
            if [ -f "$extract_dir/meson.build" ]; then
                if [ -f "$extract_dir/sklearn/_build_utils/version.py" ]; then
                    local version=$(python3 "$extract_dir/sklearn/_build_utils/version.py" 2>/dev/null || echo "1.9.dev0")
                    sed -i "4s|.*|  version: '$version',|" "$extract_dir/meson.build" || true
                fi
            fi
            log "SUCCESS" "Fixed scikit-learn"
            ;;
    esac
}

# Build wheel for a package
build_wheel() {
    local pkg_name="$1"
    local pkg_version="${2:-}"
    local pkg_constraint="${3:-}"
    
    log "INFO" "Building wheel for $pkg_name${pkg_version:+ $pkg_version}..."
    
    # Check if already built
    if wheel_exists "$pkg_name" "$pkg_version"; then
        log "WARNING" "Wheel for $pkg_name already exists, skipping build"
        return 0
    fi
    
    # Create sources directory if it doesn't exist
    mkdir -p "$SOURCES_DIR"
    
    # Find source file
    local source_file=$(find_source_file "$pkg_name" "$pkg_version")
    
    # If source file not found, error out (sources should be downloaded upfront)
    if [ -z "$source_file" ]; then
        log "ERROR" "Source file not found for $pkg_name in $SOURCES_DIR"
        log "ERROR" "Please run ./install-system-deps.sh first to download all sources"
        log "INFO" "Will try pip as fallback for $pkg_name"
        return 1
    fi
    
    log "INFO" "Using source file: $(basename "$source_file")"
    
    # Install system dependencies
    install_package_system_deps "$pkg_name"
    
    # Extract and apply fixes if needed
    local temp_dir="$WHEELS_DIR/tmp_${pkg_name}_$$"
    mkdir -p "$temp_dir"
    
    if [[ "$source_file" == *.tar.gz ]]; then
        tar -xzf "$source_file" -C "$temp_dir" || {
            log "ERROR" "Failed to extract $source_file"
            rm -rf "$temp_dir"
            return 1
        }
    elif [[ "$source_file" == *.zip ]]; then
        unzip -q "$source_file" -d "$temp_dir" || {
            log "ERROR" "Failed to extract $source_file"
            rm -rf "$temp_dir"
            return 1
        }
    fi
    
    local extract_dir=$(ls -d "$temp_dir"/*/ 2>/dev/null | head -1 || echo "$temp_dir")
    
    # Apply fixes
    apply_fixes "$pkg_name" "$source_file" "$extract_dir"
    
    # Repackage if fixes were applied
    if [ "$pkg_name" = "pandas" ] || [ "$pkg_name" = "scikit-learn" ]; then
        cd "$temp_dir"
        local fixed_source="$WHEELS_DIR/$(basename "$source_file" | sed 's/\.tar\.gz$/-fixed.tar.gz/')"
        if [[ "$source_file" == *.tar.gz ]]; then
            tar -czf "$fixed_source" "$(basename "$extract_dir")" || {
                log "ERROR" "Failed to repackage $pkg_name"
                cd - > /dev/null
                rm -rf "$temp_dir"
                return 1
            }
        fi
        source_file="$fixed_source"
        cd - > /dev/null
    fi
    
    # Build wheel
    local build_flags="--no-deps --wheel-dir $WHEELS_DIR"
    local PIP_CMD=$(get_pip_cmd)
    
    # Special build flags for certain packages
    case "$pkg_name" in
        scikit-learn)
            build_flags="$build_flags --no-build-isolation"
            ;;
        grpcio)
            build_flags="$build_flags --no-build-isolation"
            ;;
    esac
    
    # Build from source file
    if [ -f "$source_file" ]; then
        if [[ "$PIP_CMD" == *"python3 -m pip"* ]]; then
            python3 -m pip wheel "$source_file" $build_flags >> "$BUILD_LOG" 2>&1 || {
                log "ERROR" "Failed to build wheel for $pkg_name"
                rm -rf "$temp_dir"
                return 1
            }
        else
            $PIP_CMD wheel "$source_file" $build_flags >> "$BUILD_LOG" 2>&1 || {
                log "ERROR" "Failed to build wheel for $pkg_name"
                rm -rf "$temp_dir"
                return 1
            }
        fi
    else
        cd "$extract_dir"
        if [[ "$PIP_CMD" == *"python3 -m pip"* ]]; then
            python3 -m pip wheel . $build_flags >> "$BUILD_LOG" 2>&1 || {
                log "ERROR" "Failed to build wheel for $pkg_name"
                cd - > /dev/null
                rm -rf "$temp_dir"
                return 1
            }
        else
            $PIP_CMD wheel . $build_flags >> "$BUILD_LOG" 2>&1 || {
                log "ERROR" "Failed to build wheel for $pkg_name"
                cd - > /dev/null
                rm -rf "$temp_dir"
                return 1
            }
        fi
        cd - > /dev/null
    fi
    
    # Special post-build fixes
    case "$pkg_name" in
        grpcio)
            log "INFO" "Applying grpcio wheel patch..."
            local wheel_file=$(ls "$WHEELS_DIR/grpcio-"*"${PLATFORM_TAG}.whl" 2>/dev/null | head -1)
            if [ -n "$wheel_file" ] && command -v patchelf >/dev/null 2>&1; then
                local grpcio_extract="$WHEELS_DIR/grpcio_extract_$$"
                unzip -q "$wheel_file" -d "$grpcio_extract"
                local so_file=$(find "$grpcio_extract" -name "cygrpc*.so" | head -1)
                if [ -n "$so_file" ]; then
                    patchelf --add-needed libabsl_flags_internal.so "$so_file" 2>/dev/null || true
                    patchelf --add-needed libabsl_flags.so "$so_file" 2>/dev/null || true
                    patchelf --add-needed libabsl_flags_commandlineflag.so "$so_file" 2>/dev/null || true
                    patchelf --add-needed libabsl_flags_reflection.so "$so_file" 2>/dev/null || true
                    patchelf --set-rpath "$PREFIX/lib" "$so_file" 2>/dev/null || true
                    
                    cd "$grpcio_extract"
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
                    cd - > /dev/null
                    mv "$WHEELS_DIR/grpcio-fixed.whl" "$wheel_file"
                    rm -rf "$grpcio_extract"
                    log "SUCCESS" "Patched grpcio wheel"
                fi
            fi
            ;;
    esac
    
    # Cleanup
    rm -rf "$temp_dir"
    
    # Install the wheel
    local built_wheel=$(ls "$WHEELS_DIR/${pkg_name}-"*"${PLATFORM_TAG}.whl" 2>/dev/null | head -1)
    if [ -n "$built_wheel" ]; then
        log "INFO" "Installing $pkg_name from wheel..."
        local PIP_CMD=$(get_pip_cmd)
        if [[ "$PIP_CMD" == *"python3 -m pip"* ]]; then
            python3 -m pip install --find-links "$WHEELS_DIR" --no-index "$built_wheel" >> "$BUILD_LOG" 2>&1 || {
                log "WARNING" "Failed to install $pkg_name, continuing..."
            }
        else
            $PIP_CMD install --find-links "$WHEELS_DIR" --no-index "$built_wheel" >> "$BUILD_LOG" 2>&1 || {
                log "WARNING" "Failed to install $pkg_name, continuing..."
            }
        fi
    fi
    
    log "SUCCESS" "Built and installed wheel for $pkg_name"
    return 0
}

# Build package and its dependencies
build_with_deps() {
    local pkg_name="$1"
    local pkg_version="${2:-}"
    local pkg_constraint="${3:-}"
    
    # Get transitive dependencies
    local deps="${PYTHON_TRANSITIVE_DEPS[$pkg_name]:-}"
    
    # Build dependencies first
    if [ -n "$deps" ]; then
        for dep in $deps; do
            if ! wheel_exists "$dep" && ! is_package_installed "$dep"; then
                log "INFO" "Building transitive dependency: $dep"
                build_with_deps "$dep" "" ""
            else
                log "INFO" "Transitive dependency $dep already available"
            fi
        done
    fi
    
    # Build the package itself
    build_wheel "$pkg_name" "$pkg_version" "$pkg_constraint"
}

# Install build tools (called separately)
install_build_tools() {
    log "INFO" "Installing build tools..."
    local PIP_CMD=$(get_pip_cmd)
    
    if [[ "$PIP_CMD" == *"python3 -m pip"* ]]; then
        python3 -m pip install --upgrade pip wheel setuptools >> "$BUILD_LOG" 2>&1 || true
        python3 -m pip install Cython "meson-python<0.19.0,>=0.16.0" "maturin<2,>=1.9.4" >> "$BUILD_LOG" 2>&1 || {
            log "ERROR" "Failed to install build tools"
            return 1
        }
    else
        $PIP_CMD install --upgrade pip wheel setuptools >> "$BUILD_LOG" 2>&1 || true
        $PIP_CMD install Cython "meson-python<0.19.0,>=0.16.0" "maturin<2,>=1.9.4" >> "$BUILD_LOG" 2>&1 || {
            log "ERROR" "Failed to install build tools"
            return 1
        }
    fi
    
    log "SUCCESS" "Build tools installed"
}

# Fallback to pip install for packages that couldn't be built
fallback_pip_install() {
    local packages_to_install=("$@")
    
    log "INFO" "=========================================="
    log "INFO" "Fallback: Installing remaining packages via pip"
    log "INFO" "=========================================="
    
    local PIP_CMD=$(get_pip_cmd)
    
    for pkg_name in "${packages_to_install[@]}"; do
        if [ -z "$pkg_name" ]; then
            continue
        fi
        
        if is_package_installed "$pkg_name"; then
            log "INFO" "$pkg_name is already installed, skipping"
            continue
        fi
        
        local constraint="${PYTHON_PACKAGES[$pkg_name]:-}"
        local spec="$pkg_name"
        if [ -n "$constraint" ]; then
            spec="$pkg_name$constraint"
        fi
        
        log "INFO" "Installing $spec via pip (fallback)..."
        
        if [[ "$PIP_CMD" == *"python3 -m pip"* ]]; then
            python3 -m pip install "$spec" >> "$BUILD_LOG" 2>&1 || {
                log "WARNING" "Failed to install $spec via pip"
            }
        else
            $PIP_CMD install "$spec" >> "$BUILD_LOG" 2>&1 || {
                log "WARNING" "Failed to install $spec via pip"
            }
        fi
    done
    
    log "SUCCESS" "Fallback installation complete"
}

# Run if executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    build_packages_from_source "$@"
fi

