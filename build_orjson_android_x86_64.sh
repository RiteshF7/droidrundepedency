#!/bin/bash
# Script to build orjson wheel for Android x86_64 using NDK cross-compilation on Ubuntu

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}Building orjson wheel for Android x86_64${NC}"
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

# Android-specific compiler flags for x86_64
# Completely isolate from host system - use only NDK headers
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

# Rust cross-compilation setup for Android x86_64
# orjson is a Rust package, so we need to configure Rust for cross-compilation
export CARGO_BUILD_TARGET="x86_64-linux-android"
export CARGO_TARGET_X86_64_LINUX_ANDROID_LINKER="$CC"
export CC_x86_64_linux_android="$CC"
export AR_x86_64_linux_android="$AR"
export TARGET_CC="$CC"
export TARGET_AR="$AR"
export TARGET_CFLAGS="$CFLAGS"

# Create Cargo config for Android cross-compilation
CARGO_CONFIG_DIR="$HOME/.cargo"
mkdir -p "$CARGO_CONFIG_DIR"
CARGO_CONFIG="$CARGO_CONFIG_DIR/config.toml"

# Add or update Cargo config for Android x86_64
if [ ! -f "$CARGO_CONFIG" ] || ! grep -q "x86_64-linux-android" "$CARGO_CONFIG" 2>/dev/null; then
    echo -e "${YELLOW}Configuring Cargo for Android x86_64 cross-compilation...${NC}"
    cat >> "$CARGO_CONFIG" << EOF

[target.x86_64-linux-android]
linker = "$CC"
ar = "$AR"

[build]
target = "x86_64-linux-android"
EOF
    echo -e "${GREEN}✓ Cargo config updated${NC}"
fi

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
echo "  CARGO_TARGET_X86_64_LINUX_ANDROID_LINKER=$CARGO_TARGET_X86_64_LINUX_ANDROID_LINKER"
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
python3 -m pip install --user --break-system-packages --quiet setuptools wheel maturin 2>&1 | grep -E "(Successfully|Requirement|already satisfied)" || true

# Check for Rust (required for orjson)
if ! command -v rustc &> /dev/null; then
    echo -e "${YELLOW}Rust not found. Installing Rust...${NC}"
    # Try to install rust via rustup (recommended for cross-compilation)
    if ! command -v rustup &> /dev/null; then
        echo -e "${YELLOW}Installing rustup...${NC}"
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable
        export PATH="$HOME/.cargo/bin:$PATH"
    fi
    
    # Install Rust toolchain
    rustup toolchain install stable 2>/dev/null || true
    rustup default stable 2>/dev/null || true
    
    # Install Android target for Rust
    echo -e "${YELLOW}Installing Rust Android x86_64 target...${NC}"
    rustup target add x86_64-linux-android 2>/dev/null || true
else
    echo -e "${GREEN}✓ Rust found: $(rustc --version 2>/dev/null || echo 'unknown version')${NC}"
    export PATH="$HOME/.cargo/bin:$PATH"
    
    # Check if rustup is available and set default toolchain if needed
    if command -v rustup &> /dev/null; then
        # Set default toolchain if not set
        if ! rustup show default &>/dev/null; then
            echo -e "${YELLOW}Setting default Rust toolchain...${NC}"
            rustup default stable 2>/dev/null || {
                echo -e "${YELLOW}Installing stable toolchain...${NC}"
                rustup toolchain install stable 2>/dev/null || true
                rustup default stable 2>/dev/null || true
            }
        fi
        
        # Check if Android target is installed
        if ! rustup target list --installed 2>/dev/null | grep -q "x86_64-linux-android"; then
            echo -e "${YELLOW}Installing Rust Android x86_64 target...${NC}"
            rustup target add x86_64-linux-android 2>/dev/null || echo -e "${YELLOW}Warning: Could not install Android target via rustup, continuing anyway...${NC}"
        else
            echo -e "${GREEN}✓ Rust Android x86_64 target is installed${NC}"
        fi
    else
        echo -e "${YELLOW}Warning: rustup not available, assuming Android target can be built with current Rust setup${NC}"
    fi
fi

# Verify maturin is installed
if ! python3 -m maturin --version &> /dev/null; then
    echo -e "${YELLOW}maturin not found. Installing maturin...${NC}"
    python3 -m pip install --user --break-system-packages maturin
fi

echo -e "${GREEN}✓ maturin found: $(python3 -m maturin --version)${NC}"

# Set PATH to include local bin directory
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"

# Set Rust environment variables to handle symlinked directories
# Fix broken symlinks by creating target directory or using a workaround
if [ -L "$HOME/.rustup" ] && [ ! -e "$HOME/.rustup" ]; then
    RUSTUP_TARGET=$(readlink "$HOME/.rustup" 2>/dev/null)
    if [ -n "$RUSTUP_TARGET" ]; then
        echo -e "${YELLOW}Creating target directory for broken .rustup symlink: $RUSTUP_TARGET${NC}"
        mkdir -p "$RUSTUP_TARGET" 2>/dev/null || {
            echo -e "${YELLOW}Could not create $RUSTUP_TARGET, using $HOME/.rustup instead${NC}"
            rm -f "$HOME/.rustup"
            mkdir -p "$HOME/.rustup" 2>/dev/null || true
        }
    else
        echo -e "${YELLOW}Removing broken .rustup symlink...${NC}"
        rm -f "$HOME/.rustup"
        mkdir -p "$HOME/.rustup" 2>/dev/null || true
    fi
