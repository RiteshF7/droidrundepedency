#!/bin/bash
# Script to track newly installed Python packages and export their wheel files
# Usage: ./track-and-export-wheels.sh [package-name] [package-name2] ...
#   or: ./track-and-export-wheels.sh --install "package-name"
#
# This script will:
# 1. Install packages (if --install flag is used)
# 2. Build/download wheel files for installed packages
# 3. Copy all wheel files to the export directory
# 4. Track what was installed

set -e

# Configuration
# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

EXPORT_DIR_LOCAL="$PROJECT_ROOT/droidrunBuild/newwhlfilesall"
EXPORT_DIR_TERMUX="/data/user/0/com.termux/wheels-export"
TERMUX_HOME="/data/user/0/com.termux/files/home"
TRACK_FILE_LOCAL="$EXPORT_DIR_LOCAL/installed-packages.txt"
TRACK_FILE_TERMUX="/data/user/0/com.termux/wheels-export/installed-packages.txt"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if device is connected
check_adb_connection() {
    if ! adb devices | grep -q "device$"; then
        print_error "No Android device connected via ADB"
        exit 1
    fi
    print_success "ADB device connected"
}

# Function to get currently installed packages
get_installed_packages() {
    adb shell "run-as com.termux sh -c 'export PATH=/data/data/com.termux/files/usr/bin:\$PATH && pip list --format=freeze | cut -d= -f1'" 2>/dev/null | tr -d '\r' | sort
}

# Function to get previously tracked packages
get_tracked_packages() {
    if [ -f "$TRACK_FILE_LOCAL" ]; then
        cat "$TRACK_FILE_LOCAL" | sort
    else
        echo ""
    fi
}

# Function to find new packages
find_new_packages() {
    local current=$(get_installed_packages)
    local tracked=$(get_tracked_packages)
    
    # Find packages in current but not in tracked
    comm -23 <(echo "$current") <(echo "$tracked") 2>/dev/null || echo "$current"
}

# Function to install package and build wheel
install_and_build_wheel() {
    local package="$1"
    print_info "Installing and building wheel for: $package"
    
    # Install the package
    adb shell "run-as com.termux sh -c 'export PATH=/data/data/com.termux/files/usr/bin:\$PATH && pip install \"$package\"'" > /dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        print_success "Installed: $package"
    else
        print_error "Failed to install: $package"
        return 1
    fi
    
    # Build/download wheel
    print_info "Building wheel for: $package"
    adb shell "run-as com.termux sh -c 'export PATH=/data/data/com.termux/files/usr/bin:\$PATH && mkdir -p $EXPORT_DIR_TERMUX && pip wheel --no-deps --wheel-dir $EXPORT_DIR_TERMUX \"$package\"'" > /dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        print_success "Wheel built for: $package"
    else
        print_warning "Failed to build wheel for: $package (may already exist or be pure Python)"
    fi
}

# Function to export all wheels from Termux to local
export_wheels_to_local() {
    print_info "Exporting wheels from device to local directory..."
    
    # Create local export directory
    mkdir -p "$EXPORT_DIR_LOCAL"
    
    # Get list of all wheel files on device
    local wheel_files=$(adb shell "find $EXPORT_DIR_TERMUX -name '*.whl' -type f 2>/dev/null" | grep -v '.cargo/registry' | grep -v 'tests/fixtures' | tr -d '\r')
    
    if [ -z "$wheel_files" ]; then
        print_warning "No wheel files found in $EXPORT_DIR_TERMUX"
        return 1
    fi
    
    local count=0
    while IFS= read -r wheel_file; do
        if [ -z "$wheel_file" ]; then
            continue
        fi
        
        local filename=$(basename "$wheel_file")
        local local_path="$EXPORT_DIR_LOCAL/$filename"
        
        # Skip if already exists locally
        if [ -f "$local_path" ]; then
            print_info "Skipping (already exists): $filename"
            continue
        fi
        
        # Copy file using adb shell cat (works with root)
        print_info "Copying: $filename"
        adb shell "cat \"$wheel_file\"" > "$local_path" 2>/dev/null
        
        if [ -f "$local_path" ] && [ -s "$local_path" ]; then
            print_success "Exported: $filename"
            count=$((count + 1))
        else
            print_error "Failed to export: $filename"
            rm -f "$local_path"
        fi
    done <<< "$wheel_files"
    
    print_success "Exported $count wheel file(s)"
}

# Function to update tracking file
update_tracking() {
    print_info "Updating package tracking..."
    
    local installed=$(get_installed_packages)
    echo "$installed" > "$TRACK_FILE_LOCAL"
    
    # Also update on device
    echo "$installed" | adb shell "run-as com.termux sh -c 'cat > $TRACK_FILE_TERMUX'" 2>/dev/null
    
    print_success "Tracking updated"
}

# Function to show summary
show_summary() {
    echo ""
    echo "=========================================="
    echo "Summary"
    echo "=========================================="
    
    local local_count=$(ls -1 "$EXPORT_DIR_LOCAL"/*.whl 2>/dev/null | wc -l)
    local local_size=$(du -sh "$EXPORT_DIR_LOCAL" 2>/dev/null | cut -f1)
    
    echo "Local export directory: $EXPORT_DIR_LOCAL"
    echo "Total wheel files: $local_count"
    echo "Total size: $local_size"
    echo ""
    
    if [ -f "$TRACK_FILE_LOCAL" ]; then
        local tracked_count=$(wc -l < "$TRACK_FILE_LOCAL")
        echo "Tracked packages: $tracked_count"
    fi
}

# Main function
main() {
    check_adb_connection
    
    local install_mode=false
    local packages=()
    
    # Parse arguments
    if [ "$1" == "--install" ]; then
        install_mode=true
        shift
        packages=("$@")
    elif [ "$1" == "--export-only" ]; then
        # Just export existing wheels
        export_wheels_to_local
        show_summary
        exit 0
    elif [ "$1" == "--track-new" ]; then
        # Track and export new packages only
        print_info "Finding newly installed packages..."
        local new_packages=$(find_new_packages)
        
        if [ -z "$new_packages" ]; then
            print_info "No new packages found"
        else
            echo "$new_packages" | while read -r pkg; do
                if [ -n "$pkg" ]; then
                    print_info "Found new package: $pkg"
                    install_and_build_wheel "$pkg"
                fi
            done
        fi
        
        export_wheels_to_local
        update_tracking
        show_summary
        exit 0
    else
        packages=("$@")
    fi
    
    # Install packages if provided
    if [ ${#packages[@]} -gt 0 ]; then
        print_info "Installing ${#packages[@]} package(s)..."
        for package in "${packages[@]}"; do
            install_and_build_wheel "$package"
        done
    fi
    
    # Export all wheels
    export_wheels_to_local
    
    # Update tracking
    update_tracking
    
    # Show summary
    show_summary
}

# Run main function
main "$@"

