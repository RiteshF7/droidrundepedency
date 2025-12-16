#!/bin/bash
# copy-build-folder-simple.sh
# Simple script to copy build folder using adb exec-out

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$PROJECT_ROOT/scripts/build"
TARGET_DIR="/data/data/com.termux/files/home/droidrunBuild/scripts/build"

echo "Copying build folder to device..."
echo "Source: $BUILD_DIR"
echo "Target: $TARGET_DIR"
echo ""

# Create target directory
adb shell "run-as com.termux sh -c 'mkdir -p $TARGET_DIR'"

# Copy each file using adb exec-out
for file in "$BUILD_DIR"/*.sh "$BUILD_DIR"/*.md; do
    if [ ! -f "$file" ]; then
        continue
    fi
    
    filename=$(basename "$file")
    echo "Copying $filename..."
    
    # Use adb exec-out to pipe file content directly
    cat "$file" | adb exec-out "run-as com.termux sh -c 'cat > $TARGET_DIR/$filename'" && {
        echo "  ✓ $filename"
    } || {
        echo "  ✗ $filename"
    }
done

# Make scripts executable
echo ""
echo "Making scripts executable..."
adb shell "run-as com.termux sh -c 'chmod +x $TARGET_DIR/*.sh'"

# Verify
echo ""
echo "=== Verification ==="
adb exec-out "run-as com.termux sh -c 'ls -lah $TARGET_DIR/'"

echo ""
echo "✓ Build folder copied successfully!"

