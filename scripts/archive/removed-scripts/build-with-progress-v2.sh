#!/bin/bash
# build-with-progress-v2.sh - Build with full progress visibility

set -e

ADB="${LOCALAPPDATA}/Android/Sdk/platform-tools/adb.exe"
TERMUX_BASH="/data/data/com.termux/files/usr/bin/bash"
TERMUX_HOME="/data/data/com.termux/files/home"
LOG_FILE="build-progress.log"

# Color codes for better visibility
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo "=========================================="
echo "  Building droidrun[google] wheels"
echo "  Progress will be shown in real-time"
echo "=========================================="
echo ""
echo "Log file: $LOG_FILE"
echo ""

# Create log file
> "$LOG_FILE"

# Function to show progress
show_progress() {
    local msg="$1"
    local color="${2:-NC}"
    timestamp="[$(date '+%H:%M:%S')]"
    echo -e "${!color}${timestamp} ${msg}${NC}" | tee -a "$LOG_FILE"
}

# Check emulator
show_progress "Checking emulator connection..." YELLOW
"$ADB" devices | grep -q "emulator" || {
    show_progress "❌ Error: No emulator detected" RED
    exit 1
}
show_progress "✅ Emulator connected" GREEN

# Get architecture
ARCH=$("$ADB" shell "run-as com.termux $TERMUX_BASH -c 'uname -m'" | tr -d '\r\n ')
show_progress "Architecture: $ARCH" YELLOW
echo ""

# Execute build with live output
show_progress "Starting build process in Termux..." YELLOW
echo ""

"$ADB" shell "run-as com.termux $TERMUX_BASH -c '
export PREFIX=/data/data/com.termux/files/usr
export HOME=$TERMUX_HOME
export PATH=\$PREFIX/bin:\$PATH

cd \$HOME
mkdir -p wheels
cd wheels

echo \"========================================\"
echo \"  STEP 1: Downloading packages\"
echo \"========================================\"
echo \"\"

# Download source distributions (skip binary wheels for now to avoid build issues)
echo \"Downloading source distributions...\"
pip download \"droidrun[google]\" --dest . --no-binary :all: --no-cache-dir 2>&1 | tee /tmp/download.log

# Also try to download any available binary wheels
echo \"\"
echo \"Downloading available binary wheels...\"
pip download \"droidrun[google]\" --dest . --prefer-binary --no-cache-dir 2>&1 | grep -E \"Downloading|Saved|already\" || true

echo \"\"
echo \"========================================\"
echo \"  STEP 2: Building wheels\"
echo \"========================================\"
echo \"\"

wheel_count=0
source_count=\$(find . -maxdepth 1 -name \"*.tar.gz\" 2>/dev/null | wc -l)
echo \"Source packages to build: \$source_count\"
echo \"\"

for src in *.tar.gz; do
    if [ -f \"\$src\" ]; then
        wheel_file=\${src%.tar.gz}.whl
        if [ ! -f \"\$wheel_file\" ]; then
            wheel_count=\$((wheel_count + 1))
            echo \"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\"
            echo \"[BUILD \$wheel_count/\$source_count] Building: \$src\"
            echo \"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\"
            
            if pip wheel --no-deps --wheel-dir . \"\$src\" 2>&1 | tee /tmp/wheel-\$wheel_count.log; then
                echo \"✅ Successfully built: \$src\"
            else
                echo \"❌ Failed to build: \$src (check logs)\"
            fi
            echo \"\"
        fi
    fi
done

echo \"========================================\"
echo \"  BUILD SUMMARY\"
echo \"========================================\"
echo \"Architecture: $ARCH\"
echo \"Total wheels: \$(find . -maxdepth 1 -name \"*.whl\" 2>/dev/null | wc -l)\"
echo \"Total sources: \$(find . -maxdepth 1 -name \"*.tar.gz\" 2>/dev/null | wc -l)\"
echo \"Total size: \$(du -sh . | awk \"{print \\\$1}\")\"
echo \"========================================\"
'" 2>&1 | while IFS= read -r line; do
    timestamp="[$(date '+%H:%M:%S')]"
    echo "$timestamp $line" | tee -a "$LOG_FILE"
done

echo ""

# Copy wheels
show_progress "Copying wheels to Windows..." YELLOW
DEST_DIR="termux-packages/wheels/${ARCH}"
mkdir -p "$DEST_DIR"

"$ADB" pull "${TERMUX_HOME}/wheels" "$DEST_DIR/" 2>&1 | tee -a "$LOG_FILE"

if [ $? -eq 0 ] && [ -d "$DEST_DIR/wheels" ]; then
    echo ""
    show_progress "✅ Successfully copied wheels!" GREEN
    echo ""
    echo "=========================================="
    echo "  BUILD COMPLETE!"
    echo "=========================================="
    echo ""
    echo "Wheels location: $DEST_DIR/wheels"
    echo "Total wheels: $(find "$DEST_DIR/wheels" -name "*.whl" 2>/dev/null | wc -l)"
    echo "Log file: $LOG_FILE"
    echo ""
else
    echo ""
    show_progress "⚠️  Copy failed. Wheels are in emulator at: ${TERMUX_HOME}/wheels" YELLOW
    echo ""
    echo "Copy manually with:"
    echo "  adb pull ${TERMUX_HOME}/wheels $DEST_DIR/"
    echo ""
fi




