#!/bin/bash
# copy-droidrun-deps.sh
# Copy all droidrun dependencies (.whl files and source files) from Android device to arch64android directory
#
# Usage: ./copy-droidrun-deps.sh

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TARGET_DIR="$PROJECT_ROOT/arch64android"
SITE_PACKAGES="/data/data/com.termux/files/usr/lib/python3.12/site-packages"
TEMP_DIR="/data/data/com.termux/files/home/droidrun_deps_temp"

echo -e "${BLUE}Copying droidrun dependencies from device...${NC}"

# Check if device is connected
if ! adb devices | grep -q "device$"; then
    echo -e "${RED}Error: No Android device connected. Please connect your device and try again.${NC}"
    exit 1
fi

# Create target directory structure
mkdir -p "$TARGET_DIR/wheels"
mkdir -p "$TARGET_DIR/sources"
mkdir -p "$TARGET_DIR/dist-info"

echo -e "${YELLOW}Step 1: Creating archive on device...${NC}"

# Create a temporary directory on device and copy all site-packages
adb shell "run-as com.termux sh -c '
    cd /data/data/com.termux/files/usr/lib/python3.12/site-packages
    
    # Create archive excluding cache files
    tar -czf /data/data/com.termux/files/home/droidrun_deps.tar.gz \\
        --exclude=\"__pycache__\" \\
        --exclude=\"*.pyc\" \\
        --exclude=\"*.pyo\" \\
        --exclude=\"*.so\" \\
        .
    
    echo \"Archive created\"
'"

if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Failed to create archive on device${NC}"
    exit 1
fi

echo -e "${YELLOW}Step 2: Downloading archive...${NC}"

# Pull the archive
adb pull /data/data/com.termux/files/home/droidrun_deps.tar.gz "$TARGET_DIR/" || {
    echo -e "${RED}Error: Failed to download archive${NC}"
    exit 1
}

echo -e "${YELLOW}Step 3: Extracting archive...${NC}"

# Extract the archive
cd "$TARGET_DIR"
tar -xzf droidrun_deps.tar.gz
rm droidrun_deps.tar.gz

echo -e "${YELLOW}Step 4: Organizing files...${NC}"

# Move .whl files to wheels directory (if any exist in the extracted files)
find . -maxdepth 1 -name "*.whl" -type f -exec mv {} wheels/ \; 2>/dev/null || true

# Copy .dist-info directories to dist-info directory
find . -maxdepth 1 -name "*.dist-info" -type d -exec cp -r {} dist-info/ \; 2>/dev/null || true

# Copy source packages (directories that are not .dist-info)
find . -maxdepth 1 -type d ! -name "." ! -name "wheels" ! -name "sources" ! -name "dist-info" ! -name "*.dist-info" -exec cp -r {} sources/ \; 2>/dev/null || true

# Also get .whl files from pip cache if available
echo -e "${YELLOW}Step 5: Checking for .whl files in pip cache...${NC}"

adb shell "run-as com.termux sh -c '
    find /data/data/com.termux/files/home/.cache/pip/wheels -name \"*.whl\" -type f 2>/dev/null | head -100
'" | while read -r wheel_path; do
    if [ -n "$wheel_path" ]; then
        wheel_name=$(basename "$wheel_path")
        echo "  Copying $wheel_name..."
        adb pull "$wheel_path" "$TARGET_DIR/wheels/" 2>/dev/null || true
    fi
done

# Clean up device
adb shell "run-as com.termux sh -c 'rm -f /data/data/com.termux/files/home/droidrun_deps.tar.gz'" 2>/dev/null || true

# Count files
WHEEL_COUNT=$(find "$TARGET_DIR/wheels" -name "*.whl" -type f 2>/dev/null | wc -l || echo "0")
SOURCE_COUNT=$(find "$TARGET_DIR/sources" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l || echo "0")
DISTINFO_COUNT=$(find "$TARGET_DIR/dist-info" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l || echo "0")

echo -e "${GREEN}✓ Copy complete!${NC}"
echo -e "  Wheels: ${WHEEL_COUNT}"
echo -e "  Source packages: ${SOURCE_COUNT}"
echo -e "  Distribution info: ${DISTINFO_COUNT}"
echo -e "${BLUE}Files saved to: $TARGET_DIR${NC}"

