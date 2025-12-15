#!/bin/bash
# build-droidrun-wheels.sh - Build droidrun wheels on Termux emulator
# This script will be run via SSH connection

set -e

PACKAGE='droidrun[google]'
WHEELS_DIR=~/wheels
ARCH=$(uname -m)

echo "=== Building $PACKAGE wheels on Termux ==="
echo "Architecture: $ARCH"
echo "Working directory: $WHEELS_DIR"
echo ""

# Create wheels directory
mkdir -p "$WHEELS_DIR"
cd "$WHEELS_DIR" || exit 1

# Update packages
echo "Step 1: Updating package list..."
pkg update -y || echo "Warning: pkg update failed, continuing..."

# Install Python and build tools
echo ""
echo "Step 2: Installing Python and build tools..."
pkg install -y python python-pip || {
    echo "Error: Failed to install Python packages"
    exit 1
}

# Upgrade pip and install build tools
echo ""
echo "Step 3: Installing build tools..."
pip install --upgrade pip wheel build setuptools || {
    echo "Warning: Some build tools may have failed to install"
}

# Download and build wheels
echo ""
echo "Step 4: Downloading $PACKAGE and all dependencies..."
pip download "$PACKAGE" \
    --dest . \
    --prefer-binary \
    --no-cache-dir \
    --no-deps=false 2>&1 | tail -20

echo ""
echo "Step 5: Building wheels from source distributions if needed..."
BUILT=0
FAILED=0

for src in *.tar.gz; do
    if [ -f "$src" ]; then
        wheel_file="${src%.tar.gz}.whl"
        if [ ! -f "$wheel_file" ]; then
            echo "Building wheel for: $(basename "$src")"
            if pip wheel --no-deps --wheel-dir . "$src" 2>&1 | grep -E "Successfully|Building|ERROR" | head -3; then
                BUILT=$((BUILT + 1))
            else
                echo "  ⚠️  Failed or skipped: $src"
                FAILED=$((FAILED + 1))
            fi
        fi
    fi
done

# Summary
echo ""
echo "=== Build Summary ==="
WHEEL_COUNT=$(find . -maxdepth 1 -name "*.whl" 2>/dev/null | wc -l || echo "0")
SOURCE_COUNT=$(find . -maxdepth 1 -name "*.tar.gz" 2>/dev/null | wc -l || echo "0")
TOTAL_SIZE=$(du -sh . 2>/dev/null | awk '{print $1}' || echo "unknown")

echo "✅ Total wheels: $WHEEL_COUNT"
echo "📦 Source packages: $SOURCE_COUNT"
echo "💾 Total size: $TOTAL_SIZE"
echo "🏗️  Built from source: $BUILT"
echo "❌ Failed builds: $FAILED"
echo ""
echo "Wheels location: $WHEELS_DIR"
echo ""
echo "Architecture: $ARCH"
echo ""
echo "✅ Build complete! Wheels are ready to copy."




