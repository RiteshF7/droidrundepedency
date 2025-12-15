#!/data/data/com.termux/files/usr/bin/bash
# build-all-dependencies.sh
# Builds ALL dependencies from dependency manifest in correct order
# Applies all fixes from termux-build-errors-and-solutions.md
# Designed to run on Android device in Termux

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST_FILE="${1:-$HOME/dependency-manifest.json}"
WHEELS_DIR="${WHEELS_DIR:-$HOME/wheels}"
BUILD_LOG="$WHEELS_DIR/build-all.log"
BUILD_REPORT="$WHEELS_DIR/build-report.json"
STATUS_FILE="$WHEELS_DIR/build-status.json"

# Set parallelism limits to prevent memory exhaustion
export NINJAFLAGS="-j2"
export MAKEFLAGS="-j2"
export MAX_JOBS=2

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Create directories
mkdir -p "$WHEELS_DIR"
touch "$BUILD_LOG"

log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local log_entry="[$timestamp] [$level] $message"
    
    echo "$log_entry" >> "$BUILD_LOG"
    
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
    esac
}

# Load build status
load_build_status() {
    if [ -f "$STATUS_FILE" ]; then
        cat "$STATUS_FILE"
    else
        echo "{}"
    fi
}

# Save build status using utility script
save_build_status() {
    local pkg_name="$1"
    local status="$2"
    local error_msg="${3:-}"
    
    case "$status" in
        "built")
            "$SCRIPT_DIR/utils/build-status.sh" mark-built "$pkg_name"
            ;;
        "failed")
            "$SCRIPT_DIR/utils/build-status.sh" mark-failed "$pkg_name" "$error_msg"
            ;;
        "skipped")
            "$SCRIPT_DIR/utils/build-status.sh" mark-skipped "$pkg_name"
            ;;
    esac
}

# Check if package is already built
is_package_built() {
    local pkg_name="$1"
    local pkg_version="$2"
    
    # Check for wheel file
    if ls "$WHEELS_DIR/${pkg_name}-"*.whl 2>/dev/null | grep -q .; then
        return 0
    fi
    
    # Check build status using utility
    if "$SCRIPT_DIR/utils/build-status.sh" is-built "$pkg_name" | grep -q "yes"; then
        return 0
    fi
    
    return 1
}

# Apply pandas meson.build fix
fix_pandas_meson() {
    local source_dir="$1"
    local version="$2"
    
    log "INFO" "Applying pandas meson.build version fix..."
    
    cd "$source_dir" || return 1
    
    # Fix meson.build line 5 (0-indexed line 4)
    python3 <<PYTHON_FIX
with open('meson.build', 'r') as f:
    lines = f.readlines()

# Find version line and replace
for i, line in enumerate(lines):
    if 'version:' in line and 'run_command' in line:
        lines[i] = f"    version: '$version',\n"
        break

with open('meson.build', 'w') as f:
    f.writelines(lines)
print("Fixed meson.build")
PYTHON_FIX
    
    log "SUCCESS" "Pandas meson.build fixed"
}

# Apply scikit-learn version.py fix
fix_scikit_learn_version() {
    local source_dir="$1"
    
    log "INFO" "Applying scikit-learn version.py fixes..."
    
    cd "$source_dir" || return 1
    
    local version_py="sklearn/_build_utils/version.py"
    if [ -f "$version_py" ]; then
        # Fix permissions
        chmod +x "$version_py"
        
        # Add shebang if missing
        if ! head -1 "$version_py" | grep -q "^#!"; then
            sed -i "1i#!/usr/bin/env python3" "$version_py"
        fi
        
        log "SUCCESS" "scikit-learn version.py fixed"
    else
        log "WARNING" "version.py not found, skipping fix"
    fi
}

