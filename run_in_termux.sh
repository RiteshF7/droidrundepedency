#!/usr/bin/env bash
# Script to execute git pull and run installdroidrun.sh in Termux via ADB

set -e

echo "=========================================="
echo "Termux Git Pull and Script Execution"
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

# Get the project directory path in Termux
# Assuming the project is cloned in ~/droidrundepedency
PROJECT_DIR="droidrundepedency"
TERMUX_HOME="/data/data/com.termux/files/home"
FULL_PATH="$TERMUX_HOME/$PROJECT_DIR"

echo "Project directory: $FULL_PATH"
echo ""

# Step 1: Git pull
echo "Step 1: Pulling latest changes from git..."
adb shell "run-as com.termux sh -c 'cd $FULL_PATH && git pull origin master'"
if [ $? -eq 0 ]; then
    echo "[OK] Git pull completed"
else
    echo "[WARNING] Git pull failed, trying alternative method..."
    adb shell "cd $FULL_PATH && git pull origin master"
fi

echo ""

# Step 2: Make script executable
echo "Step 2: Making script executable..."
adb shell "run-as com.termux sh -c 'cd $FULL_PATH && chmod +x installdroidrun.sh'"
if [ $? -ne 0 ]; then
    adb shell "cd $FULL_PATH && chmod +x installdroidrun.sh"
fi
echo "[OK] Script is executable"

echo ""

# Step 3: Execute the script
echo "Step 3: Executing installdroidrun.sh..."
echo "=========================================="
echo ""
adb shell "run-as com.termux sh -c 'cd $FULL_PATH && bash installdroidrun.sh'"

echo ""
echo "=========================================="
echo "Script execution completed"
echo "=========================================="

