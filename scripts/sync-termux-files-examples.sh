#!/bin/bash
# sync-termux-files-examples.sh
# Example usage scenarios for sync-termux-files.sh
#
# This file contains example commands that can be used with sync-termux-files.sh
# Copy and modify these examples for your specific use cases.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SYNC_SCRIPT="$SCRIPT_DIR/sync-termux-files.sh"

echo "Example usage scenarios for sync-termux-files.sh"
echo "================================================"
echo ""

# Example 1: Copy all .whl files from device pip cache to project
echo "Example 1: Copy all .whl files from device pip cache to project"
echo "Command:"
echo "$SYNC_SCRIPT -d from-device \\"
echo "  -s \"/data/data/com.termux/files/home/.cache/pip/wheels\" \\"
echo "  -t \"../arch64android/wheels\" \\"
echo "  -p \"*.whl\" \\"
echo "  -v"
echo ""

# Example 2: Copy all source archives from device home to project
echo "Example 2: Copy all source archives from device home to project"
echo "Command:"
echo "$SYNC_SCRIPT -d from-device \\"
echo "  -s \"/data/data/com.termux/files/home\" \\"
echo "  -t \"../arch64android/sources\" \\"
echo "  -p \"*.tar.gz\" \\"
echo "  -x \"*/.cache/*\" \\"
echo "  -r -m 3 \\"
echo "  -v"
echo ""

# Example 3: Copy all .zip files from device to project
echo "Example 3: Copy all .zip files from device to project"
echo "Command:"
echo "$SYNC_SCRIPT -d from-device \\"
echo "  -s \"/data/data/com.termux/files/home\" \\"
echo "  -t \"../arch64android/sources\" \\"
echo "  -p \"*.zip\" \\"
echo "  -x \"*/.cache/*\" \\"
echo "  -r -m 3 \\"
echo "  -v"
echo ""

# Example 4: Copy files from project to device
echo "Example 4: Copy .whl files from project to device"
echo "Command:"
echo "$SYNC_SCRIPT -d to-device \\"
echo "  -s \"../arch64android/wheels\" \\"
echo "  -t \"/data/data/com.termux/files/home/wheels\" \\"
echo "  -p \"*.whl\" \\"
echo "  -v"
echo ""

# Example 5: Copy source archives from project to device
echo "Example 5: Copy source archives from project to device"
echo "Command:"
echo "$SYNC_SCRIPT -d to-device \\"
echo "  -s \"../arch64android/sources\" \\"
echo "  -t \"/data/data/com.termux/files/home/sources\" \\"
echo "  -p \"*.tar.gz\" \\"
echo "  -v"
echo ""

# Example 6: Copy specific package files
echo "Example 6: Copy specific package (e.g., numpy) files"
echo "Command:"
echo "$SYNC_SCRIPT -d from-device \\"
echo "  -s \"/data/data/com.termux/files/home\" \\"
echo "  -t \"../arch64android/sources\" \\"
echo "  -p \"*numpy*\" \\"
echo "  -r -m 3 \\"
echo "  -v"
echo ""

echo "To use any of these examples, copy the command and run it in the scripts directory."
echo "Make sure your device is connected via ADB before running."

