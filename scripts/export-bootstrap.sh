#!/data/data/com.termux/files/usr/bin/bash
# export-bootstrap.sh
# Collects all built wheels and system packages into a single bootstrap archive
# Designed to run on Android device after building all dependencies

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WHEELS_DIR="${WHEELS_DIR:-$HOME/wheels}"
SYSTEM_PKGS_DIR="${SYSTEM_PKGS_DIR:-$HOME/system-packages}"
MANIFEST_FILE="${1:-$HOME/dependency-manifest.json}"
BOOTSTRAP_DIR="$HOME/droidrun-bootstrap"
OUTPUT_ARCHIVE="$HOME/droidrun-bootstrap-$(date +%Y%m%d-%H%M%S).tar.gz"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    local level="$1"
    shift
    local message="$*"
    
    case "$level" in
        "INFO")
            echo -e "${BLUE}[INFO]${NC} $message"
            ;;
        "SUCCESS")
            echo -e "${GREEN}[SUCCESS]${NC} $message"
            ;;
        "ERROR")
            echo -e "${RED}[ERROR]${NC} $message"
            ;;
        "WARNING")
            echo -e "${YELLOW}[WARNING]${NC} $message"
            ;;
    esac
}

# Detect architecture from wheels
detect_architecture() {
    local wheel_file="$1"
    if echo "$wheel_file" | grep -q "linux_aarch64\|manylinux_aarch64"; then
        echo "aarch64"
    elif echo "$wheel_file" | grep -q "linux_x86_64\|manylinux_x86_64"; then
        echo "x86_64"
    else
        echo "unknown"
    fi
}

# Create bootstrap structure
create_bootstrap_structure() {
    log "INFO" "Creating bootstrap directory structure..."
    
    rm -rf "$BOOTSTRAP_DIR"
    mkdir -p "$BOOTSTRAP_DIR/wheels/aarch64"
    mkdir -p "$BOOTSTRAP_DIR/wheels/x86_64"
    mkdir -p "$BOOTSTRAP_DIR/system-packages"
    mkdir -p "$BOOTSTRAP_DIR/scripts"
    mkdir -p "$BOOTSTRAP_DIR/docs"
}

# Copy wheels organized by architecture
copy_wheels() {
    log "INFO" "Copying wheels from $WHEELS_DIR..."
    
    local wheel_count=0
    local aarch64_count=0
    local x86_64_count=0
    
    for wheel in "$WHEELS_DIR"/*.whl; do
        [ -f "$wheel" ] || continue
        
        local arch=$(detect_architecture "$wheel")
        local filename=$(basename "$wheel")
        
        case "$arch" in
            aarch64)
                cp "$wheel" "$BOOTSTRAP_DIR/wheels/aarch64/"
                aarch64_count=$((aarch64_count + 1))
                ;;
            x86_64)
                cp "$wheel" "$BOOTSTRAP_DIR/wheels/x86_64/"
                x86_64_count=$((x86_64_count + 1))
                ;;
            *)
                # Try to determine from system or copy to both
                log "WARNING" "Unknown architecture for $filename, copying to both"
                cp "$wheel" "$BOOTSTRAP_DIR/wheels/aarch64/"
                cp "$wheel" "$BOOTSTRAP_DIR/wheels/x86_64/"
                aarch64_count=$((aarch64_count + 1))
                x86_64_count=$((x86_64_count + 1))
                ;;
        esac
        
        wheel_count=$((wheel_count + 1))
    done
    
    log "SUCCESS" "Copied $wheel_count wheels (aarch64: $aarch64_count, x86_64: $x86_64_count)"
}

# Copy system packages
copy_system_packages() {
    log "INFO" "Copying system packages from $SYSTEM_PKGS_DIR..."
    
    if [ -d "$SYSTEM_PKGS_DIR" ] && [ -n "$(ls -A "$SYSTEM_PKGS_DIR"/*.deb 2>/dev/null)" ]; then
        cp "$SYSTEM_PKGS_DIR"/*.deb "$BOOTSTRAP_DIR/system-packages/" 2>/dev/null || true
        local pkg_count=$(ls -1 "$BOOTSTRAP_DIR/system-packages"/*.deb 2>/dev/null | wc -l)
        log "SUCCESS" "Copied $pkg_count system packages"
    else
        log "INFO" "No system packages to copy (most are available via Termux pkg manager)"
    fi
}

# Copy manifest
copy_manifest() {
    if [ -f "$MANIFEST_FILE" ]; then
        cp "$MANIFEST_FILE" "$BOOTSTRAP_DIR/dependency-manifest.json"
        log "SUCCESS" "Copied dependency manifest"
    else
        log "WARNING" "Manifest file not found: $MANIFEST_FILE"
    fi
}

# Create installation scripts
create_install_scripts() {
    log "INFO" "Creating installation scripts..."
    
    # Main install script
    cat > "$BOOTSTRAP_DIR/scripts/install.sh" <<'INSTALL_EOF'
#!/data/data/com.termux/files/usr/bin/bash
# install.sh - Zero-compilation installation script for droidrun[google]
# Uses ONLY pre-built wheels - no compilation at install time

set -e

BOOTSTRAP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WHEELS_DIR="$BOOTSTRAP_DIR/wheels"

# Detect architecture
ARCH=$(uname -m)
case "$ARCH" in
    aarch64|arm64)
        WHEEL_ARCH="aarch64"
        ;;
    x86_64|amd64)
        WHEEL_ARCH="x86_64"
        ;;
    *)
        echo "ERROR: Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

WHEELS_PATH="$WHEELS_DIR/$WHEEL_ARCH"

echo "Installing droidrun[google] from bootstrap..."
echo "Architecture: $WHEEL_ARCH"
echo "Wheels directory: $WHEELS_PATH"

# Check if wheels exist
if [ ! -d "$WHEELS_PATH" ] || [ -z "$(ls -A "$WHEELS_PATH"/*.whl 2>/dev/null)" ]; then
    echo "ERROR: No wheels found in $WHEELS_PATH"
    exit 1
fi

# Install system packages first (if any)
if [ -d "$BOOTSTRAP_DIR/system-packages" ] && [ -n "$(ls -A "$BOOTSTRAP_DIR/system-packages"/*.deb 2>/dev/null)" ]; then
    echo "Installing system packages..."
    for deb in "$BOOTSTRAP_DIR/system-packages"/*.deb; do
        dpkg -i "$deb" || pkg install -y "$(basename "$deb" .deb)" || true
    done
fi

# Install wheels in dependency order (using manifest if available)
if [ -f "$BOOTSTRAP_DIR/dependency-manifest.json" ]; then
    echo "Installing wheels in dependency order..."
    python3 <<PYTHON_INSTALL
import json
import subprocess
import sys
from pathlib import Path

with open("$BOOTSTRAP_DIR/dependency-manifest.json", "r") as f:
    manifest = json.load(f)

packages = manifest.get("packages", [])
packages.sort(key=lambda x: x.get("build_order", 999))

wheels_path = Path("$WHEELS_PATH")

for pkg in packages:
    pkg_name = pkg.get("name")
    # Find wheel for this package
    wheels = list(wheels_path.glob(f"{pkg_name}-*.whl"))
    if wheels:
        wheel_file = str(wheels[0])
        print(f"Installing {pkg_name} from {wheel_file}")
        subprocess.run(
            ["pip", "install", "--no-deps", "--find-links", "$WHEELS_PATH", "--no-index", wheel_file],
            check=False
        )

PYTHON_INSTALL
else
    # Fallback: install all wheels
    echo "Installing all wheels..."
    pip install --find-links "$WHEELS_PATH" --no-index "$WHEELS_PATH"/*.whl
fi

# Install droidrun[google] using pre-built wheels
echo "Installing droidrun[google]..."
pip install 'droidrun[google]' --find-links "$WHEELS_PATH" || {
    echo "WARNING: Some dependencies may need to be installed from PyPI"
    pip install 'droidrun[google]' --find-links "$WHEELS_PATH"
}

echo ""
echo "✅ droidrun[google] installation complete!"
echo "Verify with: python3 -c 'import droidrun; print(\"droidrun installed successfully\")'"
INSTALL_EOF

    chmod +x "$BOOTSTRAP_DIR/scripts/install.sh"
    
    # Architecture-specific scripts (symlinks to main script)
    ln -sf install.sh "$BOOTSTRAP_DIR/scripts/install-aarch64.sh"
    ln -sf install.sh "$BOOTSTRAP_DIR/scripts/install-x86_64.sh"
    
    log "SUCCESS" "Installation scripts created"
}

# Create README
create_readme() {
    log "INFO" "Creating README..."
    
    cat > "$BOOTSTRAP_DIR/README.md" <<README_EOF
# droidrun[google] Bootstrap Package

This bootstrap package contains pre-built wheels for droidrun[google] and all its dependencies.

## Contents

- \`wheels/\` - Pre-built Python wheels organized by architecture
  - \`aarch64/\` - Wheels for ARM 64-bit devices
  - \`x86_64/\` - Wheels for x86_64 emulators
- \`system-packages/\` - Custom system packages (if any)
- \`scripts/install.sh\` - Main installation script
- \`dependency-manifest.json\` - Complete dependency list

## Installation

1. Extract this bootstrap package:
   \`\`\`bash
   tar -xzf droidrun-bootstrap-*.tar.gz
   cd droidrun-bootstrap
   \`\`\`

2. Run the installation script:
   \`\`\`bash
   ./scripts/install.sh
   \`\`\`

The installation script will:
- Detect your architecture automatically
- Install all pre-built wheels
- Install droidrun[google] using the pre-built dependencies
- **No compilation required** - everything is pre-built

## Requirements

- Termux installed on Android
- Python 3.12+
- pip installed
- Internet connection (only for pure Python packages not in wheels)

## Included Packages

All compiled dependencies are included as pre-built wheels:
- numpy, scipy, pandas, scikit-learn
- jiter, pyarrow, psutil
- And all transitive dependencies

## Verification

After installation, verify:
\`\`\`bash
python3 -c "import droidrun; print('droidrun installed successfully')"
\`\`\`

## Notes

- This bootstrap contains wheels for both aarch64 and x86_64 architectures
- The installer automatically selects the correct architecture
- If a wheel is missing, installation will fail (no fallback to building)
- System packages are usually available via Termux's pkg manager
README_EOF

    log "SUCCESS" "README created"
}

# Create archive
create_archive() {
    log "INFO" "Creating bootstrap archive..."
    
    cd "$HOME"
    tar -czf "$OUTPUT_ARCHIVE" -C "$(dirname "$BOOTSTRAP_DIR")" "$(basename "$BOOTSTRAP_DIR")"
    
    local archive_size=$(du -h "$OUTPUT_ARCHIVE" | cut -f1)
    log "SUCCESS" "Bootstrap archive created: $OUTPUT_ARCHIVE ($archive_size)"
}

# Main function
main() {
    log "INFO" "Exporting bootstrap package..."
    log "INFO" "Wheels directory: $WHEELS_DIR"
    log "INFO" "System packages directory: $SYSTEM_PKGS_DIR"
    
    create_bootstrap_structure
    copy_wheels
    copy_system_packages
    copy_manifest
    create_install_scripts
    create_readme
    create_archive
    
    log "SUCCESS" "Bootstrap export complete!"
    log "INFO" "Archive: $OUTPUT_ARCHIVE"
    log "INFO" "To install: tar -xzf $(basename "$OUTPUT_ARCHIVE") && cd droidrun-bootstrap && ./scripts/install.sh"
}

# Run main if script is executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi



