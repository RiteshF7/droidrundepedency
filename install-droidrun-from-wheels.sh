#!/bin/bash
# Standalone script to install droidrun from pre-built wheels
# This script can be used to test droidrun installation separately
# Usage: ./install-droidrun-from-wheels.sh [wheels_url] [wheels_dir]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log() { echo -e "${GREEN}[*]${NC} $@"; }
log_error() { echo -e "${RED}[!]${NC} $@" 1>&2; }
log_warn() { echo -e "${YELLOW}[!]${NC} $@"; }

# Default values
WHEELS_URL="${1:-}"
WHEELS_DIR="${2:-${HOME}/droidrun-wheels}"
PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"

# Function to download wheels from URL
download_wheels() {
	local url="$1"
	local dest_dir="$2"

	if [ -z "$url" ]; then
		log_warn "No URL provided, skipping download. Using existing wheels in $dest_dir"
		return 0
	fi

	log "Downloading wheels from: $url"
	
	# Create destination directory
	mkdir -p "$dest_dir" || {
		log_error "Failed to create directory: $dest_dir"
		return 1
	}

	# Download wheels (assuming it's a zip file or tar archive)
	local temp_file="${dest_dir}/wheels_temp.zip"
	
	if command -v curl &> /dev/null; then
		curl -L -o "$temp_file" "$url" || {
			log_error "Failed to download wheels from $url"
			return 1
		}
	elif command -v wget &> /dev/null; then
		wget -O "$temp_file" "$url" || {
			log_error "Failed to download wheels from $url"
			return 1
		}
	else
		log_error "Neither curl nor wget is available. Cannot download wheels."
		return 1
	fi

	# Extract wheels
	log "Extracting wheels..."
	if [[ "$url" == *.zip ]] || [[ "$url" == *.ZIP ]]; then
		unzip -q -o "$temp_file" -d "$dest_dir" || {
			log_error "Failed to extract zip file"
			return 1
		}
	elif [[ "$url" == *.tar.gz ]] || [[ "$url" == *.tgz ]]; then
		tar -xzf "$temp_file" -C "$dest_dir" || {
			log_error "Failed to extract tar.gz file"
			return 1
		}
	elif [[ "$url" == *.tar ]]; then
		tar -xf "$temp_file" -C "$dest_dir" || {
			log_error "Failed to extract tar file"
			return 1
		}
	else
		log_warn "Unknown file type. Assuming it's a zip file."
		unzip -q -o "$temp_file" -d "$dest_dir" || {
			log_error "Failed to extract file"
			return 1
		}
	fi

	# Remove temp file
	rm -f "$temp_file"

	log "Wheels downloaded and extracted to: $dest_dir"
	return 0
}

