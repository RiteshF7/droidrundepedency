#!/usr/bin/env bash
# Script to clean emulator storage and restart it

set -euo pipefail

# Auto-detect AVD name or use provided one
if [ $# -gt 0 ]; then
    AVD_NAME="$1"
else
    # Try to auto-detect - use first available AVD
    if command -v emulator >/dev/null 2>&1; then
        AVD_NAME=$(emulator -list-avds | head -1)
    elif [ -f "$HOME/Android/Sdk/emulator/emulator" ]; then
        AVD_NAME=$("$HOME/Android/Sdk/emulator/emulator" -list-avds | head -1)
    else
        AVD_NAME="Resizable_Experimental"
    fi
fi

if [ -z "$AVD_NAME" ]; then
    echo "Error: No AVD found. Please create an AVD first."
    exit 1
fi

echo "=========================================="
echo "Cleaning Emulator Storage and Restarting"
echo "=========================================="
echo

# Step 1: Kill any running emulator
echo "[1/4] Stopping any running emulator..."
if command -v adb >/dev/null 2>&1; then
    # Try to kill via ADB first
    adb emu kill 2>/dev/null || true
    sleep 2
else
    echo "Warning: adb not found, skipping ADB kill"
fi

# Also try to kill emulator processes (Windows)
if command -v taskkill >/dev/null 2>&1; then
    taskkill //F //IM qemu-system-x86_64.exe 2>/dev/null || true
    taskkill //F //IM emulator.exe 2>/dev/null || true
    sleep 2
fi

# Kill emulator processes (Linux)
if command -v pkill >/dev/null 2>&1; then
    pkill -f qemu-system-x86_64 2>/dev/null || true
    pkill -f emulator 2>/dev/null || true
    sleep 2
fi

echo "✓ Emulator stopped"
echo

# Step 2: Check if emulator command is available
echo "[2/4] Checking emulator availability..."

# Try to find emulator in common locations
EMULATOR_CMD=""
if command -v emulator >/dev/null 2>&1; then
    EMULATOR_CMD="emulator"
elif [ -f "$HOME/Android/Sdk/emulator/emulator" ]; then
    EMULATOR_CMD="$HOME/Android/Sdk/emulator/emulator"
    export PATH="$HOME/Android/Sdk/emulator:$HOME/Android/Sdk/platform-tools:$PATH"
elif [ -f "$HOME/.android/sdk/emulator/emulator" ]; then
    EMULATOR_CMD="$HOME/.android/sdk/emulator/emulator"
    export PATH="$HOME/.android/sdk/emulator:$HOME/.android/sdk/platform-tools:$PATH"
fi

if [ -z "$EMULATOR_CMD" ]; then
    echo "Error: emulator command not found"
    echo "Please ensure Android SDK emulator is in your PATH"
    echo "You can add it using: ./add_android_to_path.sh"
    exit 1
fi

echo "Using emulator: $EMULATOR_CMD"

# Check if AVD exists
if ! "$EMULATOR_CMD" -list-avds | grep -q "^${AVD_NAME}$"; then
    echo "Error: AVD '$AVD_NAME' not found"
    echo ""
    echo "Available AVDs:"
    "$EMULATOR_CMD" -list-avds
    exit 1
fi

echo "✓ AVD found: $AVD_NAME"
echo

# Step 3: Start emulator with -wipe-data flag
echo "[3/4] Starting emulator with wiped data..."
echo "This will erase all data on the emulator!"
echo "Launching $AVD_NAME with -wipe-data..."
"$EMULATOR_CMD" -avd "$AVD_NAME" -wipe-data &
EMULATOR_PID=$!

echo "✓ Emulator starting (PID: $EMULATOR_PID)"
echo

# Step 4: Wait for emulator to be ready
echo "[4/4] Waiting for emulator to be ready..."
echo "This may take a minute or two..."

MAX_WAIT=120  # 2 minutes
WAIT_COUNT=0
READY=false

while [ $WAIT_COUNT -lt $MAX_WAIT ]; do
    if command -v adb >/dev/null 2>&1; then
        if adb devices 2>/dev/null | grep -q "device$"; then
            # Check if device is fully booted
            BOOT_COMPLETE=$(adb shell getprop sys.boot_completed 2>/dev/null || echo "0")
            if [ "$BOOT_COMPLETE" = "1" ]; then
                READY=true
                break
            fi
        fi
    fi
    sleep 2
    WAIT_COUNT=$((WAIT_COUNT + 2))
    echo -n "."
done

echo ""

if [ "$READY" = true ]; then
    echo "✓ Emulator is ready!"
    echo ""
    echo "Device status:"
    adb devices
    echo ""
    echo "Emulator has been cleaned and restarted successfully!"
    echo "You can now run your installation scripts."
else
    echo "⚠ Warning: Emulator may still be starting up"
    echo "Check manually with: adb devices"
fi

echo "=========================================="

