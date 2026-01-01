#!/bin/bash
# Build all droidrun wheels for Android x86_64

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REQUIREMENTS_FILE="${1:-/tmp/droidrun_requirements_full.txt}"
WHEELS_DIR="${2:-/tmp/droidrun_wheels_android}"
TERMUX_PACKAGES_DIR="$SCRIPT_DIR/termux-packages"

echo "=========================================="
echo "Building Droidrun Wheels for Android x86_64"
echo "=========================================="
echo ""
echo "Requirements file: $REQUIREMENTS_FILE"
echo "Wheels output: $WHEELS_DIR"
echo ""

mkdir -p "$WHEELS_DIR"

# Check if requirements file exists
if [ ! -f "$REQUIREMENTS_FILE" ]; then
    echo "Error: Requirements file not found: $REQUIREMENTS_FILE"
    exit 1
fi

# Count total packages
TOTAL_PKGS=$(grep -v "^#" "$REQUIREMENTS_FILE" | grep -v "^$" | wc -l)
echo "Total packages to process: $TOTAL_PKGS"
echo ""

# Packages that need special handling (native extensions)
NATIVE_PACKAGES=(
    "pydantic-core"
    "numpy"
    "pandas"
    "scipy"
    "cryptography"
    "orjson"
    "jiter"
)

# Function to check if package is native
is_native_package() {
    local pkg="$1"
    for native in "${NATIVE_PACKAGES[@]}"; do
        if [[ "$pkg" == "$native"* ]]; then
            return 0
        fi
    done
    return 1
}

# Function to build wheel using Termux build system
build_with_termux() {
    local pkg_name="$1"
    echo "  Building $pkg_name using Termux build system..."
    
    # Check if package exists in termux-packages
    if [ -d "$TERMUX_PACKAGES_DIR/packages/$pkg_name" ]; then
        cd "$TERMUX_PACKAGES_DIR"
        sudo -E ./build-package.sh -a x86_64 -I -f "$pkg_name" 2>&1 | tail -5
        if [ -f "output/${pkg_name}"*.deb ]; then
            echo "  ✓ Built .deb for $pkg_name"
            return 0
        fi
    fi
    return 1
}

# Function to build pure Python wheel
build_pure_python_wheel() {
    local pkg_spec="$1"
    local pkg_name=$(echo "$pkg_spec" | cut -d'=' -f1 | cut -d'@' -f1 | tr '[:upper:]' '[:lower:]' | sed 's/-/_/g')
    
    echo "  Building pure Python wheel: $pkg_spec"
    
    # Try to build wheel
    python3 -m pip wheel --no-deps "$pkg_spec" -w "$WHEELS_DIR" 2>&1 | tail -3
    
    # Check if wheel was created
    if ls "$WHEELS_DIR/${pkg_name}"*.whl 2>/dev/null | head -1 >/dev/null; then
        echo "  ✓ Wheel built: $(ls "$WHEELS_DIR/${pkg_name}"*.whl 2>/dev/null | head -1 | xargs basename)"
        return 0
    else
        echo "  ✗ Failed to build wheel"
        return 1
    fi
}

# Process requirements file
SUCCESS=0
FAILED=0
SKIPPED=0

while IFS= read -r line || [ -n "$line" ]; do
    # Skip comments and empty lines
    [[ "$line" =~ ^#.*$ ]] && continue
    [[ -z "$line" ]] && continue
    
    # Extract package name and version
    pkg_spec="$line"
    pkg_name=$(echo "$pkg_spec" | cut -d'=' -f1 | cut -d'@' -f1 | tr '[:upper:]' '[:lower:]')
    
    echo "[$((SUCCESS + FAILED + SKIPPED + 1))/$TOTAL_PKGS] Processing: $pkg_spec"
    
    # Check if already built
    if ls "$WHEELS_DIR/${pkg_name}"*.whl 2>/dev/null | head -1 >/dev/null; then
        echo "  ⊙ Already exists, skipping"
        SKIPPED=$((SKIPPED + 1))
        continue
    fi
    
    # Check if it's a native package
    if is_native_package "$pkg_name"; then
        echo "  ⊙ Native package - will need Termux build system or build from source in Termux"
        SKIPPED=$((SKIPPED + 1))
        continue
    fi
    
    # Try building pure Python wheel
    if build_pure_python_wheel "$pkg_spec"; then
        SUCCESS=$((SUCCESS + 1))
    else
        FAILED=$((FAILED + 1))
        echo "  ⚠ Failed to build, will need to install from source in Termux"
    fi
    
    echo ""
done < "$REQUIREMENTS_FILE"

echo ""
echo "=========================================="
echo "Build Summary"
echo "=========================================="
echo "✓ Successfully built: $SUCCESS"
echo "✗ Failed: $FAILED"
echo "⊙ Skipped (native/already exists): $SKIPPED"
echo "Total wheels in $WHEELS_DIR: $(ls -1 "$WHEELS_DIR"/*.whl 2>/dev/null | wc -l)"
echo ""
echo "Wheels directory: $WHEELS_DIR"
echo ""

