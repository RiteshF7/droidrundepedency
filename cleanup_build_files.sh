#!/bin/bash
# Cleanup script to remove unnecessary build files and temporary artifacts
# Created for droidrun dependency project
#
# Usage:
#   ./cleanup_build_files.sh          # Run cleanup
#   ./cleanup_build_files.sh --dry-run # Preview what will be removed

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Check for dry-run mode
DRY_RUN=false
if [ "$1" = "--dry-run" ] || [ "$1" = "-n" ]; then
    DRY_RUN=true
    echo "=========================================="
    echo "Build Files Cleanup Script (DRY RUN)"
    echo "=========================================="
else
    echo "=========================================="
    echo "Build Files Cleanup Script"
    echo "=========================================="
fi
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
TOTAL_SIZE=0
FILES_REMOVED=0

# Function to format file size
format_size() {
    local bytes=$1
    if command -v numfmt >/dev/null 2>&1; then
        numfmt --to=iec-i --suffix=B "$bytes" 2>/dev/null
    else
        # Fallback: simple formatting
        if [ $bytes -lt 1024 ]; then
            echo "${bytes}B"
        elif [ $bytes -lt 1048576 ]; then
            echo "$((bytes / 1024))KB"
        elif [ $bytes -lt 1073741824 ]; then
            echo "$((bytes / 1048576))MB"
        else
            echo "$((bytes / 1073741824))GB"
        fi
    fi
}

# Function to remove files/dirs and track size
remove_item() {
    local item="$1"
    local description="$2"
    
    if [ -e "$item" ]; then
        local size=0
        if [ -d "$item" ]; then
            size=$(du -sb "$item" 2>/dev/null | cut -f1 || echo 0)
            if [ "$DRY_RUN" = true ]; then
                echo -e "${BLUE}[WOULD REMOVE]${NC} Directory: $description ($(format_size $size))"
            else
                rm -rf "$item" 2>/dev/null && {
                    echo -e "${GREEN}[REMOVED]${NC} Directory: $description ($(format_size $size))"
                    TOTAL_SIZE=$((TOTAL_SIZE + size))
                    ((FILES_REMOVED++))
                }
            fi
        elif [ -f "$item" ]; then
            # Try different stat commands for different systems
            if stat -f%z "$item" >/dev/null 2>&1; then
                size=$(stat -f%z "$item" 2>/dev/null || echo 0)
            else
                size=$(stat -c%s "$item" 2>/dev/null || echo 0)
            fi
            if [ "$DRY_RUN" = true ]; then
                echo -e "${BLUE}[WOULD REMOVE]${NC} File: $description ($(format_size $size))"
            else
                rm -f "$item" 2>/dev/null && {
                    echo -e "${GREEN}[REMOVED]${NC} File: $description ($(format_size $size))"
                    TOTAL_SIZE=$((TOTAL_SIZE + size))
                    ((FILES_REMOVED++))
                }
            fi
        fi
    fi
}

# Function to find and remove files by pattern
remove_pattern() {
    local pattern="$1"
    local description="$2"
    
    while IFS= read -r -d '' file; do
        remove_item "$file" "$description: $(basename "$file")"
    done < <(find . -type f -name "$pattern" ! -path "./.git/*" ! -path "./termux-packages/*" -print0 2>/dev/null)
}

# Function to find and remove directories by pattern
remove_dir_pattern() {
    local pattern="$1"
    local description="$2"
    
    while IFS= read -r -d '' dir; do
        remove_item "$dir" "$description: $(basename "$dir")"
    done < <(find . -type d -name "$pattern" ! -path "./.git/*" ! -path "./termux-packages/*" -print0 2>/dev/null)
}

echo "Starting cleanup..."
echo ""

# 1. Remove build log files
echo "1. Removing build log files..."
remove_pattern "*.log" "Build log"
remove_pattern "build_*.log" "Build log"
remove_pattern "*_build.log" "Build log"
remove_pattern "installation*.log" "Installation log"
remove_pattern "build_output.log" "Build output log"
remove_pattern "termux_error_log.txt" "Termux error log"

# 2. Remove Python cache files and directories
echo ""
echo "2. Removing Python cache files..."
remove_dir_pattern "__pycache__" "Python cache"
remove_pattern "*.pyc" "Python bytecode"
remove_pattern "*.pyo" "Python optimized bytecode"
remove_pattern "*.pyd" "Python extension (if any)"

# 3. Remove Python build artifacts
echo ""
echo "3. Removing Python build artifacts..."
remove_dir_pattern "*.egg-info" "Python egg-info"
remove_dir_pattern "dist" "Distribution directory"
remove_dir_pattern "build" "Build directory"
remove_dir_pattern ".eggs" "Eggs directory"
remove_pattern "*.egg" "Python egg"

# 4. Remove test and cache directories
echo ""
echo "4. Removing test and cache directories..."
remove_dir_pattern ".pytest_cache" "Pytest cache"
remove_dir_pattern ".mypy_cache" "Mypy cache"
remove_dir_pattern ".coverage" "Coverage data"
remove_dir_pattern ".tox" "Tox virtualenv"
remove_dir_pattern ".cache" "Cache directory"
remove_dir_pattern ".ruff_cache" "Ruff cache"

# 5. Remove temporary files
echo ""
echo "5. Removing temporary files..."
remove_pattern "*.tmp" "Temporary file"
remove_pattern "*.temp" "Temporary file"
remove_pattern "*.swp" "Vim swap file"
remove_pattern "*.swo" "Vim swap file"
remove_pattern "*~" "Backup file"
remove_pattern ".DS_Store" "macOS metadata"

# 6. Remove specific build artifacts
echo ""
echo "6. Removing specific build artifacts..."
remove_item "build_grpcio_fixed.log" "grpcio build log"
remove_item "build_grpcio_retry.log" "grpcio retry log"
remove_item "build_grpcio_v2.log" "grpcio v2 log"
remove_item "build_grpcio.log" "grpcio build log"
remove_item "build_orjson.log" "orjson build log"
remove_item "build_output.log" "Build output log"
remove_item "installation.log" "Installation log"
remove_item "installation_output.log" "Installation output log"
remove_item "termux_error_log.txt" "Termux error log"

# 7. Remove wheel build artifacts (keep wheels directory but clean temp files)
echo ""
echo "7. Cleaning wheel build artifacts..."
if [ -d "wheels" ]; then
    find wheels -type f \( -name "*.tar.gz" -o -name "*.zip" -o -name "*.tgz" \) ! -name "*.whl" 2>/dev/null | while read -r file; do
        remove_item "$file" "Wheel source archive: $(basename "$file")"
    done
fi

# 8. Remove laptoptermuxbuild logs
echo ""
echo "8. Cleaning laptoptermuxbuild logs..."
if [ -d "laptoptermuxbuild/logs" ]; then
    remove_dir_pattern "laptoptermuxbuild/logs" "Laptop Termux build logs"
fi

# 9. Remove backup/old files (optional - commented out by default)
# Uncomment if you want to remove old backups
# echo ""
# echo "9. Removing old backup files..."
# remove_pattern "*.bak" "Backup file"
# remove_pattern "*.old" "Old file"

# Summary
echo ""
echo "=========================================="
if [ "$DRY_RUN" = true ]; then
    echo "Dry Run Summary"
    echo "=========================================="
    echo -e "${BLUE}Files/Directories that would be removed:${NC} $FILES_REMOVED"
    if [ $TOTAL_SIZE -gt 0 ]; then
        echo -e "${BLUE}Total space that would be freed:${NC} $(format_size $TOTAL_SIZE)"
    else
        echo -e "${YELLOW}Total space that would be freed:${NC} Unable to calculate"
    fi
    echo ""
    echo -e "${YELLOW}This was a dry run. No files were actually removed.${NC}"
    echo -e "${YELLOW}Run without --dry-run to perform the cleanup.${NC}"
else
    echo "Cleanup Summary"
    echo "=========================================="
    echo -e "${GREEN}Files/Directories removed:${NC} $FILES_REMOVED"
    if [ $TOTAL_SIZE -gt 0 ]; then
        echo -e "${GREEN}Total space freed:${NC} $(format_size $TOTAL_SIZE)"
    else
        echo -e "${YELLOW}Total space freed:${NC} Unable to calculate"
    fi
    echo ""
    echo -e "${GREEN}Cleanup completed!${NC}"
fi
echo ""

# Show remaining disk usage
echo "Current directory size:"
du -sh . 2>/dev/null | awk '{print "  " $1}'
echo ""

