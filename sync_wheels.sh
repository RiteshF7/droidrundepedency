#!/usr/bin/env bash
# Sync pre-built wheels from Windows to Android device via ADB
# Usage: bash sync_wheels.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WHEELS_SOURCE="${SCRIPT_DIR}/depedencies/wheels/_x86_64_wheels"
ANDROID_DEST="/data/data/com.termux/files/home/droidrunBuild/depedencies/wheels/_x86_64_wheels"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1" >&2
}

# Check if wheels source directory exists
if [ ! -d "$WHEELS_SOURCE" ]; then
    log_error "Wheels source directory not found: $WHEELS_SOURCE"
    exit 1
fi

# Count wheels
WHEEL_COUNT=$(find "$WHEELS_SOURCE" -maxdepth 1 -name "*.whl" 2>/dev/null | wc -l)

if [ "$WHEEL_COUNT" -eq 0 ]; then
    log_error "No wheel files found in $WHEELS_SOURCE"
    exit 1
fi

log_info "Found $WHEEL_COUNT wheel files in $WHEELS_SOURCE"

# Check if ADB is available
if ! command -v adb >/dev/null 2>&1; then
    log_error "adb is not available. Please install Android SDK Platform Tools"
    exit 1
fi

# Check if device is connected
if ! adb devices | grep -q "device$"; then
    log_error "No Android device connected via ADB"
    log_info "Make sure USB debugging is enabled and device is connected"
    exit 1
fi

log_info "Android device detected"

# Create destination directory on Android device
log_info "Creating destination directory on Android device..."
adb shell "run-as com.termux sh -c 'mkdir -p $ANDROID_DEST'" || {
    log_error "Failed to create destination directory"
    exit 1
}

# Copy wheels to Android device
log_info "Copying wheels to Android device..."
log_info "Using Termux file sharing directory..."

# Try to use Termux's shared storage
TERMUX_SHARED="/sdcard/Android/data/com.termux/files"
COPIED=0
FAILED=0

# First, try to push to a temporary location that Termux can access
TEMP_DIR="/sdcard/Download/droidrun_wheels"
adb shell "mkdir -p $TEMP_DIR" 2>/dev/null || true

for wheel in "$WHEELS_SOURCE"/*.whl; do
    if [ -f "$wheel" ]; then
        wheel_name=$(basename "$wheel")
        log_info "Copying $wheel_name..."
        
        # Push to /sdcard/Download (accessible by Termux)
        if adb push "$wheel" "$TEMP_DIR/$wheel_name" >/dev/null 2>&1; then
            # Copy from Download to Termux directory using Termux's file access
            if adb shell "run-as com.termux sh -c 'export PREFIX=/data/data/com.termux/files/usr && export HOME=/data/data/com.termux/files/home && export PATH=\$PREFIX/bin:\$PATH && mkdir -p $ANDROID_DEST && cp /sdcard/Download/droidrun_wheels/$wheel_name $ANDROID_DEST/$wheel_name 2>&1'" >/dev/null 2>&1; then
                COPIED=$((COPIED + 1))
                # Cleanup temp file
                adb shell "rm $TEMP_DIR/$wheel_name" 2>/dev/null || true
            else
                # Alternative: Use termux-open-url or direct file access
                # Try using Termux's storage access
                if adb shell "run-as com.termux sh -c 'export PREFIX=/data/data/com.termux/files/usr && export HOME=/data/data/com.termux/files/home && export PATH=\$PREFIX/bin:\$PATH && if [ -d /sdcard/Download/droidrun_wheels ]; then cp /sdcard/Download/droidrun_wheels/$wheel_name $ANDROID_DEST/$wheel_name 2>&1; fi'" >/dev/null 2>&1; then
                    COPIED=$((COPIED + 1))
                    adb shell "rm $TEMP_DIR/$wheel_name" 2>/dev/null || true
                else
                    log_error "Failed to copy $wheel_name (Termux may need storage permission)"
                    log_info "  Run in Termux: termux-setup-storage"
                    FAILED=$((FAILED + 1))
                fi
            fi
        else
            log_error "Failed to push $wheel_name to device"
            FAILED=$((FAILED + 1))
        fi
    fi
done

# Cleanup temp directory
adb shell "rmdir $TEMP_DIR" 2>/dev/null || true

echo
log_success "Sync complete!"
echo "  Copied: $COPIED wheels"
if [ "$FAILED" -gt 0 ]; then
    log_error "  Failed: $FAILED wheels"
fi
echo
log_info "Wheels are now available at: $ANDROID_DEST"
log_info "Run 'bash build.sh' to use these pre-built wheels"