fi

# Resolve symlinks to actual paths to avoid rustup errors
if [ -L "$HOME/.rustup" ] && [ -e "$HOME/.rustup" ]; then
    RUSTUP_HOME_TARGET=$(readlink -f "$HOME/.rustup" 2>/dev/null)
    if [ -n "$RUSTUP_HOME_TARGET" ] && [ -d "$RUSTUP_HOME_TARGET" ]; then
        export RUSTUP_HOME="$RUSTUP_HOME_TARGET"
        echo -e "${YELLOW}Setting RUSTUP_HOME to resolved path: $RUSTUP_HOME${NC}"
    else
        export RUSTUP_HOME="$HOME/.rustup"
    fi
elif [ -d "$HOME/.rustup" ]; then
    export RUSTUP_HOME="$HOME/.rustup"
else
    export RUSTUP_HOME="$HOME/.rustup"
    mkdir -p "$RUSTUP_HOME" 2>/dev/null || true
fi

if [ -L "$HOME/.cargo" ] && [ ! -e "$HOME/.cargo" ]; then
    echo -e "${YELLOW}Removing broken .cargo symlink...${NC}"
    rm -f "$HOME/.cargo"
fi

if [ -L "$HOME/.cargo" ]; then
    CARGO_HOME_TARGET=$(readlink -f "$HOME/.cargo" 2>/dev/null)
    if [ -n "$CARGO_HOME_TARGET" ] && [ -d "$CARGO_HOME_TARGET" ]; then
        export CARGO_HOME="$CARGO_HOME_TARGET"
        echo -e "${YELLOW}Setting CARGO_HOME to resolved path: $CARGO_HOME${NC}"
    else
        export CARGO_HOME="$HOME/.cargo"
    fi
elif [ -d "$HOME/.cargo" ]; then
    export CARGO_HOME="$HOME/.cargo"
else
    export CARGO_HOME="$HOME/.cargo"
fi

# Ensure these are set for maturin/cargo subprocesses
export RUSTUP_HOME="${RUSTUP_HOME:-$HOME/.rustup}"
export CARGO_HOME="${CARGO_HOME:-$HOME/.cargo}"
echo -e "${GREEN}Using RUSTUP_HOME=$RUSTUP_HOME${NC}"
echo -e "${GREEN}Using CARGO_HOME=$CARGO_HOME${NC}"

echo ""
echo -e "${GREEN}Starting build...${NC}"
echo -e "${YELLOW}This may take 5-15 minutes depending on your system.${NC}"
echo ""

# Build the wheel using maturin directly for better cross-compilation control
echo -e "${GREEN}Building orjson wheel for Android x86_64...${NC}"

# Get Python version for maturin cross-compilation
PYTHON_VERSION=$(python3 --version 2>&1 | awk '{print $2}' | cut -d. -f1,2)
PYTHON_INTERPRETER="python${PYTHON_VERSION}"
echo -e "${YELLOW}Using Python interpreter: $PYTHON_INTERPRETER${NC}"

# Download orjson source
TEMP_DIR=$(mktemp -d)
echo -e "${YELLOW}Downloading orjson source...${NC}"
python3 -m pip download --no-deps --no-binary=:all: orjson -d "$TEMP_DIR" 2>&1 | grep -E "(Downloading|Saved)" || true

# Extract source
ORJSON_TAR=$(find "$TEMP_DIR" -name "orjson-*.tar.gz" -type f | head -1)
if [ -z "$ORJSON_TAR" ]; then
    echo -e "${RED}Error: Could not find orjson source tarball${NC}"
    exit 1
fi

ORJSON_SRC_DIR="$TEMP_DIR/orjson-src"
mkdir -p "$ORJSON_SRC_DIR"
tar -xzf "$ORJSON_TAR" -C "$ORJSON_SRC_DIR" --strip-components=1
echo -e "${GREEN}✓ Extracted orjson source to $ORJSON_SRC_DIR${NC}"

# Build with maturin
echo -e "${GREEN}Building with maturin...${NC}"
cd "$ORJSON_SRC_DIR"
python3 -m maturin build \
    --release \
    --target x86_64-linux-android \
    --interpreter "$PYTHON_INTERPRETER" \
    --out "$WHEELS_DIR" \
    2>&1 | tee "$(pwd)/../build_orjson.log"

BUILD_EXIT_CODE=${PIPESTATUS[0]}
cd - > /dev/null

# Cleanup
rm -rf "$TEMP_DIR"

BUILD_EXIT_CODE=${PIPESTATUS[0]}

echo ""
if [ $BUILD_EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}✓ Build successful!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo -e "Wheel file(s) created in: ${BLUE}$WHEELS_DIR${NC}"
    ls -lh "$WHEELS_DIR"/orjson*.whl 2>/dev/null || echo "No orjson .whl files found"
    echo ""
    echo -e "${GREEN}Next steps:${NC}"
    echo -e "  1. Transfer the wheel file to your Android device"
    echo -e "  2. Install it using: pip install <wheel_file>"
else
    echo -e "${RED}========================================${NC}"
    echo -e "${RED}✗ Build failed!${NC}"
    echo -e "${RED}========================================${NC}"
    echo -e "Check build_orjson.log for details"
    exit 1
fi

