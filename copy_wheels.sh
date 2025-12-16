#!/usr/bin/env bash
# Copy wheels from shared storage to Termux directory
# Run this script on Android device via: adb shell "run-as com.termux bash < copy_wheels.sh"

export PREFIX=/data/data/com.termux/files/usr
export HOME=/data/data/com.termux/files/home
export PATH=$PREFIX/bin:$PATH

SOURCE_DIR="/sdcard/Download/droidrun_wheels"
DEST_DIR="$HOME/droidrunBuild/depedencies/wheels/_x86_64_wheels"

mkdir -p "$DEST_DIR"

if [ ! -d "$SOURCE_DIR" ]; then
    echo "Source directory not found: $SOURCE_DIR"
    echo "First, push wheels to device:"
    echo "  adb push depedencies/wheels/_x86_64_wheels /sdcard/Download/droidrun_wheels"
    exit 1
fi

echo "Copying wheels from $SOURCE_DIR to $DEST_DIR..."
COUNT=0
for wheel in "$SOURCE_DIR"/*.whl; do
    if [ -f "$wheel" ]; then
        cp "$wheel" "$DEST_DIR/" && COUNT=$((COUNT + 1))
        echo "  Copied: $(basename "$wheel")"
    fi
done

echo "Copied $COUNT wheels to $DEST_DIR"

