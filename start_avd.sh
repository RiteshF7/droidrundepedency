#!/usr/bin/env bash
# Script to start Android Virtual Device

set -euo pipefail

# Auto-detect AVD name or use provided one
if [ $# -gt 0 ]; then
    AVD_NAME="$1"
else
    # Try to auto-detect - use first available AVD
    if [ -f "$HOME/Android/Sdk/emulator/emulator" ]; then
        AVD_NAME=$("$HOME/Android/Sdk/emulator/emulator" -list-avds | head -1)
        export PATH="$HOME/Android/Sdk/emulator:$HOME/Android/Sdk/platform-tools:$PATH"
    elif command -v emulator >/dev/null 2>&1; then
        AVD_NAME=$(emulator -list-avds | head -1)
    else
        AVD_NAME="Resizable_Experimental"
    fi
fi

if [ -z "$AVD_NAME" ]; then
    echo "Error: No AVD found. Please create an AVD first."
    exit 1
fi

echo "Starting Android Virtual Device: $AVD_NAME"
echo "=========================================="

# Find emulator command
EMULATOR_CMD=""
if command -v emulator >/dev/null 2>&1; then
    EMULATOR_CMD="emulator"
elif [ -f "$HOME/Android/Sdk/emulator/emulator" ]; then
    EMULATOR_CMD="$HOME/Android/Sdk/emulator/emulator"
    export PATH="$HOME/Android/Sdk/emulator:$HOME/Android/Sdk/platform-tools:$PATH"
fi

if [ -z "$EMULATOR_CMD" ]; then
    echo "Error: emulator command not found"
    echo "Please ensure Android SDK emulator is in your PATH"
    exit 1
fi

# Check if AVD exists
if ! "$EMULATOR_CMD" -list-avds | grep -q "^${AVD_NAME}$"; then
    echo "Error: AVD '$AVD_NAME' not found"
    echo ""
    echo "Available AVDs:"
    "$EMULATOR_CMD" -list-avds
    exit 1
fi

# Start the emulator in background
echo "Launching $AVD_NAME..."
"$EMULATOR_CMD" -avd "$AVD_NAME" &

echo ""
echo "AVD is starting in the background..."
echo "The emulator window should appear shortly."
echo ""
echo "To check if it's ready, run: adb devices"
echo "To stop the emulator, close the emulator window or run: adb emu kill"


