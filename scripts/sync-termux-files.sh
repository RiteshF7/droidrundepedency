#!/bin/bash
# sync-termux-files.sh
# Bidirectional file sync script between project and Termux device
# Based on reliable adb exec-out method for file transfer
#
# Usage:
#   ./sync-termux-files.sh [OPTIONS]
#
# Options:
#   -d, --direction DIRECTION    Transfer direction: 'to-device' or 'from-device' (default: from-device)
#   -s, --source PATH            Source path (project path for to-device, device path for from-device)
#   -t, --target PATH            Target path (device path for to-device, project path for from-device)
#   -p, --pattern PATTERN        File pattern to match (e.g., "*.whl", "*.tar.gz", "*.zip")
#   -r, --recursive              Search recursively (up to maxdepth 3)
#   -m, --maxdepth DEPTH         Maximum depth for recursive search (default: 3)
#   -x, --exclude PATTERN        Exclude pattern (e.g., "*/.cache/*")
#   -v, --verbose                Verbose output
#   -h, --help                   Show help message
#
# Examples:
#   # Copy all .whl files from device to project
#   ./sync-termux-files.sh -d from-device -s "/data/data/com.termux/files/home/.cache/pip/wheels" -t "../arch64android/wheels" -p "*.whl"
#
#   # Copy all source archives from device to project
#   ./sync-termux-files.sh -d from-device -s "/data/data/com.termux/files/home" -t "../arch64android/sources" -p "*.tar.gz" -x "*/.cache/*"
#
#   # Copy files from project to device
#   ./sync-termux-files.sh -d to-device -s "../arch64android/wheels" -t "/data/data/com.termux/files/home/wheels" -p "*.whl"

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
DIRECTION="from-device"
SOURCE_PATH=""
TARGET_PATH=""
PATTERN="*"
RECURSIVE=false
MAXDEPTH=3
EXCLUDE_PATTERN=""
VERBOSE=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--direction)
            DIRECTION="$2"
            shift 2
            ;;
        -s|--source)
            SOURCE_PATH="$2"
            shift 2
            ;;
        -t|--target)
            TARGET_PATH="$2"
            shift 2
            ;;
        -p|--pattern)
            PATTERN="$2"
            shift 2
            ;;
        -r|--recursive)
            RECURSIVE=true
            shift
            ;;
        -m|--maxdepth)
            MAXDEPTH="$2"
            shift 2
            ;;
        -x|--exclude)
            EXCLUDE_PATTERN="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            cat << EOF
Usage: $0 [OPTIONS]

Bidirectional file sync script between project and Termux device.

Options:
  -d, --direction DIRECTION    Transfer direction: 'to-device' or 'from-device' (default: from-device)
  -s, --source PATH            Source path
  -t, --target PATH            Target path
  -p, --pattern PATTERN        File pattern to match (default: *)
  -r, --recursive              Search recursively
  -m, --maxdepth DEPTH         Maximum depth for recursive search (default: 3)
  -x, --exclude PATTERN        Exclude pattern
  -v, --verbose                Verbose output
  -h, --help                   Show this help message

Examples:
  # Copy .whl files from device to project
  $0 -d from-device -s "/data/data/com.termux/files/home/.cache/pip/wheels" \\
     -t "../arch64android/wheels" -p "*.whl"

  # Copy source archives from device to project
  $0 -d from-device -s "/data/data/com.termux/files/home" \\
     -t "../arch64android/sources" -p "*.tar.gz" -x "*/.cache/*" -r

  # Copy files from project to device
  $0 -d to-device -s "../arch64android/wheels" \\
     -t "/data/data/com.termux/files/home/wheels" -p "*.whl"
EOF
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

# Validate required parameters
if [ -z "$SOURCE_PATH" ] || [ -z "$TARGET_PATH" ]; then
    echo -e "${RED}Error: Source and target paths are required${NC}"
    echo "Use -h or --help for usage information"
    exit 1
fi

if [ "$DIRECTION" != "from-device" ] && [ "$DIRECTION" != "to-device" ]; then
    echo -e "${RED}Error: Direction must be 'from-device' or 'to-device'${NC}"
    exit 1
fi

# Check if device is connected
if ! adb devices | grep -q "device$"; then
    echo -e "${RED}Error: No Android device connected. Please connect your device and try again.${NC}"
    exit 1
fi

# Function to copy file from device to project
copy_from_device() {
    local device_path="$1"
    local project_path="$2"
    local filename=$(basename "$device_path")
    
    if [ "$VERBOSE" = true ]; then
        echo -e "${YELLOW}Copying $filename from device...${NC}"
    fi
    
    # Create target directory if it doesn't exist
    mkdir -p "$(dirname "$project_path/$filename")"
    
    # Copy file using adb exec-out
    if adb exec-out "run-as com.termux sh -c 'cat \"$device_path\"'" > "$project_path/$filename" 2>/dev/null; then
        if [ "$VERBOSE" = true ]; then
            local size=$(du -h "$project_path/$filename" 2>/dev/null | cut -f1 || echo "unknown")
            echo -e "${GREEN}  ✓ Copied $filename ($size)${NC}"
        fi
        return 0
    else
        if [ "$VERBOSE" = true ]; then
            echo -e "${RED}  ✗ Failed to copy $filename${NC}"
        fi
        return 1
    fi
}