# Build a single package
build_package() {
    local pkg_name="$1"
    local pkg_version="$2"
    local constraint="$3"
    local special_fixes="$4"
    local build_reqs="$5"
    
    log "INFO" "Building $pkg_name $pkg_version..."
    
    # Check if already built
    if is_package_built "$pkg_name" "$pkg_version"; then
        log "INFO" "$pkg_name already built, skipping"
        save_build_status "$pkg_name" "skipped"
        return 0
    fi
    
    cd "$WHEELS_DIR" || return 1
    
    # Install build requirements if needed
    if [ -n "$build_reqs" ]; then
        log "INFO" "Installing build requirements: $build_reqs"
        # Parse and install system packages
        for req in $build_reqs; do
            if ! pkg list-installed | grep -q "^$req "; then
                pkg install -y "$req" 2>&1 | tee -a "$BUILD_LOG" || log "WARNING" "Failed to install $req"
            fi
        done
    fi
    
    # Download source
    local package_spec="$pkg_name"
    if [ -n "$constraint" ]; then
        package_spec="$pkg_name$constraint"
    elif [ -n "$pkg_version" ]; then
        package_spec="$pkg_name==$pkg_version"
    fi
    
    log "INFO" "Downloading $package_spec..."
    if ! pip download "$package_spec" --dest . --no-cache-dir 2>&1 | tee -a "$BUILD_LOG"; then
        log "ERROR" "Failed to download $package_spec"
        save_build_status "$pkg_name" "failed"
        return 1
    fi
    
    # Find source file
    local source_file=$(ls -t ${pkg_name}-*.tar.gz ${pkg_name}-*.zip 2>/dev/null | head -1)
    
    if [ -z "$source_file" ] || [ ! -f "$source_file" ]; then
        log "ERROR" "No source file found for $pkg_name"
        save_build_status "$pkg_name" "failed"
        return 1
    fi
    
    # Apply special fixes before building
    if echo "$special_fixes" | grep -q "meson_build_version_fix"; then
        # Extract source for pandas fix
        local extract_dir="$WHEELS_DIR/${pkg_name}-extract"
        rm -rf "$extract_dir"
        mkdir -p "$extract_dir"
        
        if [[ "$source_file" == *.tar.gz ]]; then
            tar -xzf "$source_file" -C "$extract_dir" --strip-components=1 2>/dev/null || \
            tar -xzf "$source_file" -C "$extract_dir"
        elif [[ "$source_file" == *.zip ]]; then
            unzip -q "$source_file" -d "$extract_dir"
            # Move contents up one level if needed
            if [ $(ls -1 "$extract_dir" | wc -l) -eq 1 ]; then
                mv "$extract_dir"/*/* "$extract_dir/" 2>/dev/null || true
            fi
        fi
        
        # Find meson.build
        local meson_build=$(find "$extract_dir" -name "meson.build" | head -1)
        if [ -n "$meson_build" ]; then
            fix_pandas_meson "$(dirname "$meson_build")" "$pkg_version"
            # Recreate tarball
            cd "$extract_dir"
            tar -czf "$WHEELS_DIR/${pkg_name}-${pkg_version}-fixed.tar.gz" . 2>/dev/null || \
            zip -r "$WHEELS_DIR/${pkg_name}-${pkg_version}-fixed.zip" . 2>/dev/null
            source_file="${pkg_name}-${pkg_version}-fixed.tar.gz"
            if [ ! -f "$WHEELS_DIR/$source_file" ]; then
                source_file="${pkg_name}-${pkg_version}-fixed.zip"
            fi
            cd "$WHEELS_DIR"
        fi
    fi
    
    if echo "$special_fixes" | grep -q "version_py"; then
        # Extract for scikit-learn fix
        local extract_dir="$WHEELS_DIR/${pkg_name}-extract"
        if [ ! -d "$extract_dir" ]; then
            rm -rf "$extract_dir"
            mkdir -p "$extract_dir"
            
            if [[ "$source_file" == *.tar.gz ]]; then
                tar -xzf "$source_file" -C "$extract_dir" --strip-components=1 2>/dev/null || \
                tar -xzf "$source_file" -C "$extract_dir"
            elif [[ "$source_file" == *.zip ]]; then
                unzip -q "$source_file" -d "$extract_dir"
            fi
        fi
        
        fix_scikit_learn_version "$extract_dir"
        
        # Recreate tarball if needed
        if [ ! -f "$WHEELS_DIR/${pkg_name}-${pkg_version}-fixed.tar.gz" ]; then
            cd "$extract_dir"
            tar -czf "$WHEELS_DIR/${pkg_name}-${pkg_version}-fixed.tar.gz" . 2>/dev/null || \
            zip -r "$WHEELS_DIR/${pkg_name}-${pkg_version}-fixed.zip" . 2>/dev/null
            source_file="${pkg_name}-${pkg_version}-fixed.tar.gz"
            if [ ! -f "$WHEELS_DIR/$source_file" ]; then
                source_file="${pkg_name}-${pkg_version}-fixed.zip"
            fi
            cd "$WHEELS_DIR"
        fi
    fi
    
    # Build wheel
    log "INFO" "Building wheel from $source_file (this may take a while)..."
    local build_start=$(date +%s)
    
    # Special handling for grpcio (needs --no-build-isolation)
    local build_flags=""
    if [ "$pkg_name" = "grpcio" ]; then
        build_flags="--no-build-isolation"
        export GRPC_PYTHON_BUILD_SYSTEM_OPENSSL=1
        export GRPC_PYTHON_BUILD_SYSTEM_ZLIB=1
        export GRPC_PYTHON_BUILD_SYSTEM_CARES=1
        export GRPC_PYTHON_BUILD_SYSTEM_RE2=1
        export GRPC_PYTHON_BUILD_SYSTEM_ABSL=1
        export GRPC_PYTHON_BUILD_WITH_CYTHON=1
    fi
    
    if pip wheel --no-deps --wheel-dir . $build_flags "$source_file" 2>&1 | tee -a "$BUILD_LOG"; then
        local build_time=$(($(date +%s) - build_start))
        log "SUCCESS" "Built $pkg_name in ${build_time}s"
        save_build_status "$pkg_name" "built"
        
        # Verify wheel exists
        if ls "$WHEELS_DIR/${pkg_name}-"*.whl 2>/dev/null | grep -q .; then
            log "SUCCESS" "Wheel verified: $(ls -1 "$WHEELS_DIR/${pkg_name}-"*.whl | head -1)"
            return 0
        else
            log "WARNING" "Build succeeded but wheel not found"
        fi
    else
        log "ERROR" "Failed to build $pkg_name"
        save_build_status "$pkg_name" "failed"
        return 1
    fi
    
    return 1
}

# Main build process
main() {
    log "INFO" "Starting build process..."
    log "INFO" "Manifest: $MANIFEST_FILE"
    log "INFO" "Wheels directory: $WHEELS_DIR"
    
    if [ ! -f "$MANIFEST_FILE" ]; then
        log "ERROR" "Manifest file not found: $MANIFEST_FILE"
        exit 1
    fi
    
    # Parse manifest and build packages in order
    python3 <<PYTHON_BUILD
import json
import sys

with open("$MANIFEST_FILE", "r") as f:
    manifest = json.load(f)

packages = manifest.get("packages", [])
# Sort by build_order
packages.sort(key=lambda x: x.get("build_order", 999))

print(f"Building {len(packages)} packages in order...", file=sys.stderr)

for pkg in packages:
    pkg_name = pkg.get("name")
    pkg_version = pkg.get("version", "unknown")
    constraint = pkg.get("constraint", "")
    fixes = ",".join(pkg.get("special_fixes", []))
    system_reqs = " ".join(pkg.get("build_requirements", {}).get("system", []))
    
    # Output in format: name|version|constraint|fixes|system_reqs
    print(f"{pkg_name}|{pkg_version}|{constraint}|{fixes}|{system_reqs}")

PYTHON_BUILD | while IFS='|' read -r pkg_name pkg_version constraint fixes system_reqs; do
    [ -z "$pkg_name" ] && continue
    build_package "$pkg_name" "$pkg_version" "$constraint" "$fixes" "$system_reqs" || {
        log "ERROR" "Failed to build $pkg_name, continuing with next package..."
    }
done
    
    log "SUCCESS" "Build process complete!"
    log "INFO" "Build log: $BUILD_LOG"
    log "INFO" "Wheels directory: $WHEELS_DIR"
    
    # Generate final report
    "$SCRIPT_DIR/utils/build-status.sh" report "$MANIFEST_FILE"
    "$SCRIPT_DIR/utils/build-status.sh" progress "$MANIFEST_FILE"
}

# Run main if script is executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi

