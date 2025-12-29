#!/bin/bash
# Script to build grpcio wheel for Android x86_64 using NDK cross-compilation on Ubuntu

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}Building grpcio wheel for Android x86_64${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# NDK path (Linux/Ubuntu format)
# Update this path to match your Android NDK installation
NDK="${ANDROID_NDK:-$HOME/Android/Sdk/ndk/29.0.14206865}"

# Alternative common locations
if [ ! -d "$NDK" ]; then
    NDK="${ANDROID_NDK:-/opt/android-ndk}"
fi

if [ ! -d "$NDK" ]; then
    NDK="${ANDROID_NDK:-$HOME/android-ndk}"
fi

# Verify NDK exists
if [ ! -d "$NDK" ]; then
    echo -e "${RED}Error: NDK not found at $NDK${NC}"
    echo -e "${YELLOW}Please set ANDROID_NDK environment variable or update the NDK path in the script.${NC}"
    echo -e "${YELLOW}Common locations:${NC}"
    echo -e "  - \$HOME/Android/Sdk/ndk/<version>"
    echo -e "  - /opt/android-ndk"
    echo -e "  - \$HOME/android-ndk"
    exit 1
fi

echo -e "${GREEN}✓ NDK found at: $NDK${NC}"

# Set Android NDK environment
export ANDROID_NDK="$NDK"
export ANDROID_ABI=x86_64
export ANDROID_PLATFORM=android-30
export ANDROID_API=30

# Get NDK sysroot (Linux toolchain)
# Try to detect the toolchain directory
TOOLCHAIN_BASE="$NDK/toolchains/llvm/prebuilt"
if [ -d "$TOOLCHAIN_BASE/linux-x86_64" ]; then
    TOOLCHAIN_DIR="linux-x86_64"
elif [ -d "$TOOLCHAIN_BASE/linux-x86" ]; then
    TOOLCHAIN_DIR="linux-x86"
else
    echo -e "${YELLOW}Warning: Could not detect toolchain directory, trying linux-x86_64${NC}"
    TOOLCHAIN_DIR="linux-x86_64"
fi

NDK_SYSROOT="$NDK/toolchains/llvm/prebuilt/$TOOLCHAIN_DIR/sysroot"
NDK_INCLUDE="$NDK_SYSROOT/usr/include"
NDK_LIB="$NDK_SYSROOT/usr/lib/x86_64-linux-android/30"

# Verify sysroot exists
if [ ! -d "$NDK_SYSROOT" ]; then
    echo -e "${RED}Error: NDK sysroot not found at $NDK_SYSROOT${NC}"
    echo -e "${YELLOW}Available toolchains:${NC}"
    ls -la "$NDK/toolchains/llvm/prebuilt/" 2>/dev/null || true
    exit 1
fi

# Set cross-compiler paths (Linux toolchain)
COMPILER_BASE="$NDK/toolchains/llvm/prebuilt/$TOOLCHAIN_DIR/bin"
export CC="$COMPILER_BASE/x86_64-linux-android30-clang"
export CXX="$COMPILER_BASE/x86_64-linux-android30-clang++"
export AR="$COMPILER_BASE/llvm-ar"
export STRIP="$COMPILER_BASE/llvm-strip"
export RANLIB="$COMPILER_BASE/llvm-ranlib"
export LD="$COMPILER_BASE/x86_64-linux-android30-ld"

# Verify compiler exists
if [ ! -f "$CC" ]; then
    echo -e "${RED}Error: Compiler not found at $CC${NC}"
    echo -e "${YELLOW}Checking for alternative toolchain paths...${NC}"
    if [ -d "$NDK/toolchains/llvm/prebuilt" ]; then
        echo "Available toolchains:"
        ls -la "$NDK/toolchains/llvm/prebuilt/" || true
        echo ""
        echo "Available compilers in $COMPILER_BASE:"
        ls -la "$COMPILER_BASE"/*clang* 2>/dev/null | head -10 || true
    fi
    exit 1
fi

echo -e "${GREEN}✓ Compiler found: $CC${NC}"

# Set grpcio build flags
export GRPC_PYTHON_DISABLE_LIBC_COMPATIBILITY=1
export GRPC_PYTHON_BUILD_SYSTEM_OPENSSL=1
export GRPC_PYTHON_BUILD_SYSTEM_ZLIB=1
export GRPC_PYTHON_BUILD_SYSTEM_CARES=1
export GRPC_PYTHON_BUILD_SYSTEM_RE2=1
export GRPC_PYTHON_BUILD_SYSTEM_ABSL=1
export GRPC_PYTHON_BUILD_WITH_CYTHON=1

# Android-specific compiler flags for x86_64
# Completely isolate from host system - use only NDK headers
# -nostdinc prevents system includes, --sysroot sets Android sysroot
export CFLAGS="-U__ANDROID_API__ -D__ANDROID_API__=30 --sysroot=$NDK_SYSROOT -nostdinc -isystem $NDK_INCLUDE -isystem $NDK_INCLUDE/x86_64-linux-android -isystem $NDK_SYSROOT/usr/include/c++/v1 -fPIC -target x86_64-linux-android30"
export CPPFLAGS="$CFLAGS"
export CXXFLAGS="$CFLAGS -nostdinc++ -isystem $NDK_SYSROOT/usr/include/c++/v1"
export LDFLAGS="--sysroot=$NDK_SYSROOT -llog -L$NDK_LIB -fuse-ld=lld -target x86_64-linux-android30"

# Set target architecture
export ARCH=x86_64
export TARGET_ARCH=x86_64-linux-android

# Set Python build flags for cross-compilation
export _PYTHON_HOST_PLATFORM=linux-x86_64
export PYTHON_FOR_BUILD=python3

# Create wheels directory
WHEELS_DIR="./wheels"
mkdir -p "$WHEELS_DIR"

echo ""
echo -e "${BLUE}Build Configuration:${NC}"
echo -e "  NDK: $NDK"
echo -e "  Toolchain: $TOOLCHAIN_DIR"
echo -e "  CC: $CC"
echo -e "  CXX: $CXX"
echo -e "  Target: Android x86_64 (API 30)"
echo -e "  Output: $WHEELS_DIR"
echo ""

# Display environment variables
echo -e "${YELLOW}Environment variables:${NC}"
echo "  ANDROID_NDK=$ANDROID_NDK"
echo "  ANDROID_ABI=$ANDROID_ABI"
echo "  ANDROID_PLATFORM=$ANDROID_PLATFORM"
echo "  ARCH=$ARCH"
echo "  TARGET_ARCH=$TARGET_ARCH"
echo "  CFLAGS=$CFLAGS"
echo "  LDFLAGS=$LDFLAGS"
echo ""

# Verify Python is available
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}Error: python3 not found${NC}"
    exit 1
fi

# Check and install pip if needed
if ! python3 -m pip --version &> /dev/null; then
    echo -e "${YELLOW}pip not found, installing...${NC}"
    # Try to install pip using ensurepip
    if python3 -m ensurepip --upgrade 2>/dev/null; then
        echo -e "${GREEN}✓ pip installed via ensurepip${NC}"
    else
        # Download and install pip
        PIP_SCRIPT="/tmp/get-pip.py"
        if [ ! -f "$PIP_SCRIPT" ]; then
            echo -e "${YELLOW}Downloading get-pip.py...${NC}"
            wget -q https://bootstrap.pypa.io/get-pip.py -O "$PIP_SCRIPT" || {
                echo -e "${RED}Failed to download get-pip.py${NC}"
                exit 1
            }
        fi
        python3 "$PIP_SCRIPT" --user --break-system-packages 2>&1 | grep -E "(Successfully|Installing)" || {
            echo -e "${RED}Failed to install pip${NC}"
            exit 1
        }
        export PATH="$HOME/.local/bin:$PATH"
        echo -e "${GREEN}✓ pip installed${NC}"
    fi
fi

# Verify pip is now available
if ! python3 -m pip --version &> /dev/null; then
    echo -e "${RED}Error: pip installation failed${NC}"
    exit 1
fi

# Install build dependencies if needed
echo -e "${BLUE}Checking build dependencies...${NC}"
python3 -m pip install --user --break-system-packages --quiet setuptools wheel Cython build 2>&1 | grep -E "(Successfully|Requirement|already satisfied)" || true

echo -e "${GREEN}Starting build...${NC}"
echo -e "${YELLOW}This may take 10-30 minutes depending on your system.${NC}"
echo ""

# Build the wheel
# Use python3 -m pip to ensure we're using the correct pip
# Set PATH to include local bin directory
export PATH="$HOME/.local/bin:$PATH"

echo -e "${GREEN}Building grpcio wheel...${NC}"
echo -e "${YELLOW}This may take 10-30 minutes depending on your system.${NC}"
echo ""

# Build with proper error handling and output capture
python3 -m pip wheel grpcio==1.76.0 \
    --no-binary=:all: \
    --no-build-isolation \
    --wheel-dir "$WHEELS_DIR" \
    --verbose 2>&1 | tee build.log

BUILD_EXIT_CODE=${PIPESTATUS[0]}

BUILD_EXIT_CODE=${PIPESTATUS[0]}

echo ""
if [ $BUILD_EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}✓ Build successful!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo -e "Wheel file(s) created in: ${BLUE}$WHEELS_DIR${NC}"
    ls -lh "$WHEELS_DIR"/*.whl 2>/dev/null || echo "No .whl files found"
    echo ""
    echo -e "${GREEN}Next steps:${NC}"
    echo -e "  1. Transfer the wheel file to your Android device"
    echo -e "  2. Install it using: pip install <wheel_file>"
else
    echo -e "${RED}========================================${NC}"
    echo -e "${RED}✗ Build failed!${NC}"
    echo -e "${RED}========================================${NC}"
    echo -e "Check build.log for details"
    exit 1
fi

