#!/usr/bin/env bash
# Sync pre-built wheels from Windows to Android device via ADB
# Usage: bash sync_wheels.sh
#
# This script:
# 1. Pushes wheels to /sdcard/Download/droidrun_wheels on Android device
# 2. Then runs copy_wheels.sh on the device to move them to Termux directory

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

# Push wheels to Android device shared storage
log_info "Pushing wheels to Android device (/sdcard/Download/droidrun_wheels)..."
TEMP_DIR="/sdcard/Download/droidrun_wheels"

# Remove old directory and create new one
adb shell "rm -rf $TEMP_DIR" 2>/dev/null || true
adb shell "mkdir -p $TEMP_DIR" 2>/dev/null || true

# Push entire directory
if adb push "$WHEELS_SOURCE" "$TEMP_DIR" >/dev/null 2>&1; then
    log_success "Pushed wheels to $TEMP_DIR"
    
    # Now copy to Termux directory using copy_wheels.sh
    log_info "Copying wheels to Termux directory..."
    COPY_SCRIPT="${SCRIPT_DIR}/copy_wheels.sh"
    
    if [ -f "$COPY_SCRIPT" ]; then
        # Push copy script to device
        adb push "$COPY_SCRIPT" "/sdcard/Download/copy_wheels.sh" >/dev/null 2>&1
        
        # Run copy script on device
        if adb shell "run-as com.termux bash < /sdcard/Download/copy_wheels.sh" 2>&1 | tee /tmp/wheel_copy.log; then
            COPIED=$(grep -c "Copied:" /tmp/wheel_copy.log 2>/dev/null || echo "0")
            if [ "$COPIED" -gt 0 ]; then
                log_success "Successfully copied wheels to Termux directory"
            else
                log_warning "Copy completed but no wheels were copied (check logs)"
            fi
        else
            log_error "Failed to copy wheels to Termux directory"
            log_info "Try running manually in Termux:"
            log_info "  bash <(cat copy_wheels.sh)"
        fi
        
        # Cleanup
        adb shell "rm /sdcard/Download/copy_wheels.sh" 2>/dev/null || true
    else
        log_warning "copy_wheels.sh not found, using manual method..."
        # Manual copy
        COPIED=0
        for wheel in "$WHEELS_SOURCE"/*.whl; do
            if [ -f "$wheel" ]; then
                wheel_name=$(basename "$wheel")
                if adb shell "run-as com.termux sh -c 'export PREFIX=/data/data/com.termux/files/usr && export HOME=/data/data/com.termux/files/home && export PATH=\$PREFIX/bin:\$PATH && mkdir -p $ANDROID_DEST && cp /sdcard/Download/droidrun_wheels/_x86_64_wheels/$wheel_name $ANDROID_DEST/$wheel_name 2>&1'" >/dev/null 2>&1; then
                    COPIED=$((COPIED + 1))
                fi
            fi
        done
        if [ "$COPIED" -gt 0 ]; then
            log_success "Copied $COPIED wheels manually"
        fi
    fi
else
    log_error "Failed to push wheels to device"
    FAILED=$WHEEL_COUNT
fi

echo
log_success "Sync complete!"
echo "  Copied: $COPIED wheels"
if [ "$FAILED" -gt 0 ]; then
    log_error "  Failed: $FAILED wheels"
fi
echo
log_info "Wheels are now available at: $ANDROID_DEST"
log_info "Run 'bash build.sh' to use these pre-built wheels"

