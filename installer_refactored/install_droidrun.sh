#!/usr/bin/env bash
# Main droidrun Installation Script
# Orchestrates all installation phases

set -euo pipefail

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# Initialize logging
init_logging

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}droidrun Installation Script${NC}"
echo -e "${BLUE}========================================${NC}"
echo

# Check Termux environment
if [ ! -d "$PREFIX" ]; then
    log_error "Termux PREFIX directory not found: $PREFIX"
    log_error "This script must be run in Termux environment"
    exit 1
fi

log_info "PREFIX: $PREFIX"

# Load progress and environment at start
if [ -f "$PROGRESS_FILE" ]; then
    log_info "Found existing progress file: $PROGRESS_FILE"
    completed_phases=()
    for phase in 1 2 3 4 5 6 7; do
        if is_phase_complete "$phase"; then
            completed_phases+=("$phase")
        fi
    done
    if [ ${#completed_phases[@]} -gt 0 ]; then
        log_info "Completed phases: ${completed_phases[*]}"
        log_info "Script will resume from last completed phase"
    else
        log_info "No completed phases found, starting from beginning"
    fi
    load_env_vars
fi

echo

# ============================================
# Check and install system dependencies
# ============================================
log_info "Checking system dependencies..."

REQUIRED_PKGS=(
    "python" "python-pip"
    "autoconf" "automake" "libtool" "make" "binutils"
    "clang" "cmake" "ninja"
    "rust"
    "flang" "blas-openblas"
    "libjpeg-turbo" "libpng" "libtiff" "libwebp" "freetype"
    "libarrow-cpp"
    "openssl" "libc++" "zlib"
    "protobuf" "libprotobuf"
    "abseil-cpp" "c-ares" "libre2"
    "patchelf"
)

MISSING_PKGS=()
for pkg in "${REQUIRED_PKGS[@]}"; do
    if ! pkg_installed "$pkg"; then
        MISSING_PKGS+=("$pkg")
    fi
done

if [ ${#MISSING_PKGS[@]} -gt 0 ]; then
    log_warning "Missing system packages: ${MISSING_PKGS[*]}"
    log_info "Installing missing packages..."
    pkg update -y
    pkg install -y "${MISSING_PKGS[@]}"
    log_success "System packages installed"
else
    log_success "All system dependencies are installed"
fi

# ============================================
# Setup build environment
# ============================================
setup_build_environment

# ============================================
# Create gfortran symlink for scipy compatibility
# ============================================
if [ ! -f "$PREFIX/bin/gfortran" ]; then
    log_info "Creating gfortran symlink (required for scipy/scikit-learn)..."
    ln -sf "$PREFIX/bin/flang" "$PREFIX/bin/gfortran"
    log_success "gfortran symlink created"
fi

# ============================================
# Check Python and pip
# ============================================
if ! command_exists python3; then
    log_error "python3 is not installed"
    exit 1
fi

if ! command_exists pip; then
    log_error "pip is not installed"
    exit 1
fi

PYTHON_VERSION=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>/dev/null || echo "unknown")
log_success "Python $PYTHON_VERSION found"

echo

# ============================================
# Run installation phases
# ============================================
PHASES=(
    "phase1_build_tools.sh:Phase 1: Build Tools"
    "phase2_numpy.sh:Phase 2: NumPy"
    "phase3_scientific.sh:Phase 3: Scientific Stack"
    "phase4_jiter.sh:Phase 4: Jiter"
    "phase5_compiled.sh:Phase 5: Compiled Packages"
    "phase6_optional.sh:Phase 6: Optional Packages"
    "phase7_providers.sh:Phase 7: Droidrun and Providers"
)

FAILED_PHASES=()
SUCCESSFUL_PHASES=()

for phase_entry in "${PHASES[@]}"; do
    phase_script="${phase_entry%%:*}"
    phase_name="${phase_entry##*:}"
    phase_num=$(echo "$phase_script" | grep -oE '[0-9]+')
    
    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_info "Starting $phase_name"
    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Check if phase is already complete
    if is_phase_complete "$phase_num"; then
        log_success "$phase_name already completed (skipping)"
        SUCCESSFUL_PHASES+=("$phase_name")
        echo
        continue
    fi
    
    # Run phase script
    phase_script_path="$SCRIPT_DIR/$phase_script"
    if [ ! -f "$phase_script_path" ]; then
        log_error "Phase script not found: $phase_script_path"
        FAILED_PHASES+=("$phase_name (script not found)")
        continue
    fi
    
    # Make script executable
    chmod +x "$phase_script_path" 2>/dev/null || true
    
    # Run the phase script
    if bash "$phase_script_path"; then
        log_success "$phase_name completed successfully"
        SUCCESSFUL_PHASES+=("$phase_name")
    else
        exit_code=$?
        log_error "$phase_name failed with exit code: $exit_code"
        FAILED_PHASES+=("$phase_name")
        
        # Ask user if they want to continue
        log_warning "Phase failed. Do you want to continue with remaining phases? (y/n)"
        read -r response || response="n"
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            log_error "Installation aborted by user"
            exit 1
        fi
    fi
    
    echo
done

# ============================================
# Final Summary
# ============================================
echo
echo -e "${BLUE}========================================${NC}"
log_success "Installation process completed!"
echo -e "${BLUE}========================================${NC}"
echo

if [ ${#SUCCESSFUL_PHASES[@]} -gt 0 ]; then
    log_success "Successfully completed phases:"
    for phase in "${SUCCESSFUL_PHASES[@]}"; do
        echo "  ✓ $phase"
    done
    echo
fi

if [ ${#FAILED_PHASES[@]} -gt 0 ]; then
    log_warning "Failed phases:"
    for phase in "${FAILED_PHASES[@]}"; do
        echo "  ✗ $phase"
    done
    echo
    log_warning "Some phases failed. Check the error log for details: $ERROR_LOG_FILE"
    echo
fi

echo "droidrun installation process has completed."
echo
echo "Important notes:"
echo "  - LD_LIBRARY_PATH has been configured for grpcio"
echo "  - Restart your terminal or run: source ~/.bashrc"
echo "  - Wheels are available in: $WHEELS_DIR"
echo
echo "Log files (for troubleshooting):"
echo "  - Full installation log: $LOG_FILE"
echo "  - Error log: $ERROR_LOG_FILE"
echo "  - Progress file: $PROGRESS_FILE"
echo "  - Environment file: $ENV_FILE"
echo
if [ -f "$ERROR_LOG_FILE" ] && [ -s "$ERROR_LOG_FILE" ]; then
    error_count=$(grep -c "===" "$ERROR_LOG_FILE" 2>/dev/null || echo "0")
    if [ "$error_count" -gt 0 ]; then
        log_warning "Some packages failed to build (this may be expected)"
        log_info "Check $ERROR_LOG_FILE for detailed error information"
        log_info "Common issue: tokenizers requires pre-built wheel on Android"
    fi
fi
echo
echo "To verify installation:"
echo "  python3 -c 'import droidrun; print(\"droidrun installed successfully\")'"
echo
echo "To view logs:"
echo "  cat $LOG_FILE"
echo "  cat $ERROR_LOG_FILE"
echo
echo "To rerun a specific phase:"
echo "  bash $SCRIPT_DIR/phase<N>_<name>.sh"
echo

if [ ${#FAILED_PHASES[@]} -eq 0 ]; then
    exit 0
else
    exit 1
fi

