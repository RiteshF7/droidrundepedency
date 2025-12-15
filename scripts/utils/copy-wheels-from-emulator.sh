#!/bin/bash
# copy-wheels-from-emulator.sh
# Copy built wheels from emulator to Windows host

set -e

ANDROID_SDK="${LOCALAPPDATA}/Android/Sdk"
ADB_PATH="${ANDROID_SDK}/platform-tools/adb.exe"
TERMUX_WHEELS_PATH="/data/data/com.termux/files/home/wheels"
WINDOWS_WHEELS_BASE="E:/Code/LunarLand/MiniLinux/termux-packages/wheels"

echo "=== Copying wheels from emulator ==="
echo ""

# Check if ADB is available
if [ ! -f "$ADB_PATH" ]; then
    echo "Error: ADB not found at $ADB_PATH"
    echo "Please check your Android SDK installation."
    exit 1
fi

# Check if emulator is connected
"$ADB_PATH" devices | grep -q "emulator"
if [ $? -ne 0 ]; then
    echo "Error: No emulator detected"
    echo "Please start the Pixel 4a emulator first"
    exit 1
fi

# Get architecture
ARCH=$("$ADB_PATH" shell getprop ro.product.cpu.abi | tr -d '\r\n' || echo "aarch64")
echo "Detected architecture: $ARCH"

# Create destination directory
DEST_DIR="${WINDOWS_WHEELS_BASE}/${ARCH}"
mkdir -p "$DEST_DIR" || {
    echo "Error: Failed to create directory $DEST_DIR"
    exit 1
}

# Copy wheels
echo ""
echo "Copying wheels from: $TERMUX_WHEELS_PATH"
echo "To: $DEST_DIR"
echo ""

"$ADB_PATH" pull "$TERMUX_WHEELS_PATH" "$DEST_DIR/"

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Success! Wheels copied to:"
    echo "   $DEST_DIR"
    echo ""
    echo "Total files: $(find "$DEST_DIR" -name "*.whl" 2>/dev/null | wc -l)"
else
    echo ""
    echo "❌ Failed to copy wheels"
    exit 1
fi




