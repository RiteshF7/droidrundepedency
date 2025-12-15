#!/bin/bash
# build-all.sh
# Master build script that combines the best features of all build scripts
# This is the recommended script to use for building droidrun[google] dependencies

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source common functions if available
if [ -f "$SCRIPT_DIR/../utils/common.sh" ]; then
    source "$SCRIPT_DIR/../utils/common.sh"
fi

# Configuration
WHEELS_DIR="$HOME/wheels"
LOG_FILE="$WHEELS_DIR/build-all.log"
ADB="${LOCALAPPDATA}/Android/Sdk/platform-tools/adb.exe"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Functions
log() {
    echo -e "${BLUE}[$(date +%H:%M:%S)]${NC} $1" | tee -a "$LOG_FILE"
}

success() {
    echo -e "${GREEN}✓${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}✗${NC} $1" | tee -a "$LOG_FILE"
}

warning() {
    echo -e "${YELLOW}⚠${NC} $1" | tee -a "$LOG_FILE"
}

# Check if emulator is running
check_emulator() {
    log "Checking emulator connection..."
    if ! "$ADB" devices | grep -q "emulator"; then
        error "No emulator detected. Please start the emulator first."
        exit 1
    fi
    success "Emulator detected"
}

# Main execution
main() {
    log "Starting droidrun[google] build process..."
    log "This script will build all dependencies in the correct order"
    log "See docs/droidrun_dep_install_seq.md for detailed sequence"
    echo ""
    
    check_emulator
    
    log "Using the main installation script: install-droidrun-dependencies.sh"
    log "This script handles all dependencies automatically"
    echo ""
    
    # Execute the main installation script via ADB
    "$ADB" shell "run-as com.termux sh -c 'export PREFIX=/data/data/com.termux/files/usr && export HOME=/data/data/com.termux/files/home && export PATH=\$PREFIX/bin:\$PATH && cd \$HOME && if [ -f scripts/build/install-droidrun-dependencies.sh ]; then bash scripts/build/install-droidrun-dependencies.sh; else echo \"Script not found in Termux. Please copy it first.\"; fi'"
}

# Run main function
main "$@"