# Function to install droidrun from wheels
install_droidrun_from_wheels() {
	local wheels_dir="$1"

	# Check if wheels directory exists
	if [ ! -d "$wheels_dir" ]; then
		log_error "Wheels directory not found: $wheels_dir"
		return 1
	fi

	local wheel_count
	wheel_count=$(ls -1 "$wheels_dir"/*.whl 2>/dev/null | wc -l)
	if [ "$wheel_count" -eq 0 ]; then
		log_error "No wheel files found in $wheels_dir"
		return 1
	fi

	log "Found $wheel_count wheel files in $wheels_dir"

	# Set up environment variables
	export PREFIX
	export CMAKE_PREFIX_PATH="$PREFIX"
	export CMAKE_INCLUDE_PATH="$PREFIX/include"
	export CC="$PREFIX/bin/clang"
	export CXX="$PREFIX/bin/clang++"
	export TMPDIR="$HOME/tmp"
	mkdir -p "$TMPDIR" 2>/dev/null || true
	export LD_LIBRARY_PATH="$PREFIX/lib:$LD_LIBRARY_PATH"
	export NINJAFLAGS="-j2"
	export MAKEFLAGS="-j2"
	export MAX_JOBS=2

	log "Environment variables set:"
	log "  PREFIX=$PREFIX"
	log "  CMAKE_PREFIX_PATH=$CMAKE_PREFIX_PATH"
	log "  LD_LIBRARY_PATH=$LD_LIBRARY_PATH"

	# Ensure pip is available
	if ! command -v pip &> /dev/null; then
		log_error "pip not found, cannot install droidrun"
		log "Please install python-pip: pkg install python-pip"
		return 1
	fi

	log "Using pip: $(which pip)"
	log "Python version: $(python --version 2>&1 || echo 'unknown')"

	# Phase 2: numpy (foundation)
	log "Phase 2: Installing numpy..."
	if pip install --no-index --find-links "$wheels_dir" numpy; then
		log "✓ numpy installed successfully"
	else
		log_error "Failed to install numpy"
		return 1
	fi

	# Phase 3: scipy, pandas, scikit-learn
	log "Phase 3: Installing scipy..."
	if pip install --no-index --find-links "$wheels_dir" scipy; then
		log "✓ scipy installed successfully"
	else
		log_error "Failed to install scipy"
		return 1
	fi

	log "Phase 3: Installing pandas..."
	if pip install --no-index --find-links "$wheels_dir" "pandas<2.3.0"; then
		log "✓ pandas installed successfully"
	else
		log_error "Failed to install pandas"
		return 1
	fi

	log "Phase 3: Installing scikit-learn..."
	if pip install --no-index --find-links "$wheels_dir" scikit-learn; then
		log "✓ scikit-learn installed successfully"
	else
		log_error "Failed to install scikit-learn"
		return 1
	fi

	# Phase 4: jiter
	log "Phase 4: Installing jiter..."
	if pip install --no-index --find-links "$wheels_dir" "jiter==0.12.0"; then
		log "✓ jiter installed successfully"
	else
		log_error "Failed to install jiter"
		return 1
	fi

	# Phase 5: pyarrow, psutil, grpcio, Pillow
	log "Phase 5: Installing pyarrow..."
	if pip install --no-index --find-links "$wheels_dir" pyarrow; then
		log "✓ pyarrow installed successfully"
	else
		log_warn "pyarrow installation failed (optional)"
	fi

	log "Phase 5: Installing psutil..."
	if pip install --no-index --find-links "$wheels_dir" psutil; then
		log "✓ psutil installed successfully"
	else
		log_error "Failed to install psutil"
		return 1
	fi

	log "Phase 5: Installing grpcio..."
	if pip install --no-index --find-links "$wheels_dir" grpcio; then
		log "✓ grpcio installed successfully"
	else
		log_error "Failed to install grpcio"
		return 1
	fi

	log "Phase 5: Installing Pillow..."
	if pip install --no-index --find-links "$wheels_dir" Pillow; then
		log "✓ Pillow installed successfully"
	else
		log_error "Failed to install Pillow"
		return 1
	fi

	# Phase 6: Optional compiled packages
	log "Phase 6: Installing optional compiled packages..."
	
	log "  Installing tokenizers..."
	pip install --no-index --find-links "$wheels_dir" tokenizers || log_warn "tokenizers installation failed (optional)"
	
	log "  Installing safetensors..."
	pip install --no-index --find-links "$wheels_dir" safetensors || log_warn "safetensors installation failed (optional)"
	
	log "  Installing cryptography..."
	pip install --no-index --find-links "$wheels_dir" cryptography || log_warn "cryptography installation failed (optional)"
	
	log "  Installing pydantic-core..."
	pip install --no-index --find-links "$wheels_dir" pydantic-core || log_warn "pydantic-core installation failed (optional)"
	
	log "  Installing orjson..."
	pip install --no-index --find-links "$wheels_dir" orjson || log_warn "orjson installation failed (optional)"

	# Phase 7: droidrun + all LLM providers
	log "Phase 7: Installing droidrun with all LLM providers..."
	if pip install --no-index --find-links "$wheels_dir" 'droidrun[google,anthropic,openai,deepseek,ollama,openrouter]'; then
		log "✓ droidrun installed successfully"
	else
		log_error "Failed to install droidrun"
		return 1
	fi

	log "✓ Droidrun installation completed successfully!"
	return 0
}

# Main function
main() {
	log "=== Droidrun Installation Script ==="
	log ""
	log "Configuration:"
	log "  WHEELS_URL: ${WHEELS_URL:-'(not provided, using existing wheels)'}"
	log "  WHEELS_DIR: $WHEELS_DIR"
	log "  PREFIX: $PREFIX"
	log ""

	# Download wheels if URL is provided
	if [ -n "$WHEELS_URL" ]; then
		download_wheels "$WHEELS_URL" "$WHEELS_DIR" || {
			log_error "Failed to download wheels"
			return 1
		}
	fi

	# Install droidrun from wheels
	install_droidrun_from_wheels "$WHEELS_DIR" || {
		log_error "Failed to install droidrun"
		return 1
	}

	log ""
	log "=== Installation Complete ==="
	log "You can now test droidrun by running: droidrun --help"
	
	return 0
}

# Show usage if help is requested
if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
	cat << EOF
Usage: $0 [WHEELS_URL] [WHEELS_DIR]

Install droidrun and its dependencies from pre-built wheel files.

Arguments:
  WHEELS_URL    (optional) URL to download wheels from (zip/tar.gz/tar)
                If not provided, will use existing wheels in WHEELS_DIR
  WHEELS_DIR    (optional) Directory containing wheel files
                Default: \$HOME/droidrun-wheels

Environment Variables:
  PREFIX        Termux prefix directory
                Default: /data/data/com.termux/files/usr

Examples:
  # Download and install from URL
  $0 https://example.com/wheels.zip

  # Install from local directory
  $0 "" /path/to/wheels

  # Use default directory (no download)
  $0

EOF
	exit 0
fi

# Run main function
main "$@"

