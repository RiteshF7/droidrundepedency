#!/usr/bin/env bash
# Script to start Resizable_Experimental AVD

set -euo pipefail

AVD_NAME="Resizable_Experimental"

echo "Starting Android Virtual Device: $AVD_NAME"
echo "=========================================="

# Check if emulator command is available
if ! command -v emulator >/dev/null 2>&1; then
    echo "Error: emulator command not found"
    echo "Please ensure Android SDK emulator is in your PATH"
    echo "You can add it using: ./add_android_to_path.sh"
    exit 1
fi

# Check if AVD exists
if ! emulator -list-avds | grep -q "^${AVD_NAME}$"; then
    echo "Error: AVD '$AVD_NAME' not found"
    echo ""
    echo "Available AVDs:"
    emulator -list-avds
    exit 1
fi

# Start the emulator in background
echo "Launching $AVD_NAME..."
emulator -avd "$AVD_NAME" &

echo ""
echo "AVD is starting in the background..."
echo "The emulator window should appear shortly."
echo ""
echo "To check if it's ready, run: adb devices"
echo "To stop the emulator, close the emulator window or run: adb emu kill"


