#!/bin/bash
# Script to find and install all missing dependencies for droidrun

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WHEELS_BUILD_DIR="/tmp/wheels_build_$(date +%s)"
TERMUX_WHEELS_DIR="/data/data/com.termux/files/home/droidrun-wheels"
MAX_ITERATIONS=20
ITERATION=0

mkdir -p "$WHEELS_BUILD_DIR"

echo "=========================================="
echo "Finding and Installing Missing Dependencies"
echo "=========================================="
echo ""

# Function to extract missing module from error
extract_missing_module() {
    local error_output="$1"
    echo "$error_output" | grep -o "ModuleNotFoundError: No module named '[^']*'" | \
        sed "s/ModuleNotFoundError: No module named '//" | sed "s/'//" | head -1
}

# Function to check if module is installed
check_module_installed() {
    local module="$1"
    adb shell "run-as com.termux sh -c 'export PATH=/data/data/com.termux/files/usr/bin:\$PATH && python3 -c \"import ${module//-/_}; print(\\\"OK\\\")\" 2>&1'" | grep -q "OK" && return 0 || return 1
}

# Function to install from wheels directory
install_from_wheels() {
    local module="$1"
    adb shell "run-as com.termux sh -c 'export PATH=/data/data/com.termux/files/usr/bin:\$PATH && cd $TERMUX_WHEELS_DIR && pip3 install --no-index --find-links . \"$module\" 2>&1'" | grep -q "Successfully" && return 0 || return 1
}

# Function to build wheel on laptop
build_wheel() {
    local module="$1"
    echo "  Building wheel for $module..."
    python3 -m pip wheel --no-deps "$module" -w "$WHEELS_BUILD_DIR" 2>&1 | tail -3
    local wheel_file=$(ls "$WHEELS_BUILD_DIR/${module}"*.whl 2>/dev/null | head -1)
    if [ -n "$wheel_file" ]; then
        echo "  ✓ Wheel built: $(basename "$wheel_file")"
        return 0
    else
        echo "  ✗ Failed to build wheel"
        return 1
    fi
}

# Function to copy and install wheel in Termux
install_wheel_in_termux() {
    local wheel_file="$1"
    local module_name="$2"
    
    echo "  Copying wheel to Termux..."
    "$SCRIPT_DIR/copy_to_termux.sh" "$wheel_file" "~/$(basename "$wheel_file")" >/dev/null 2>&1
    
    echo "  Installing in Termux..."
    adb shell "run-as com.termux sh -c 'export PATH=/data/data/com.termux/files/usr/bin:\$PATH && pip3 install /data/data/com.termux/files/home/$(basename "$wheel_file") 2>&1'" | grep -q "Successfully" && return 0 || return 1
}

# Function to install from PyPI in Termux (build from source)
install_from_pypi() {
    local module="$1"
    echo "  Installing $module from PyPI (building from source)..."
    adb shell "run-as com.termux sh -c 'export PATH=/data/data/com.termux/files/usr/bin:\$PATH && pip3 install \"$module\" 2>&1'" | tail -3
    check_module_installed "$module" && return 0 || return 1
}

# Main loop
while [ $ITERATION -lt $MAX_ITERATIONS ]; do
    ITERATION=$((ITERATION + 1))
    echo "Iteration $ITERATION: Testing droidrun import..."
    
    ERROR_OUTPUT=$(adb shell "run-as com.termux sh -c 'export PATH=/data/data/com.termux/files/usr/bin:\$PATH && python3 -c \"import droidrun; print(\\\"✓ droidrun works!\\\")\" 2>&1'" 2>&1)
    
    if echo "$ERROR_OUTPUT" | grep -q "✓ droidrun works!"; then
        echo ""
        echo "=========================================="
        echo "✓ SUCCESS! droidrun is working!"
        echo "=========================================="
        exit 0
    fi
    
    MISSING_MODULE=$(extract_missing_module "$ERROR_OUTPUT")
    
    if [ -z "$MISSING_MODULE" ]; then
        echo "  No missing module found in error. Full error:"
        echo "$ERROR_OUTPUT" | tail -10
        echo ""
        echo "Stopping - cannot determine missing dependency"
        exit 1
    fi
    
    echo "  Missing module: $MISSING_MODULE"
    
    # Check if already installed
    if check_module_installed "$MISSING_MODULE"; then
        echo "  ✓ Already installed, but import failed. Checking next error..."
        continue
    fi
    
    # Try installing from wheels directory first
    if install_from_wheels "$MISSING_MODULE" 2>/dev/null; then
        echo "  ✓ Installed from wheels directory"
        continue
    fi
    
    # Try building wheel on laptop
    if build_wheel "$MISSING_MODULE"; then
        WHEEL_FILE=$(ls "$WHEELS_BUILD_DIR/${MISSING_MODULE}"*.whl 2>/dev/null | head -1)
        if install_wheel_in_termux "$WHEEL_FILE" "$MISSING_MODULE"; then
            echo "  ✓ Installed from built wheel"
            continue
        fi
    fi
    
    # Fallback: install from PyPI (build from source in Termux)
    if install_from_pypi "$MISSING_MODULE"; then
        echo "  ✓ Installed from PyPI"
        continue
    else
        echo "  ✗ Failed to install $MISSING_MODULE"
        echo "  Error output:"
        echo "$ERROR_OUTPUT" | tail -5
        exit 1
    fi
done

echo ""
echo "=========================================="
echo "✗ Reached maximum iterations ($MAX_ITERATIONS)"
echo "=========================================="
exit 1

