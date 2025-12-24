#!/bin/bash
# Script to build grpcio wheel for Android aarch64 using NDK cross-compilation

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Setting up Android NDK cross-compilation environment...${NC}"

# NDK path (Windows format for Git Bash)
NDK="/c/Users/rites/AppData/Local/Android/Sdk/ndk/29.0.14206865"

# Verify NDK exists
if [ ! -d "$NDK" ]; then
    echo -e "${RED}Error: NDK not found at $NDK${NC}"
    exit 1
fi

# Set Android NDK environment
export ANDROID_NDK="$NDK"
export ANDROID_ABI=arm64-v8a
export ANDROID_PLATFORM=android-30
export ANDROID_API=30

# Set cross-compiler paths
export CC="$NDK/toolchains/llvm/prebuilt/windows-x86_64/bin/aarch64-linux-android30-clang"
export CXX="$NDK/toolchains/llvm/prebuilt/windows-x86_64/bin/aarch64-linux-android30-clang++"
export AR="$NDK/toolchains/llvm/prebuilt/windows-x86_64/bin/llvm-ar"
export STRIP="$NDK/toolchains/llvm/prebuilt/windows-x86_64/bin/llvm-strip"
export RANLIB="$NDK/toolchains/llvm/prebuilt/windows-x86_64/bin/llvm-ranlib"

# Verify compiler exists
if [ ! -f "$CC" ] && [ ! -f "$CC.exe" ]; then
    echo -e "${RED}Error: Compiler not found at $CC${NC}"
    exit 1
fi

echo -e "${GREEN}Compiler found: $CC${NC}"

# Set grpcio build flags
export GRPC_PYTHON_DISABLE_LIBC_COMPATIBILITY=1
export GRPC_PYTHON_BUILD_SYSTEM_OPENSSL=1
export GRPC_PYTHON_BUILD_SYSTEM_ZLIB=1
export GRPC_PYTHON_BUILD_SYSTEM_CARES=1
export GRPC_PYTHON_BUILD_SYSTEM_RE2=1
export GRPC_PYTHON_BUILD_SYSTEM_ABSL=1
export GRPC_PYTHON_BUILD_WITH_CYTHON=1

# Android-specific compiler flags
export CFLAGS="-U__ANDROID_API__ -D__ANDROID_API__=30 -include unistd.h -I$NDK/toolchains/llvm/prebuilt/windows-x86_64/sysroot/usr/include -I$NDK/toolchains/llvm/prebuilt/windows-x86_64/sysroot/usr/include/aarch64-linux-android"
export CPPFLAGS="$CFLAGS"
export LDFLAGS="-llog -L$NDK/toolchains/llvm/prebuilt/windows-x86_64/sysroot/usr/lib/aarch64-linux-android/30"

# Set target platform (this is tricky on Windows)
export _PYTHON_HOST_PLATFORM=linux-aarch64

# Create wheels directory
mkdir -p wheels

echo -e "${YELLOW}Note: Cross-compiling Python wheels on Windows is challenging.${NC}"
echo -e "${YELLOW}Python's build system may still try to use MSVC.${NC}"
echo -e "${YELLOW}If this fails, consider using WSL or building on a Linux system.${NC}"
echo ""
echo -e "${GREEN}Building grpcio wheel for Android aarch64...${NC}"
echo -e "${GREEN}This may take a while...${NC}"
echo ""

# Build the wheel
pip wheel grpcio==1.76.0 \
    --no-binary=:all: \
    --no-build-isolation \
    --wheel-dir ./wheels \
    --verbose

echo ""
echo -e "${GREEN}Build complete! Check ./wheels/ for the generated wheel file.${NC}"

