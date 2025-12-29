#!/usr/bin/env bash
# Script to copy wheel files from Termux to laptop via ADB
# Uses direct pull from Termux directory or shared storage

TERMUX_HOME="/data/data/com.termux/files/home"
TERMUX_PREFIX="/data/data/com.termux/files/usr"
SHARED_STORAGE="/sdcard/Download"
LOCAL_DEST_DIR="$HOME/Downloads/termux_wheels"

echo "=========================================="
echo "Copying wheels from Termux to laptop"
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
    exit 1
fi

echo "[OK] Android device connected"
echo ""

# Step 1: Setup Termux storage (if not already done)
echo "Step 1: Setting up Termux storage access..."
adb shell "run-as com.termux sh -c 'cd $TERMUX_HOME && export PATH=$TERMUX_PREFIX/bin:\$PATH && export HOME=$TERMUX_HOME && export PREFIX=$TERMUX_PREFIX && if [ ! -d ~/storage/downloads ]; then termux-setup-storage; fi'"
sleep 2

# Step 2: Copy wheels from Termux home to shared storage
echo "Step 2: Copying wheels to Termux shared storage..."
echo "Checking wheels directory..."
WHEEL_COUNT=$(adb shell "run-as com.termux sh -c 'cd $TERMUX_HOME && export PATH=$TERMUX_PREFIX/bin:\$PATH && ls -1 wheels/*.whl 2>/dev/null | wc -l'")
echo "Found $WHEEL_COUNT wheel files"

if [ "$WHEEL_COUNT" -gt 0 ]; then
    echo "Copying wheels to shared storage..."
    # Use a loop to copy files one by one to avoid issues
    STORAGE_CMD="cd $TERMUX_HOME && export PATH=$TERMUX_PREFIX/bin:\$PATH && export HOME=$TERMUX_HOME && export PREFIX=$TERMUX_PREFIX && STORAGE_DIR=\$HOME/storage/downloads/termux_wheels && mkdir -p \$STORAGE_DIR && count=0 && for wheel in wheels/*.whl; do if [ -f \"\$wheel\" ]; then cp \"\$wheel\" \"\$STORAGE_DIR/\" && count=\$((count+1)); fi; done && echo \"Copied \$count files to \$STORAGE_DIR\""
    
    adb shell "run-as com.termux sh -c '$STORAGE_CMD'"
    
    # Verify files were copied
    echo ""
    echo "Verifying files in shared storage..."
    VERIFY_COUNT=$(adb shell "run-as com.termux sh -c 'cd $TERMUX_HOME && export PATH=$TERMUX_PREFIX/bin:\$PATH && export HOME=$TERMUX_HOME && ls -1 ~/storage/downloads/termux_wheels/*.whl 2>/dev/null | wc -l'")
    echo "Files in shared storage: $VERIFY_COUNT"
    
    if [ "$VERIFY_COUNT" -eq 0 ]; then
        echo "Warning: Files may not have been copied. Trying direct path..."
        # Try using the actual Android path
        adb shell "run-as com.termux sh -c 'cd $TERMUX_HOME && export PATH=$TERMUX_PREFIX/bin:\$PATH && mkdir -p /sdcard/Download/termux_wheels && cp wheels/*.whl /sdcard/Download/termux_wheels/ 2>&1'"
    fi
else
    echo "No wheel files found to copy"
    exit 1
fi

echo ""

# Step 3: Create local destination directory
echo ""
echo "Step 3: Creating local destination directory..."
mkdir -p "$LOCAL_DEST_DIR"
echo "[OK] Local directory: $LOCAL_DEST_DIR"
echo ""

# Step 4: Pull files from device to laptop
echo ""
echo "Step 4: Pulling wheel files from device to laptop..."

# Try method 1: Pull from shared storage
echo "Trying method 1: Pulling from shared storage..."
if adb pull "/sdcard/Download/termux_wheels/" "$LOCAL_DEST_DIR/" 2>/dev/null; then
    echo "[OK] Files pulled from shared storage!"
else
    echo "Method 1 failed, trying method 2: Direct stream via adb exec-out..."
    
    # Method 2: Use adb exec-out with tar to stream files directly
    echo "Streaming wheels directly from Termux..."
    adb shell "run-as com.termux sh -c 'cd $TERMUX_HOME && export PATH=$TERMUX_PREFIX/bin:\$PATH && cd wheels && tar czf - *.whl 2>/dev/null'" | tar xzf - -C "$LOCAL_DEST_DIR/" 2>/dev/null
    
    if [ $? -eq 0 ] && [ $(ls -1 "$LOCAL_DEST_DIR"/*.whl 2>/dev/null | wc -l) -gt 0 ]; then
        echo "[OK] Files streamed successfully!"
    else
        echo "Method 2 failed, trying method 3: Individual file copy via base64..."
        echo "This may take a while..."
        
        # Method 3: Copy files one by one using base64 encoding
        adb shell "run-as com.termux sh -c 'cd $TERMUX_HOME && export PATH=$TERMUX_PREFIX/bin:\$PATH && ls -1 wheels/*.whl 2>/dev/null'" | while read wheel_file; do
            if [ -n "$wheel_file" ]; then
                filename=$(basename "$wheel_file")
                echo "Copying $filename..."
                adb shell "run-as com.termux sh -c 'cd $TERMUX_HOME && export PATH=$TERMUX_PREFIX/bin:\$PATH && base64 wheels/$filename'" | base64 -d > "$LOCAL_DEST_DIR/$filename"
            fi
        done
    fi
fi

# Verify and report
echo ""
WHEEL_COUNT=$(ls -1 "$LOCAL_DEST_DIR"/*.whl 2>/dev/null | wc -l)
if [ "$WHEEL_COUNT" -gt 0 ]; then
    echo "[OK] Files copied successfully!"
    echo "Wheels location: $LOCAL_DEST_DIR"
    echo "Total wheel files: $WHEEL_COUNT"
    echo ""
    echo "Sample files:"
    ls -lh "$LOCAL_DEST_DIR"/*.whl 2>/dev/null | head -5
else
    echo ""
    echo "Error: Could not copy files."
    echo "Trying to diagnose..."
    adb shell "run-as com.termux sh -c 'cd $TERMUX_HOME && export PATH=$TERMUX_PREFIX/bin:\$PATH && ls -1 wheels/*.whl 2>/dev/null | head -3'"
    echo ""
    echo "Please check:"
    echo "1. Termux storage permission is granted (run 'termux-setup-storage' in Termux)"
    echo "2. Files exist in wheels directory"
    echo "3. ADB has proper permissions"
    exit 1
fi

echo ""
echo "=========================================="
echo "Done! Wheels copied to: $LOCAL_DEST_DIR"
echo "=========================================="

