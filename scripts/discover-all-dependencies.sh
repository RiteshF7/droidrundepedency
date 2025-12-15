#!/usr/bin/env bash
# discover-all-dependencies.sh
# Discovers ALL transitive dependencies for droidrun[google] and checks wheel availability
# Generates a comprehensive dependency manifest JSON file

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
UTILS_DIR="$SCRIPT_DIR/utils"
DEPS_DIR="$PROJECT_ROOT/droidrunBuild/depedencies"
TARGET_PACKAGE="${1:-droidrun[google]}"
PYTHON_VERSION="${2:-3.12}"
ARCHITECTURES=("aarch64" "x86_64")

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
            echo -e "${RED}[ERROR]${NC} $message" >&2
            ;;
        "WARNING")
            echo -e "${YELLOW}[WARNING]${NC} $message"
            ;;
    esac
}

# Create directories
mkdir -p "$DEPS_DIR"
mkdir -p "$DEPS_DIR/tmp"

# Temporary download directory
TMP_DOWNLOAD_DIR="$DEPS_DIR/tmp/downloads"
mkdir -p "$TMP_DOWNLOAD_DIR"

# Output manifest file
MANIFEST_FILE="$DEPS_DIR/dependency-manifest.json"

log "INFO" "Discovering dependencies for: $TARGET_PACKAGE"
log "INFO" "Python version: $PYTHON_VERSION"
log "INFO" "Architectures: ${ARCHITECTURES[*]}"

# Step 1: Get all dependencies using pip
log "INFO" "Step 1: Downloading package metadata to discover dependencies..."

# Use pip show to get direct dependencies first
log "INFO" "Getting dependency tree from pip..."

# Download the package and all dependencies (without installing)
pip download "$TARGET_PACKAGE" --dest "$TMP_DOWNLOAD_DIR" --no-cache-dir 2>&1 | grep -v "WARNING" || true

# Step 2: Parse all downloaded packages to get transitive dependencies
log "INFO" "Step 2: Parsing dependencies from downloaded packages..."

# Use pip show or pipdeptree if available, otherwise parse METADATA files
PACKAGES=()

# Get list of all downloaded packages
for file in "$TMP_DOWNLOAD_DIR"/*.{tar.gz,zip,whl} 2>/dev/null; do
    [ -f "$file" ] || continue
    filename=$(basename "$file")
    
    # Extract package name from filename
    # Format: package-name-version.tar.gz or package-name-version.whl
    if [[ "$filename" =~ ^([a-zA-Z0-9_-]+)-([0-9.]+[a-zA-Z0-9._-]*)\.(tar\.gz|zip|whl)$ ]]; then
        pkg_name="${BASH_REMATCH[1]}"
        pkg_version="${BASH_REMATCH[2]}"
        PACKAGES+=("$pkg_name==$pkg_version")
    fi
done

log "INFO" "Found ${#PACKAGES[@]} packages"

# Step 3: For each package, check wheel availability and get requirements
log "INFO" "Step 3: Checking wheel availability and parsing requirements..."

# Initialize manifest structure
MANIFEST=$(cat <<EOF
{
  "target": "$TARGET_PACKAGE",
  "python_version": "$PYTHON_VERSION",
  "architectures": ${ARCHITECTURES[@]@Q},
  "generated_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "packages": [],
  "system_packages": []
}
EOF
)

# Use Python script for discovery
python3 "$SCRIPT_DIR/utils/discover-dependencies.py" \
    --target "$TARGET_PACKAGE" \
    --python-version "$PYTHON_VERSION" \
    --download-dir "$TMP_DOWNLOAD_DIR" \
    --output "$MANIFEST_FILE" \
    --utils-dir "$UTILS_DIR"

log "SUCCESS" "Dependency discovery complete!"
log "INFO" "Manifest saved to: $MANIFEST_FILE"
log "INFO" "Total packages discovered: $(python3 -c "import json; data=json.load(open('$MANIFEST_FILE')); print(len(data['packages']))")"

# Cleanup
log "INFO" "Cleaning up temporary files..."
rm -rf "$TMP_DOWNLOAD_DIR"

log "SUCCESS" "Done! Review the manifest at: $MANIFEST_FILE"