# Function to copy file from project to device
copy_to_device() {
    local project_path="$1"
    local device_path="$2"
    local filename=$(basename "$project_path")
    
    if [ "$VERBOSE" = true ]; then
        echo -e "${YELLOW}Copying $filename to device...${NC}"
    fi
    
    # Create temporary file on device
    local temp_path="/data/data/com.termux/files/home/tmp_$filename"
    
    # Push file to temporary location
    if adb push "$project_path" "$temp_path" 2>/dev/null; then
        # Move to target location using run-as
        if adb shell "run-as com.termux sh -c 'mkdir -p \"$(dirname "$device_path")\" && mv \"$temp_path\" \"$device_path\" && chmod 644 \"$device_path\"'" 2>/dev/null; then
            if [ "$VERBOSE" = true ]; then
                local size=$(du -h "$project_path" 2>/dev/null | cut -f1 || echo "unknown")
                echo -e "${GREEN}  ✓ Copied $filename ($size)${NC}"
            fi
            return 0
        else
            # Clean up temp file
            adb shell "run-as com.termux sh -c 'rm -f \"$temp_path\"'" 2>/dev/null || true
            if [ "$VERBOSE" = true ]; then
                echo -e "${RED}  ✗ Failed to move $filename to target location${NC}"
            fi
            return 1
        fi
    else
        if [ "$VERBOSE" = true ]; then
            echo -e "${RED}  ✗ Failed to push $filename${NC}"
        fi
        return 1
    fi
}

# Main execution
echo -e "${BLUE}Starting file sync: $DIRECTION${NC}"
echo -e "Source: $SOURCE_PATH"
echo -e "Target: $TARGET_PATH"
echo -e "Pattern: $PATTERN"
echo ""

if [ "$DIRECTION" = "from-device" ]; then
    # Copy from device to project
    echo -e "${YELLOW}Searching for files on device...${NC}"
    
    # Build find command
    local find_cmd="find \"$SOURCE_PATH\""
    
    if [ "$RECURSIVE" = true ]; then
        find_cmd="$find_cmd -maxdepth $MAXDEPTH"
    else
        find_cmd="$find_cmd -maxdepth 1"
    fi
    
    find_cmd="$find_cmd -name \"$PATTERN\" -type f"
    
    if [ -n "$EXCLUDE_PATTERN" ]; then
        find_cmd="$find_cmd ! -path \"$EXCLUDE_PATTERN\""
    fi
    
    find_cmd="$find_cmd 2>/dev/null"
    
    # Execute find and copy files
    local count=0
    local success=0
    local failed=0
    
    adb exec-out "run-as com.termux sh -c '$find_cmd'" | while IFS= read -r filepath; do
        if [ -n "$filepath" ]; then
            count=$((count + 1))
            if copy_from_device "$filepath" "$TARGET_PATH"; then
                success=$((success + 1))
            else
                failed=$((failed + 1))
            fi
        fi
    done
    
    echo ""
    echo -e "${GREEN}✓ Sync complete!${NC}"
    echo -e "  Files processed: $count"
    echo -e "  Successful: $success"
    echo -e "  Failed: $failed"
    
elif [ "$DIRECTION" = "to-device" ]; then
    # Copy from project to device
    echo -e "${YELLOW}Searching for files in project...${NC}"
    
    # Build find command for local files
    local find_cmd="find \"$SOURCE_PATH\""
    
    if [ "$RECURSIVE" = true ]; then
        find_cmd="$find_cmd -maxdepth $MAXDEPTH"
    else
        find_cmd="$find_cmd -maxdepth 1"
    fi
    
    find_cmd="$find_cmd -name \"$PATTERN\" -type f"
    
    if [ -n "$EXCLUDE_PATTERN" ]; then
        find_cmd="$find_cmd ! -path \"$EXCLUDE_PATTERN\""
    fi
    
    # Execute find and copy files
    local count=0
    local success=0
    local failed=0
    
    while IFS= read -r filepath; do
        if [ -n "$filepath" ]; then
            count=$((count + 1))
            if copy_to_device "$filepath" "$TARGET_PATH"; then
                success=$((success + 1))
            else
                failed=$((failed + 1))
            fi
        fi
    done < <(eval "$find_cmd")
    
    echo ""
    echo -e "${GREEN}✓ Sync complete!${NC}"
    echo -e "  Files processed: $count"
    echo -e "  Successful: $success"
    echo -e "  Failed: $failed"
fi

echo -e "${BLUE}Files saved to: $TARGET_PATH${NC}"

