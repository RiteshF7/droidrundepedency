#!/data/data/com.termux/files/usr/bin/bash
# build-system-packages.sh
# Builds Termux system packages that don't exist in repository
# Most packages exist in Termux, but this handles edge cases

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST_FILE="${1:-$HOME/dependency-manifest.json}"
SYSTEM_PKGS_DIR="${SYSTEM_PKGS_DIR:-$HOME/system-packages}"
BUILD_LOG="$SYSTEM_PKGS_DIR/build-system.log"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

mkdir -p "$SYSTEM_PKGS_DIR"
touch "$BUILD_LOG"

log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "[$timestamp] [$level] $message" >> "$BUILD_LOG"
    
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

# Check if package exists in Termux repository
package_exists_in_termux() {
    local pkg_name="$1"
    
    # Try to search for package
    if pkg search "$pkg_name" 2>/dev/null | grep -q "^$pkg_name "; then
        return 0
    fi
    
    # Try to show package info
    if pkg show "$pkg_name" &>/dev/null; then
        return 0
    fi
    
    return 1
}

# Get package version from Termux
get_termux_package_version() {
    local pkg_name="$1"
    
    pkg show "$pkg_name" 2>/dev/null | grep "^Version:" | awk '{print $2}' || echo "unknown"
}

# Build a system package (placeholder - most packages exist in Termux)
build_system_package() {
    local pkg_name="$1"
    local required_version="${2:-}"
    
    log "INFO" "Checking system package: $pkg_name"
    
    # Check if package exists in Termux
    if package_exists_in_termux "$pkg_name"; then
        local installed_version=$(get_termux_package_version "$pkg_name")
        log "SUCCESS" "$pkg_name is available in Termux (version: $installed_version)"
        
        # Check version if required
        if [ -n "$required_version" ]; then
            log "INFO" "Required version: $required_version, Available: $installed_version"
            # Version checking would go here if needed
        fi
        
        return 0
    fi
    
    log "WARNING" "$pkg_name not found in Termux repository"
    log "INFO" "Building $pkg_name from source..."
    
    # Most system packages exist in Termux, so building from source is rare
    # This is a placeholder for packages that might need custom builds
    
    case "$pkg_name" in
        libarrow-cpp)
            # libarrow-cpp exists in Termux, but if version mismatch, we'd build here
            log "WARNING" "libarrow-cpp building not implemented - use Termux package"
            return 1
            ;;
        *)
            log "ERROR" "Building $pkg_name from source not implemented"
            log "INFO" "Most packages are available via: pkg install $pkg_name"
            return 1
            ;;
    esac
}

# Main function
main() {
    log "INFO" "Checking system package requirements..."
    log "INFO" "Manifest: $MANIFEST_FILE"
    
    if [ ! -f "$MANIFEST_FILE" ]; then
        log "ERROR" "Manifest file not found: $MANIFEST_FILE"
        exit 1
    fi
    
    # Extract system packages from manifest
    python3 <<PYTHON_CHECK
import json
import subprocess
import sys

with open("$MANIFEST_FILE", "r") as f:
    manifest = json.load(f)

system_packages = manifest.get("system_packages", [])

print(f"Checking {len(system_packages)} system packages...", file=sys.stderr)

for pkg in system_packages:
    pkg_name = pkg.get("name")
    pkg_version = pkg.get("version", "latest")
    needs_build = pkg.get("needs_build", False)
    available = pkg.get("available_in_termux", True)
    
    if needs_build and not available:
        print(f"{pkg_name}|{pkg_version}")
    else:
        print(f"SKIP:{pkg_name}|{pkg_version}", file=sys.stderr)

PYTHON_CHECK | while IFS='|' read -r pkg_name pkg_version; do
    [ -z "$pkg_name" ] && continue
    [ "${pkg_name:0:5}" = "SKIP:" ] && continue
    
    build_system_package "$pkg_name" "$pkg_version" || {
        log "WARNING" "Could not build $pkg_name, may need manual installation"
    }
done
    
    log "SUCCESS" "System package check complete!"
    log "INFO" "Most packages can be installed via: pkg install <package-name>"
}

# Run main if script is executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi



