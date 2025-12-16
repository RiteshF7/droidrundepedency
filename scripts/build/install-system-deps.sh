#!/data/data/com.termux/files/usr/bin/bash
# install-system-deps.sh
# Installs system dependencies using pkg in correct sequence

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"
source "$SCRIPT_DIR/common.sh"
source "$SCRIPT_DIR/build-wheels.sh"

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

# Download source archive from GitHub release
download_source_archive() {
    log "INFO" "=========================================="
    log "INFO" "Downloading source archive from GitHub release"
    log "INFO" "Repository: $GITHUB_REPO"
    log "INFO" "Release: $GITHUB_RELEASE_TAG"
    log "INFO" "Archive: $SOURCE_ARCHIVE_NAME"
    log "INFO" "=========================================="
    
    # Create sources directory if it doesn't exist
    mkdir -p "$SOURCES_DIR"
    
    # Check if sources directory already has files (unless force download)
    if [ "${FORCE_DOWNLOAD:-0}" != "1" ]; then
        local existing_files=$(find "$SOURCES_DIR" -maxdepth 1 -type f \( -name "*.tar.gz" -o -name "*.zip" \) 2>/dev/null | wc -l)
        if [ "$existing_files" -gt 0 ]; then
            log "INFO" "Source directory already contains $existing_files files"
            log "INFO" "Skipping download. Use --force-download to re-download."
            return 0
        fi
    else
        log "INFO" "Force download enabled, will re-download sources"
    fi
    
    # Determine release tag
    local release_tag="$GITHUB_RELEASE_TAG"
    if [ "$release_tag" = "latest" ]; then
        log "INFO" "Fetching latest release tag..."
        if command -v curl >/dev/null 2>&1; then
            release_tag=$(curl -s "https://api.github.com/repos/$GITHUB_REPO/releases/latest" | grep '"tag_name"' | head -1 | sed 's/.*"tag_name": "\([^"]*\)".*/\1/')
        elif command -v wget >/dev/null 2>&1; then
            release_tag=$(wget -q -O - "https://api.github.com/repos/$GITHUB_REPO/releases/latest" | grep '"tag_name"' | head -1 | sed 's/.*"tag_name": "\([^"]*\)".*/\1/')
        else
            log "ERROR" "Neither curl nor wget is available to fetch release tag"
            return 1
        fi
        if [ -z "$release_tag" ]; then
            log "ERROR" "Failed to get latest release tag"
            return 1
        fi
        log "INFO" "Latest release tag: $release_tag"
    fi
    
    # Construct download URL
    local download_url="https://github.com/$GITHUB_REPO/releases/download/$release_tag/$SOURCE_ARCHIVE_NAME"
    local temp_archive="$SOURCES_DIR/$SOURCE_ARCHIVE_NAME"
    
    log "INFO" "Downloading from: $download_url"
    log "INFO" "Saving to: $temp_archive"
    
    # Download the archive
    if command -v wget >/dev/null 2>&1; then
        if ! wget -q --show-progress -O "$temp_archive" "$download_url" 2>&1 | tee -a "$BUILD_LOG"; then
            log "ERROR" "Failed to download source archive with wget"
            rm -f "$temp_archive"
            return 1
        fi
    elif command -v curl >/dev/null 2>&1; then
        if ! curl -L -o "$temp_archive" "$download_url" 2>&1 | tee -a "$BUILD_LOG"; then
            log "ERROR" "Failed to download source archive with curl"
            rm -f "$temp_archive"
            return 1
        fi
    else
        log "ERROR" "Neither wget nor curl is available. Please install one of them."
        return 1
    fi
    
    # Verify download
    if [ ! -f "$temp_archive" ] || [ ! -s "$temp_archive" ]; then
        log "ERROR" "Downloaded file is empty or missing"
        rm -f "$temp_archive"
        return 1
    fi
    
    log "SUCCESS" "Downloaded archive: $(du -h "$temp_archive" | cut -f1)"
    
    # Extract archive
    log "INFO" "Extracting archive to $SOURCES_DIR..."
    cd "$SOURCES_DIR"
    
    if [[ "$SOURCE_ARCHIVE_NAME" == *.tar.gz ]]; then
        if ! tar -xzf "$temp_archive" 2>&1 | tee -a "$BUILD_LOG"; then
            log "ERROR" "Failed to extract tar.gz archive"
            rm -f "$temp_archive"
            return 1
        fi
    elif [[ "$SOURCE_ARCHIVE_NAME" == *.7z ]] || [[ "$SOURCE_ARCHIVE_NAME" == *.7Z ]]; then
        if command -v 7z >/dev/null 2>&1; then
            if ! 7z x "$temp_archive" -o"$SOURCES_DIR" -y 2>&1 | tee -a "$BUILD_LOG"; then
                log "ERROR" "Failed to extract 7z archive"
                rm -f "$temp_archive"
                return 1
            fi
        else
            log "ERROR" "7z is not available. Please install p7zip: pkg install -y p7zip"
            rm -f "$temp_archive"
            return 1
        fi
    elif [[ "$SOURCE_ARCHIVE_NAME" == *.zip ]]; then
        if ! unzip -q "$temp_archive" -d "$SOURCES_DIR" 2>&1 | tee -a "$BUILD_LOG"; then
            log "ERROR" "Failed to extract zip archive"
            rm -f "$temp_archive"
            return 1
        fi
    else
        log "ERROR" "Unsupported archive format: $SOURCE_ARCHIVE_NAME"
        rm -f "$temp_archive"
        return 1
    fi
    
    # Clean up archive file
    rm -f "$temp_archive"
    
    # Count extracted files
    local extracted_count=$(find "$SOURCES_DIR" -maxdepth 1 -type f \( -name "*.tar.gz" -o -name "*.zip" \) 2>/dev/null | wc -l)
    
    log "SUCCESS" "=========================================="
    log "SUCCESS" "Source archive extracted successfully!"
    log "INFO" "Extracted $extracted_count source files to $SOURCES_DIR"
    log "SUCCESS" "=========================================="
    
    return 0
}

