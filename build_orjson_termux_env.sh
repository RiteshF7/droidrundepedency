#!/bin/bash
# Build orjson wheel using Termux-style build environment for Android x86_64

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ANDROID_SDK="/media/trex/92e387d0-6ebf-4985-9602-95ad507642c3/home/trex/Android/Sdk"

# Find NDK in SDK
NDK_PATH=""
for ndk_dir in "$ANDROID_SDK/ndk"/*; do
    if [ -d "$ndk_dir" ]; then
        NDK_PATH="$ndk_dir"
        break
    fi
done

if [ -z "$NDK_PATH" ]; then
    echo "Error: Could not find NDK in $ANDROID_SDK/ndk"
    exit 1
fi

export ANDROID_HOME="$ANDROID_SDK"
export NDK="$NDK_PATH"
export TERMUX_ARCH=x86_64

# Get Python version
PYTHON_VERSION=$(python3 --version 2>&1 | awk '{print $2}' | cut -d. -f1,2)
PYTHON_INTERPRETER="python${PYTHON_VERSION}"

echo "Using Android SDK: $ANDROID_SDK"
echo "Using NDK: $NDK"
echo "Architecture: $TERMUX_ARCH"
echo "Python: $PYTHON_INTERPRETER"
echo ""

# Setup NDK toolchain paths
TOOLCHAIN_BASE="$NDK/toolchains/llvm/prebuilt"
if [ -d "$TOOLCHAIN_BASE/linux-x86_64" ]; then
    TOOLCHAIN_DIR="linux-x86_64"
elif [ -d "$TOOLCHAIN_BASE/linux-x86" ]; then
    TOOLCHAIN_DIR="linux-x86"
else
    echo "Error: Could not find toolchain in $TOOLCHAIN_BASE"
    exit 1
fi

NDK_SYSROOT="$TOOLCHAIN_BASE/$TOOLCHAIN_DIR/sysroot"
COMPILER_BASE="$TOOLCHAIN_BASE/$TOOLCHAIN_DIR/bin"

export CC="$COMPILER_BASE/x86_64-linux-android30-clang"
export CXX="$COMPILER_BASE/x86_64-linux-android30-clang++"
export AR="$COMPILER_BASE/llvm-ar"
export STRIP="$COMPILER_BASE/llvm-strip"
export RANLIB="$COMPILER_BASE/llvm-ranlib"

# Setup Rust for Android x86_64
export CARGO_BUILD_TARGET="x86_64-linux-android"
export CARGO_TARGET_X86_64_LINUX_ANDROID_LINKER="$CC"
export CC_x86_64_linux_android="$CC"
export AR_x86_64_linux_android="$AR"

# Create Cargo config
CARGO_CONFIG_DIR="$HOME/.cargo"
mkdir -p "$CARGO_CONFIG_DIR"
CARGO_CONFIG="$CARGO_CONFIG_DIR/config.toml"

if [ ! -f "$CARGO_CONFIG" ] || ! grep -q "x86_64-linux-android" "$CARGO_CONFIG" 2>/dev/null; then
    cat >> "$CARGO_CONFIG" << EOF

[target.x86_64-linux-android]
linker = "$CC"
ar = "$AR"
EOF
fi

# Ensure Rust Android target is installed
if command -v rustup &> /dev/null; then
    if ! rustup target list --installed 2>/dev/null | grep -q "x86_64-linux-android"; then
        echo "Installing Rust Android x86_64 target..."
        rustup target add x86_64-linux-android
    fi
fi

# Create output directory
WHEELS_DIR="$SCRIPT_DIR/wheels"
mkdir -p "$WHEELS_DIR"

# Download orjson source directly from PyPI
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

ORJSON_VERSION="3.11.5"
ORJSON_TAR="$TEMP_DIR/orjson-${ORJSON_VERSION}.tar.gz"

echo "Downloading orjson source from PyPI..."
if ! wget -q "https://files.pythonhosted.org/packages/source/o/orjson/orjson-${ORJSON_VERSION}.tar.gz" -O "$ORJSON_TAR"; then
    echo "Error: Failed to download orjson source"
    exit 1
fi

ORJSON_SRC_DIR="$TEMP_DIR/orjson-src"
mkdir -p "$ORJSON_SRC_DIR"
tar -xzf "$ORJSON_TAR" -C "$ORJSON_SRC_DIR" --strip-components=1

echo "Building orjson wheel for Android x86_64..."
cd "$ORJSON_SRC_DIR"

# Build with maturin
echo "Building with maturin (target: x86_64-linux-android, interpreter: $PYTHON_INTERPRETER)..."
python3 -m maturin build \
    --release \
    --target x86_64-linux-android \
    --out "$WHEELS_DIR" \
    --interpreter "$PYTHON_INTERPRETER" \
    --skip-auditwheel

echo ""
echo "=========================================="
echo "Build complete!"
echo "=========================================="
echo "Wheel location: $WHEELS_DIR"
find "$WHEELS_DIR" -name "orjson*.whl" -type f
