#!/bin/bash
# copy-build-folder-to-device.sh
# Copy build folder to Termux device using ADB
# Uses temporary files to avoid command line length limits

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$PROJECT_ROOT/scripts/build"
TARGET_DIR="/data/data/com.termux/files/home/droidrunBuild/scripts/build"
TEMP_DIR="/tmp/build_copy_$$"

echo "Copying build folder to device..."
echo "Source: $BUILD_DIR"
echo "Target: $TARGET_DIR"
echo ""

# Create temp directory
mkdir -p "$TEMP_DIR"

# Create target directory on device
adb shell "run-as com.termux sh -c 'mkdir -p $TARGET_DIR'" || {
    echo "ERROR: Failed to create target directory"
    rm -rf "$TEMP_DIR"
    exit 1
}

# Copy each file
COPIED=0
FAILED=0

for file in "$BUILD_DIR"/*.sh "$BUILD_DIR"/*.md; do
    if [ ! -f "$file" ]; then
        continue
    fi
    
    filename=$(basename "$file")
    echo "Copying $filename..."
    
    # Create base64 file locally
    TEMP_B64="$TEMP_DIR/${filename}.b64"
    cat "$file" | base64 -w 0 > "$TEMP_B64" 2>/dev/null || cat "$file" | base64 | tr -d '\n' > "$TEMP_B64"
    
    # Copy base64 file to device's accessible location first
    DEVICE_TEMP="/sdcard/tmp_${filename}.b64"
    
    if adb push "$TEMP_B64" "$DEVICE_TEMP" >/dev/null 2>&1; then
        # Now decode and move to final location using Python
        OUTPUT=$(adb shell "run-as com.termux sh -c '
export PREFIX=/data/data/com.termux/files/usr
export HOME=/data/data/com.termux/files/home
export PATH=\$PREFIX/bin:\$PATH
python3 << \"PYEOF\"
import base64
import os
import shutil
try:
    # Read from /sdcard (accessible location)
    with open(\"/sdcard/tmp_${filename}.b64\", \"r\") as f:
        content = f.read().strip()
    decoded = base64.b64decode(content)
    os.makedirs(\"$TARGET_DIR\", exist_ok=True)
    with open(\"$TARGET_DIR/$filename\", \"wb\") as f:
        f.write(decoded)
    # Clean up temp file
    os.remove(\"/sdcard/tmp_${filename}.b64\")
    print(\"SUCCESS\")
except Exception as e:
    print(f\"ERROR: {e}\")
    import sys
    sys.exit(1)
PYEOF
chmod +x $TARGET_DIR/$filename 2>/dev/null || true
'")
        
        if echo "$OUTPUT" | grep -q "SUCCESS"; then
            echo "  ✓ Success: $filename"
            COPIED=$((COPIED + 1))
        else
            echo "  ✗ Failed: $filename"
            echo "    $(echo "$OUTPUT" | grep -i error | head -1)"
            FAILED=$((FAILED + 1))
        fi
    else
        echo "  ✗ Failed: $filename (could not push to device)"
        FAILED=$((FAILED + 1))
    fi
    
    # Clean up local temp file
    rm -f "$TEMP_B64"
done

# Clean up temp directory
rm -rf "$TEMP_DIR"

# Make all scripts executable
echo ""
echo "Making scripts executable..."
adb exec-out run-as com.termux sh -c "chmod +x $TARGET_DIR/*.sh 2>/dev/null && echo 'All scripts made executable'" || true

# Verify
echo ""
echo "=== Verification ==="
adb exec-out run-as com.termux sh -c "ls -lah $TARGET_DIR/"

echo ""
echo "=== Summary ==="
echo "  Copied: $COPIED"
echo "  Failed: $FAILED"
echo ""
if [ $COPIED -gt 0 ]; then
    echo "✓ Build folder successfully copied to: $TARGET_DIR"
else
    echo "✗ Failed to copy build folder"
    exit 1
fi