# Download all source files for Python packages (fallback method)
download_all_sources_individual() {
    log "INFO" "=========================================="
    log "INFO" "Downloading source files individually (fallback)"
    log "INFO" "Sources directory: $SOURCES_DIR"
    log "INFO" "=========================================="
    
    # Create sources directory if it doesn't exist
    mkdir -p "$SOURCES_DIR"
    
    # Setup build environment (needed for pip)
    setup_build_environment
    
    local downloaded_count=0
    local skipped_count=0
    local failed_count=0
    
    # Download sources for all Python packages
    for pkg_name in "${!PYTHON_PACKAGES[@]}"; do
        local constraint="${PYTHON_PACKAGES[$pkg_name]}"
        local version=""
        
        # Extract version from constraint if it's ==
        if [[ "$constraint" == ==* ]]; then
            version="${constraint#==}"
        fi
        
        # Check if source file already exists
        local source_file=$(find_source_file "$pkg_name" "$version")
        if [ -n "$source_file" ]; then
            log "INFO" "Source file already exists for $pkg_name: $(basename "$source_file")"
            skipped_count=$((skipped_count + 1))
            continue
        fi
        
        # Download source file
        log "INFO" "Downloading source for $pkg_name${version:+ $version}..."
        if download_source_file "$pkg_name" "$version" "$constraint"; then
            downloaded_count=$((downloaded_count + 1))
        else
            log "WARNING" "Failed to download source for $pkg_name"
            failed_count=$((failed_count + 1))
        fi
    done
    
    log "SUCCESS" "=========================================="
    log "SUCCESS" "Source download complete!"
    log "INFO" "Downloaded: $downloaded_count"
    log "INFO" "Skipped (already exists): $skipped_count"
    log "INFO" "Failed: $failed_count"
    log "SUCCESS" "=========================================="
}

# Main download function - tries archive first, falls back to individual
download_all_sources() {
    # Try downloading archive first
    if download_source_archive; then
        log "SUCCESS" "Sources downloaded from release archive"
        return 0
    else
        log "WARNING" "Failed to download source archive, falling back to individual downloads"
        download_all_sources_individual
    fi
}

# Main function that installs system deps and downloads sources
install_all_and_download_sources() {
    # Step 1: Install system dependencies
    install_all_system_deps
    
    # Step 2: Download all source files
    download_all_sources
}

# Run if executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    # Check if --no-download flag is provided to skip source download
    if [ "$1" = "--no-download" ] || [ "$1" = "-n" ]; then
        install_all_system_deps
    elif [ "$1" = "--force-download" ] || [ "$1" = "-f" ]; then
        # Force re-download even if sources exist
        install_all_system_deps
        export FORCE_DOWNLOAD=1
        download_source_archive
    elif [ "$1" = "--individual" ] || [ "$1" = "-i" ]; then
        # Use individual downloads instead of archive
        install_all_system_deps
        download_all_sources_individual
    else
        # By default, install system deps and download sources from archive
        install_all_and_download_sources
    fi
fi

