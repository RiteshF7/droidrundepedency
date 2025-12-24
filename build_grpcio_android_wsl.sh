#!/bin/bash
# Script to build grpcio wheel for Android aarch64 using NDK cross-compilation in WSL Ubuntu

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}Building grpcio wheel for Android aarch64${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# NDK path (WSL format - /mnt/c/ maps to C:\)
NDK="/mnt/c/Users/rites/AppData/Local/Android/Sdk/ndk/29.0.14206865"

# Verify NDK exists
if [ ! -d "$NDK" ]; then
    echo -e "${RED}Error: NDK not found at $NDK${NC}"
    echo -e "${YELLOW}Please verify the NDK path is correct.${NC}"
    exit 1
fi

echo -e "${GREEN}✓ NDK found at: $NDK${NC}"

# Set Android NDK environment
export ANDROID_NDK="$NDK"
export ANDROID_ABI=arm64-v8a
export ANDROID_PLATFORM=android-30
export ANDROID_API=30

# Get NDK sysroot (must be defined before CC/CXX)
NDK_SYSROOT="$NDK/toolchains/llvm/prebuilt/windows-x86_64/sysroot"
NDK_INCLUDE="$NDK_SYSROOT/usr/include"
NDK_LIB="$NDK_SYSROOT/usr/lib/aarch64-linux-android/30"

# Set cross-compiler paths (Windows toolchain - works in WSL)
# Note: We set CC/CXX as simple paths, flags go in CFLAGS
COMPILER_BASE="$NDK/toolchains/llvm/prebuilt/windows-x86_64/bin"
export CC="$COMPILER_BASE/aarch64-linux-android30-clang"
export CXX="$COMPILER_BASE/aarch64-linux-android30-clang++"
export AR="$COMPILER_BASE/llvm-ar.exe"
export STRIP="$COMPILER_BASE/llvm-strip.exe"
export RANLIB="$COMPILER_BASE/llvm-ranlib.exe"
export LD="$COMPILER_BASE/aarch64-linux-android30-ld"

# Verify compiler exists
if [ ! -f "$CC" ]; then
    echo -e "${RED}Error: Compiler not found at $CC${NC}"
    echo -e "${YELLOW}Checking for alternative toolchain paths...${NC}"
    # Try to find the toolchain
    if [ -d "$NDK/toolchains/llvm/prebuilt" ]; then
        echo "Available toolchains:"
        ls -la "$NDK/toolchains/llvm/prebuilt/" || true
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

# Android-specific compiler flags
# Use --sysroot to force use of Android NDK headers only
export CFLAGS="-U__ANDROID_API__ -D__ANDROID_API__=30 --sysroot=$NDK_SYSROOT -I$NDK_INCLUDE -I$NDK_INCLUDE/aarch64-linux-android -fPIC -target aarch64-linux-android30"
export CPPFLAGS="$CFLAGS"
export CXXFLAGS="$CFLAGS"
export LDFLAGS="--sysroot=$NDK_SYSROOT -llog -L$NDK_LIB -fuse-ld=lld -target aarch64-linux-android30"

# Set target architecture
export ARCH=arm64
export TARGET_ARCH=aarch64-linux-android

# Set Python build flags for cross-compilation
export _PYTHON_HOST_PLATFORM=linux-aarch64
export PYTHON_FOR_BUILD=python3

# Create wheels directory
WHEELS_DIR="./wheels"
mkdir -p "$WHEELS_DIR"

echo ""
echo -e "${BLUE}Build Configuration:${NC}"
echo -e "  NDK: $NDK"
echo -e "  CC: $CC"
echo -e "  CXX: $CXX"
echo -e "  Target: Android aarch64 (API 30)"
echo -e "  Output: $WHEELS_DIR"
echo ""

# Display environment variables
echo -e "${YELLOW}Environment variables:${NC}"
echo "  CFLAGS=$CFLAGS"
echo "  LDFLAGS=$LDFLAGS"
echo ""

echo -e "${GREEN}Starting build...${NC}"
echo -e "${YELLOW}This may take 10-30 minutes depending on your system.${NC}"
echo ""

# Build the wheel
pip wheel grpcio==1.76.0 \
    --no-binary=:all: \
    --no-build-isolation \
    --wheel-dir "$WHEELS_DIR" \
    --verbose 2>&1 | tee build.log

echo ""
if [ $? -eq 0 ]; then
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}✓ Build successful!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo -e "Wheel file(s) created in: ${BLUE}$WHEELS_DIR${NC}"
    ls -lh "$WHEELS_DIR"/*.whl 2>/dev/null || echo "No .whl files found"
else
    echo -e "${RED}========================================${NC}"
    echo -e "${RED}✗ Build failed!${NC}"
    echo -e "${RED}========================================${NC}"
    echo -e "Check build.log for details"
    exit 1
fi

