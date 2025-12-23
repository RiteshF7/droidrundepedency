#!/usr/bin/env bash
# Script to run commands in Termux via ADB with full environment access

set -euo pipefail

TERMUX_HOME="/data/data/com.termux/files/home"
TERMUX_PREFIX="/data/data/com.termux/files/usr"

echo "=========================================="
echo "Termux Command Execution via ADB"
echo "=========================================="
echo ""

# Check if ADB is available
if ! command -v adb >/dev/null 2>&1; then
    echo "Error: ADB not found. Please install Android SDK Platform Tools"
    exit 1
fi

# Check if device is connected
DEVICES=$(adb devices | grep -v "List" | grep "device$" | wc -l)
if [ "$DEVICES" -eq 0 ]; then
    echo "Error: No Android device connected via ADB"
    echo "Please connect your device and enable USB debugging"
    exit 1
fi

echo "[OK] Android device connected"
echo ""

# Function to execute command in Termux with full environment
termux_exec() {
    local cmd="$1"
    adb shell "run-as com.termux sh -c 'cd $TERMUX_HOME && source $TERMUX_PREFIX/etc/profile && export PATH=$TERMUX_PREFIX/bin:\$PATH && export HOME=$TERMUX_HOME && export PREFIX=$TERMUX_PREFIX && $cmd'"
}

# Test if we can access Termux
echo "Testing Termux access..."
if ! termux_exec "pwd" >/dev/null 2>&1; then
    echo "Error: Cannot access Termux. Make sure Termux is installed and ADB has proper permissions."
    exit 1
fi

echo "[OK] Termux access confirmed"
echo ""

# If commands are provided as arguments, execute them
if [ $# -gt 0 ]; then
    echo "Executing commands in Termux..."
    echo ""
    termux_exec "$@"
else
    echo "Starting interactive Termux shell..."
    echo "All commands (pkg, pip, python, etc.) are available with the Termux environment loaded."
    echo "Type 'exit' to leave the shell."
    echo ""
    adb shell "run-as com.termux sh -c 'cd $TERMUX_HOME && source $TERMUX_PREFIX/etc/profile && export PATH=$TERMUX_PREFIX/bin:\$PATH && export HOME=$TERMUX_HOME && export PREFIX=$TERMUX_PREFIX && exec sh'"
fi

echo ""
echo "=========================================="
echo "Done!"
