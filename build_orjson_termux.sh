#!/bin/bash
# Build orjson wheel using Termux build system for Android x86_64

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TERMUX_PACKAGES_DIR="$SCRIPT_DIR/termux-packages"

if [ ! -d "$TERMUX_PACKAGES_DIR" ]; then
    echo "Error: termux-packages directory not found at $TERMUX_PACKAGES_DIR"
    exit 1
fi

cd "$TERMUX_PACKAGES_DIR"

# Set architecture to x86_64
export TERMUX_ARCH=x86_64

# Set NDK path - try common locations
if [ -z "$NDK" ]; then
    # Try to find NDK in common locations
    if [ -d "$HOME/lib/android-ndk-r28c" ]; then
        export NDK="$HOME/lib/android-ndk-r28c"
    elif [ -d "$HOME/Android/Sdk/ndk/r26b" ]; then
        export NDK="$HOME/Android/Sdk/ndk/r26b"
    elif [ -d "$HOME/Android/Sdk/ndk/29.0.14206865" ]; then
        export NDK="$HOME/Android/Sdk/ndk/29.0.14206865"
    elif [ -n "$ANDROID_NDK" ]; then
        export NDK="$ANDROID_NDK"
    else
        echo "Error: NDK not found. Please set NDK or ANDROID_NDK environment variable"
        echo "Or install NDK to: $HOME/lib/android-ndk-r28c"
        exit 1
    fi
fi

echo "Using NDK: $NDK"
echo "Building orjson for Android x86_64 using Termux build system..."
echo ""

./build-package.sh python-orjson

# Find the built wheel
WHEEL_DIR="$TERMUX_PACKAGES_DIR/output"
if [ -d "$WHEEL_DIR" ]; then
    echo ""
    echo "=========================================="
    echo "Build complete! Looking for wheel..."
    echo "=========================================="
    find "$WHEEL_DIR" -name "orjson*.whl" -type f
    echo ""
    echo "Wheel location: $WHEEL_DIR"
else
    echo "Output directory not found. Check build logs."
fi

