#!/bin/bash
# Script to copy wheel files from Android device to local arch64_wheels directory
# Usage: ./copy_wheels_from_device.sh

DEVICE_WHEELS_PATH="/data/data/com.termux/files/home/wheels"
LOCAL_WHEELS_DIR="termux-app/arch64_wheels"

echo "Copying wheel files from device to local directory..."
echo "Device path: $DEVICE_WHEELS_PATH"
echo "Local directory: $LOCAL_WHEELS_DIR"
echo ""

# Create local directory if it doesn't exist
mkdir -p "$LOCAL_WHEELS_DIR"

# Try to get list of wheels from device using different methods
echo "Attempting to list wheels on device..."

# Method 1: Try using run-as (works if app is debuggable)
WHEEL_LIST=$(adb shell "run-as com.termux ls $DEVICE_WHEELS_PATH/*.whl 2>/dev/null" 2>/dev/null | sed 's|.*/||')

# Method 2: If run-as fails, try using termux-exec
if [ -z "$WHEEL_LIST" ]; then
    echo "Method 1 failed, trying termux-exec..."
    WHEEL_LIST=$(adb shell "am start -n com.termux/.HomeActivity -e cmd 'ls $DEVICE_WHEELS_PATH/*.whl' > /dev/null 2>&1; sleep 2" 2>/dev/null)
fi

# Method 3: Use adb shell with su (requires root)
if [ -z "$WHEEL_LIST" ]; then
    echo "Method 2 failed, trying with root access..."
    WHEEL_LIST=$(adb shell "su -c 'ls $DEVICE_WHEELS_PATH/*.whl 2>/dev/null'" 2>/dev/null | sed 's|.*/||')
fi

if [ -z "$WHEEL_LIST" ]; then
    echo "ERROR: Could not access device wheels directory."
    echo "Please ensure:"
    echo "  1. Device is connected via ADB"
    echo "  2. App is debuggable OR device is rooted"
    echo "  3. Termux app has been run at least once"
    exit 1
fi

echo "Found wheels on device:"
echo "$WHEEL_LIST" | while read wheel; do
    echo "  - $wheel"
done
echo ""

# Copy each wheel file
COPIED=0
SKIPPED=0
FAILED=0

echo "$WHEEL_LIST" | while read wheel_file; do
    if [ -z "$wheel_file" ]; then
        continue
    fi
    
    local_path="$LOCAL_WHEELS_DIR/$wheel_file"
    
    # Skip if already exists locally
    if [ -f "$local_path" ]; then
        echo "SKIP: $wheel_file (already exists locally)"
        SKIPPED=$((SKIPPED + 1))
        continue
    fi
    
    echo "Copying: $wheel_file..."
    
    # Try different methods to copy
    SUCCESS=false
    
    # Method 1: adb pull with run-as
    if adb shell "run-as com.termux cat $DEVICE_WHEELS_PATH/$wheel_file" > "$local_path" 2>/dev/null; then
        if [ -f "$local_path" ] && [ -s "$local_path" ]; then
            SUCCESS=true
        fi
    fi
    
    # Method 2: adb pull with su
    if [ "$SUCCESS" = false ]; then
        if adb shell "su -c 'cat $DEVICE_WHEELS_PATH/$wheel_file'" > "$local_path" 2>/dev/null; then
            if [ -f "$local_path" ] && [ -s "$local_path" ]; then
                SUCCESS=true
            fi
        fi
    fi
    
    if [ "$SUCCESS" = true ]; then
        echo "  ✓ Copied: $wheel_file ($(du -h "$local_path" | cut -f1))"
        COPIED=$((COPIED + 1))
    else
        echo "  ✗ Failed: $wheel_file"
        rm -f "$local_path"
        FAILED=$((FAILED + 1))
    fi
done

echo ""
echo "Summary:"
echo "  Copied: $COPIED"
echo "  Skipped: $SKIPPED"
echo "  Failed: $FAILED"
echo ""
echo "Local wheels directory now contains:"
ls -1 "$LOCAL_WHEELS_DIR"/*.whl 2>/dev/null | wc -l | xargs echo "  Total wheel files:"

