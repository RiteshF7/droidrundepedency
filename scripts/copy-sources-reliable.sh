#!/bin/bash
# copy-sources-reliable.sh
# More reliable method to copy source archives using adb pull with temporary files

set -euo pipefail

TARGET_DIR="../arch64android/sources"

# Get list of files from wheels directory
echo "Getting file list from wheels directory..."
adb exec-out "run-as com.termux sh -c 'for f in /data/data/com.termux/files/home/wheels/*.tar.gz /data/data/com.termux/files/home/wheels/*.zip; do if [ -f \"\$f\" ]; then echo \"\$f\"; fi; done'" > /tmp/wheels_files.txt

# Get list of files from home directory
echo "Getting file list from home directory..."
adb exec-out "run-as com.termux sh -c 'for f in /data/data/com.termux/files/home/*.tar.gz /data/data/com.termux/files/home/*.zip; do if [ -f \"\$f\" ] && [ \"\$(basename \$f)\" != \"all_sources.tar.gz\" ] && [ \"\$(basename \$f)\" != \"sources.tar.gz\" ] && [ \"\$(basename \$f)\" != \"home_sources.tar.gz\" ]; then echo \"\$f\"; fi; done'" > /tmp/home_files.txt

# Copy files from wheels directory
echo "Copying files from wheels directory..."
while IFS= read -r filepath; do
    if [ -n "$filepath" ]; then
        filename=$(basename "$filepath")
        echo "  Copying $filename..."
        
        # Copy to temporary accessible location
        adb shell "run-as com.termux sh -c 'cp \"$filepath\" /data/data/com.termux/files/home/tmp_$filename && chmod 644 /data/data/com.termux/files/home/tmp_$filename'" 2>/dev/null
        
        # Pull the file
        if adb pull "/data/data/com.termux/files/home/tmp_$filename" "$TARGET_DIR/$filename" 2>/dev/null; then
            echo "    ✓ Copied $filename ($(du -h "$TARGET_DIR/$filename" | cut -f1))"
        else
            echo "    ✗ Failed to copy $filename"
        fi
        
        # Clean up
        adb shell "run-as com.termux sh -c 'rm -f /data/data/com.termux/files/home/tmp_$filename'" 2>/dev/null || true
        
        # Check device connection
        if ! adb devices | grep -q "device$"; then
            echo "ERROR: Device disconnected! Please reconnect and run again."
            exit 1
        fi
    fi
done < /tmp/wheels_files.txt

# Copy files from home directory
echo "Copying files from home directory..."
while IFS= read -r filepath; do
    if [ -n "$filepath" ]; then
        filename=$(basename "$filepath")
        # Skip if already exists
        if [ -f "$TARGET_DIR/$filename" ]; then
            echo "  Skipping $filename (already exists)"
            continue
        fi
        
        echo "  Copying $filename..."
        
        # Copy to temporary accessible location
        adb shell "run-as com.termux sh -c 'cp \"$filepath\" /data/data/com.termux/files/home/tmp_$filename && chmod 644 /data/data/com.termux/files/home/tmp_$filename'" 2>/dev/null
        
        # Pull the file
        if adb pull "/data/data/com.termux/files/home/tmp_$filename" "$TARGET_DIR/$filename" 2>/dev/null; then
            echo "    ✓ Copied $filename ($(du -h "$TARGET_DIR/$filename" | cut -f1))"
        else
            echo "    ✗ Failed to copy $filename"
        fi
        
        # Clean up
        adb shell "run-as com.termux sh -c 'rm -f /data/data/com.termux/files/home/tmp_$filename'" 2>/dev/null || true
        
        # Check device connection
        if ! adb devices | grep -q "device$"; then
            echo "ERROR: Device disconnected! Please reconnect and run again."
            exit 1
        fi
    fi
done < /tmp/home_files.txt

# Clean up temp files
rm -f /tmp/wheels_files.txt /tmp/home_files.txt

echo ""
echo "=== Summary ==="
echo "Total source files: $(find "$TARGET_DIR" -type f 2>/dev/null | wc -l)"
echo "Total size: $(du -sh "$TARGET_DIR" 2>/dev/null | cut -f1)"

