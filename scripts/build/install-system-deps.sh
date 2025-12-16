#!/data/data/com.termux/files/usr/bin/bash
# install-system-deps.sh
# Installs system dependencies using pkg in correct sequence

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"
source "$SCRIPT_DIR/common.sh"

# Track installed packages
declare -A INSTALLED_PKGS

# Install a system package and its prerequisites
install_pkg_with_deps() {
    local pkg_name="$1"
    
    # Skip if already installed
    if [ -n "${INSTALLED_PKGS[$pkg_name]:-}" ]; then
        return 0
    fi
    
    # Get prerequisites from SYSTEM_DEPS array
    local prereqs="${SYSTEM_DEPS[$pkg_name]:-}"
    
    # Install prerequisites first
    if [ -n "$prereqs" ]; then
        IFS=',' read -ra PREREQ_ARRAY <<< "$prereqs"
        for prereq in "${PREREQ_ARRAY[@]}"; do
            prereq=$(echo "$prereq" | xargs)  # trim whitespace
            if [ -n "$prereq" ] && [ -z "${INSTALLED_PKGS[$prereq]:-}" ]; then
                install_pkg_with_deps "$prereq"
            fi
        done
    fi
    
    # Check if package is already installed
    if pkg list-installed 2>/dev/null | grep -q "^$pkg_name "; then
        log "INFO" "System package $pkg_name already installed"
        INSTALLED_PKGS[$pkg_name]=1
        return 0
    fi
    
    # Install the package
    log "INFO" "Installing system package: $pkg_name"
    if pkg install -y "$pkg_name" >> "$BUILD_LOG" 2>&1; then
        log "SUCCESS" "Installed $pkg_name"
        INSTALLED_PKGS[$pkg_name]=1
        return 0
    else
        log "WARNING" "Failed to install $pkg_name, continuing..."
        return 1
    fi
}

# Main function to install all system dependencies
install_all_system_deps() {
    log "INFO" "=========================================="
    log "INFO" "Installing system dependencies"
    log "INFO" "=========================================="
    
    # Update and upgrade packages first
    log "INFO" "Updating package repository..."
    pkg update -y >> "$BUILD_LOG" 2>&1 || {
        log "WARNING" "pkg update failed, continuing..."
    }
    
    log "INFO" "Upgrading packages..."
    pkg upgrade -y >> "$BUILD_LOG" 2>&1 || {
        log "WARNING" "pkg upgrade failed, continuing..."
    }
    
    # Install python and pip first
    log "INFO" "Installing Python and pip..."
    install_pkg_with_deps "python"
    install_pkg_with_deps "python-pip"
    
    # Install all other system dependencies
    for pkg_name in "${!SYSTEM_DEPS[@]}"; do
        # Skip python and python-pip (already installed)
        if [ "$pkg_name" = "python" ] || [ "$pkg_name" = "python-pip" ]; then
            continue
        fi
        install_pkg_with_deps "$pkg_name"
    done
    
    log "SUCCESS" "System dependencies installation complete"
}

# Run if executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    install_all_system_deps
fi

