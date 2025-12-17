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

# Default values - GitHub release URL for pre-built wheels
GITHUB_REPO="RiteshF7/droidrundepedency"
GITHUB_RELEASE_TAG="v1.0.0-wheels"
GITHUB_RELEASE_FILE="_x86_64_wheels.7z"
DEFAULT_WHEELS_URL="https://github.com/${GITHUB_REPO}/releases/download/${GITHUB_RELEASE_TAG}/${GITHUB_RELEASE_FILE}"

WHEELS_URL="${1:-${DEFAULT_WHEELS_URL}}"
WHEELS_DIR="${2:-${HOME}/droidrun-wheels}"
PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"

# Function to check if wheels already exist
wheels_exist() {
	local wheels_dir="$1"
	
	# Check if directory exists and has wheel files
	if [ -d "$wheels_dir" ]; then
		# Check main directory
		if ls -1 "${wheels_dir}"/*.whl >/dev/null 2>&1; then
			return 0
		fi
		# Check subdirectory (_x86_64_wheels)
		if [ -d "${wheels_dir}/_x86_64_wheels" ] && ls -1 "${wheels_dir}/_x86_64_wheels"/*.whl >/dev/null 2>&1; then
			return 0
		fi
	fi
	return 1
}

# Function to download wheels from URL
download_wheels() {
	local url="$1"
	local dest_dir="$2"

	if [ -z "$url" ]; then
		log_warn "No URL provided, skipping download. Using existing wheels in $dest_dir"
		return 0
	fi

	# Check if wheels already exist
	if wheels_exist "$dest_dir"; then
		log "Wheels already exist in $dest_dir, skipping download"
		return 0
	fi

	log "Downloading wheels from: $url"
	
	# Create destination directory
	mkdir -p "$dest_dir" || {
		log_error "Failed to create directory: $dest_dir"
		return 1
	}

	# Determine file extension and set temp file name
	local file_ext=""
	local temp_file=""
	
	if [[ "$url" == *.7z ]] || [[ "$url" == *.7Z ]]; then
		file_ext="7z"
		temp_file="${dest_dir}/wheels_temp.7z"
		# Check if 7z extraction tool is available BEFORE downloading
		if ! command -v 7z &> /dev/null && ! command -v 7za &> /dev/null; then
			log "7z or 7za not found. Attempting to install p7zip..."
			if ! install_p7zip; then
				log_error "Cannot extract .7z files without p7zip"
				return 1
			fi
			# Refresh command cache
			hash -r 2>/dev/null || true
		fi
	elif [[ "$url" == *.zip ]] || [[ "$url" == *.ZIP ]]; then
		file_ext="zip"
		temp_file="${dest_dir}/wheels_temp.zip"
		# Check if unzip is available
		if ! command -v unzip &> /dev/null; then
			log "unzip not found. Attempting to install..."
			if ! install_unzip; then
				log_error "Cannot extract .zip files without unzip"
				return 1
			fi
			# Refresh command cache
			hash -r 2>/dev/null || true
		fi
	elif [[ "$url" == *.tar.gz ]] || [[ "$url" == *.tgz ]]; then
		file_ext="tar.gz"
		temp_file="${dest_dir}/wheels_temp.tar.gz"
	elif [[ "$url" == *.tar ]]; then
		file_ext="tar"
		temp_file="${dest_dir}/wheels_temp.tar"
	else
		log_warn "Unknown file type, assuming zip"
		file_ext="zip"
		temp_file="${dest_dir}/wheels_temp.zip"
		if ! command -v unzip &> /dev/null; then
			log "unzip not found. Attempting to install..."
			if ! install_unzip; then
				log_error "Cannot extract files without unzip"
				return 1
			fi
			# Refresh command cache
			hash -r 2>/dev/null || true
		fi
	fi
	
	log "Downloading wheels archive..."
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

	# Extract wheels based on file type
	log "Extracting wheels archive..."
	if [ "$file_ext" = "7z" ]; then
		# Extract using 7z or 7za (already checked availability above)
		if command -v 7z &> /dev/null; then
			if 7z x -o"$dest_dir" "$temp_file" -y > /dev/null 2>&1; then
				log "✓ Successfully extracted 7z archive"
			else
				log_error "Failed to extract 7z file"
				rm -f "$temp_file"
				return 1
			fi
		elif command -v 7za &> /dev/null; then
			if 7za x -o"$dest_dir" "$temp_file" -y > /dev/null 2>&1; then
				log "✓ Successfully extracted 7z archive"
			else
				log_error "Failed to extract 7z file"
				rm -f "$temp_file"
				return 1
			fi
		fi
		# For 7z files, wheels are in _x86_64_wheels subdirectory
		# The extraction creates: dest_dir/_x86_64_wheels/*.whl
		# We'll handle this in the main function
	elif [ "$file_ext" = "zip" ]; then
		unzip -q -o "$temp_file" -d "$dest_dir" || {
			log_error "Failed to extract zip file"
			return 1
		}
	elif [ "$file_ext" = "tar.gz" ] || [ "$file_ext" = "tgz" ]; then
		tar -xzf "$temp_file" -C "$dest_dir" || {
			log_error "Failed to extract tar.gz file"
			return 1
		}
	elif [ "$file_ext" = "tar" ]; then
		tar -xf "$temp_file" -C "$dest_dir" || {
			log_error "Failed to extract tar file"
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

	# Check for wheels in subdirectory (_x86_64_wheels) if main directory is empty
	local actual_wheels_dir="$wheels_dir"
	if [ ! -f "${wheels_dir}"/*.whl ] 2>/dev/null && [ -d "${wheels_dir}/_x86_64_wheels" ]; then
		actual_wheels_dir="${wheels_dir}/_x86_64_wheels"
		log "Using wheels from subdirectory: $actual_wheels_dir"
	fi

	local wheel_count
	wheel_count=$(ls -1 "${actual_wheels_dir}"/*.whl 2>/dev/null | wc -l)
	if [ "$wheel_count" -eq 0 ]; then
		log_error "No wheel files found in $actual_wheels_dir"
		return 1
	fi

	log "Found $wheel_count wheel files in $actual_wheels_dir"
	
	# Update wheels_dir to point to actual location
	wheels_dir="$actual_wheels_dir"

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
		log "pip not found, attempting to install python-pip..."
		if ! install_python_pip; then
			log_error "Cannot install droidrun without pip"
			return 1
		fi
		# Verify pip is now available
		if ! command -v pip &> /dev/null; then
			log_error "python-pip installed but pip still not found in PATH"
			log_error "Please restart your terminal or run: hash -r"
			return 1
		fi
	fi

	log "Using pip: $(which pip)"
	log "Python version: $(python --version 2>&1 || echo 'unknown')"

	# Phase 1: Build Tools (Pure Python) - MUST be installed first
	# These are build-time dependencies, but we install them from wheels if available
	log "Phase 1: Installing build tools (Cython, meson-python, maturin)..."
	
	log "  Installing Cython (required for numpy, scipy, pandas, scikit-learn)..."
	pip install --no-index --find-links "$wheels_dir" Cython 2>/dev/null || {
		# If not in wheels, try installing from PyPI (pure Python, should work)
		log_warn "Cython not found in wheels, installing from PyPI..."
		pip install Cython || {
			log_error "Failed to install Cython"
			return 1
		}
	}
	
	log "  Installing meson-python (required for pandas, scikit-learn)..."
	pip install --no-index --find-links "$wheels_dir" "meson-python<0.19.0,>=0.16.0" 2>/dev/null || {
		log_warn "meson-python not found in wheels, installing from PyPI..."
		pip install "meson-python<0.19.0,>=0.16.0" || {
			log_error "Failed to install meson-python"
			return 1
		}
	}
	
	log "  Installing maturin (required for jiter)..."
	pip install --no-index --find-links "$wheels_dir" "maturin<2,>=1.9.4" 2>/dev/null || {
		log_warn "maturin not found in wheels, installing from PyPI..."
		pip install "maturin<2,>=1.9.4" || {
			log_error "Failed to install maturin"
			return 1
		}
	}
	log "✓ Phase 1 build tools installed successfully"

	# Phase 2: numpy (foundation) - MUST be installed before scipy, pandas, scikit-learn, pyarrow
	log "Phase 2: Installing numpy (foundation for scipy, pandas, scikit-learn, pyarrow)..."
	if pip install --no-index --find-links "$wheels_dir" numpy; then
		log "✓ numpy installed successfully"
	else
		log_error "Failed to install numpy"
		return 1
	fi
	
	# Verify numpy is installed and importable
	if ! python3 -c "import numpy" 2>/dev/null; then
		log_error "numpy installation verification failed"
		return 1
	fi

	# Phase 3: Scientific Stack
	# scipy → scikit-learn (requires numpy)
	log "Phase 3: Installing scipy (required for scikit-learn)..."
	if pip install --no-index --find-links "$wheels_dir" scipy; then
		log "✓ scipy installed successfully"
	else
		log_error "Failed to install scipy"
		return 1
	fi

	# pandas → llama-index-readers-file (requires numpy, meson-python)
	log "Phase 3: Installing pandas (requires numpy, meson-python)..."
	# Ensure numpy is explicitly available before installing pandas
	log "  Verifying numpy is available..."
	pip install --no-index --find-links "$wheels_dir" numpy --upgrade --force-reinstall 2>/dev/null || true
	
	# Install pandas pure Python dependencies first (python-dateutil, pytz, tzdata)
	log "  Installing pandas dependencies (python-dateutil, pytz, tzdata)..."
	pip install --no-index --find-links "$wheels_dir" python-dateutil pytz tzdata 2>/dev/null || {
		# If not in wheels, try PyPI (these are pure Python)
		log_warn "Some pandas dependencies not in wheels, installing from PyPI..."
		pip install python-dateutil pytz tzdata 2>/dev/null || log_warn "Some pandas dependencies may already be installed"
	}
	
	# Now install pandas (numpy and meson-python should already be installed)
	if pip install --no-index --find-links "$wheels_dir" "pandas<2.3.0"; then
		log "✓ pandas installed successfully"
	else
		log_error "Failed to install pandas"
		log_error "Make sure numpy and meson-python are installed first"
		return 1
	fi

	# scikit-learn → arize-phoenix (requires numpy, scipy, meson-python, joblib>=1.3.0, threadpoolctl>=3.2.0)
	log "Phase 3: Installing scikit-learn dependencies (joblib, threadpoolctl)..."
	pip install --no-index --find-links "$wheels_dir" "joblib>=1.3.0" "threadpoolctl>=3.2.0" 2>/dev/null || {
		# If not in wheels, try PyPI (these are pure Python)
		log_warn "scikit-learn dependencies not in wheels, installing from PyPI..."
		pip install "joblib>=1.3.0" "threadpoolctl>=3.2.0" || {
			log_error "Failed to install scikit-learn dependencies"
			return 1
		}
	}
	
	log "Phase 3: Installing scikit-learn (requires numpy, scipy, meson-python, joblib, threadpoolctl)..."
	if pip install --no-index --find-links "$wheels_dir" scikit-learn; then
		log "✓ scikit-learn installed successfully"
	else
		log_error "Failed to install scikit-learn"
		log_error "Make sure numpy, scipy, meson-python, joblib, and threadpoolctl are installed first"
		return 1
	fi

	# Phase 4: Rust Packages
	# jiter → arize-phoenix (requires maturin, already installed in Phase 1)
	log "Phase 4: Installing jiter (required for arize-phoenix, depends on maturin)..."
	if pip install --no-index --find-links "$wheels_dir" "jiter==0.12.0"; then
		log "✓ jiter installed successfully"
	else
		log_error "Failed to install jiter"
		return 1
	fi

	# Phase 5: Other compiled packages
	# pyarrow → arize-phoenix (requires numpy, already installed in Phase 2)
	# psutil → arize-phoenix
	# grpcio → google-cloud packages
	# Pillow → image processing
	log "Phase 5: Installing pyarrow (required for arize-phoenix, depends on numpy)..."
	if pip install --no-index --find-links "$wheels_dir" pyarrow; then
		log "✓ pyarrow installed successfully"
	else
		log_warn "pyarrow installation failed (optional)"
	fi

	log "Phase 5: Installing psutil (required for arize-phoenix)..."
	if pip install --no-index --find-links "$wheels_dir" psutil; then
		log "✓ psutil installed successfully"
	else
		log_error "Failed to install psutil"
		return 1
	fi

	log "Phase 5: Installing grpcio (required for google-cloud packages)..."
	if pip install --no-index --find-links "$wheels_dir" grpcio; then
		log "✓ grpcio installed successfully"
	else
		log_error "Failed to install grpcio"
		return 1
	fi

	log "Phase 5: Installing Pillow (required for image processing)..."
	if pip install --no-index --find-links "$wheels_dir" Pillow; then
		log "✓ Pillow installed successfully"
	else
		log_error "Failed to install Pillow"
		return 1
	fi

	# Phase 6: Optional compiled packages
	# Install these before droidrun to ensure dependencies are available
	# tokenizers → transformers → llama-index-llms-deepseek
	# safetensors → transformers
	# cryptography → google-auth, authlib
	# pydantic-core → pydantic
	# orjson → fastapi, arize-phoenix
	log "Phase 6: Installing optional compiled packages..."
	
	log "  Installing tokenizers (required for transformers → llama-index-llms-deepseek)..."
	pip install --no-index --find-links "$wheels_dir" tokenizers || log_warn "tokenizers installation failed (optional)"
	
	log "  Installing safetensors (required for transformers)..."
	pip install --no-index --find-links "$wheels_dir" safetensors || log_warn "safetensors installation failed (optional)"
	
	log "  Installing cryptography (required for google-auth, authlib)..."
	pip install --no-index --find-links "$wheels_dir" cryptography || log_warn "cryptography installation failed (optional)"
	
	log "  Installing pydantic-core (required for pydantic)..."
	pip install --no-index --find-links "$wheels_dir" pydantic-core || log_warn "pydantic-core installation failed (optional)"
	
	log "  Installing orjson (required for fastapi, arize-phoenix)..."
	pip install --no-index --find-links "$wheels_dir" orjson || log_warn "orjson installation failed (optional)"

	# Phase 7: Main Package + LLM Providers
	# All dependencies should now be installed:
	# - numpy, scipy, pandas, scikit-learn (Phase 2-3)
	# - jiter, pyarrow, psutil (Phase 4-5)
	# - tokenizers, safetensors, cryptography, pydantic-core, orjson (Phase 6)
	# - grpcio, Pillow (Phase 5)
	log "Phase 7: Installing droidrun with all LLM providers..."
	log "  All dependencies should be installed: numpy, scipy, pandas, scikit-learn, jiter, pyarrow, psutil, grpcio, Pillow, tokenizers, safetensors, cryptography, pydantic-core, orjson"
	if pip install --no-index --find-links "$wheels_dir" 'droidrun[google,anthropic,openai,deepseek,ollama,openrouter]'; then
		log "✓ droidrun installed successfully"
	else
		log_error "Failed to install droidrun"
		log_error "Make sure all dependencies from Phase 1-6 are installed correctly"
		return 1
	fi

	log "✓ Droidrun installation completed successfully!"
	return 0
}

# Function to install p7zip
install_p7zip() {
	log "Installing p7zip (required for 7z extraction)..."
	if command -v pkg &> /dev/null; then
		if pkg install -y p7zip > /dev/null 2>&1; then
			log "✓ p7zip installed successfully"
			return 0
		else
			log_error "Failed to install p7zip. Please install manually: pkg install p7zip"
			return 1
		fi
	else
		log_error "pkg command not found. Cannot auto-install p7zip."
		log_error "Please install manually: pkg install p7zip"
		return 1
	fi
}

# Function to install unzip
install_unzip() {
	log "Installing unzip (required for zip extraction)..."
	if command -v pkg &> /dev/null; then
		if pkg install -y unzip > /dev/null 2>&1; then
			log "✓ unzip installed successfully"
			return 0
		else
			log_error "Failed to install unzip. Please install manually: pkg install unzip"
			return 1
		fi
	else
		log_error "pkg command not found. Cannot auto-install unzip."
		log_error "Please install manually: pkg install unzip"
		return 1
	fi
}

# Function to install python-pip
install_python_pip() {
	log "Installing python-pip (required for Python package installation)..."
	if command -v pkg &> /dev/null; then
		if pkg install -y python-pip > /dev/null 2>&1; then
			log "✓ python-pip installed successfully"
			# Refresh command cache
			hash -r 2>/dev/null || true
			return 0
		else
			log_error "Failed to install python-pip. Please install manually: pkg install python-pip"
			return 1
		fi
	else
		log_error "pkg command not found. Cannot auto-install python-pip."
		log_error "Please install manually: pkg install python-pip"
		return 1
	fi
}

# Function to check and install required tools
check_required_tools() {
	# Check for download tools
	if ! command -v curl &> /dev/null && ! command -v wget &> /dev/null; then
		log_error "Neither curl nor wget is available. Cannot download wheels."
		log_error "Please install: pkg install curl"
		return 1
	fi
	
	# Check for extraction tools based on URL
	if [[ "$WHEELS_URL" == *.7z ]] || [[ "$WHEELS_URL" == *.7Z ]] || [[ "$WHEELS_URL" == "$DEFAULT_WHEELS_URL" ]]; then
		if ! command -v 7z &> /dev/null && ! command -v 7za &> /dev/null; then
			log "7z/7za not found, attempting to install p7zip..."
			if ! install_p7zip; then
				return 1
			fi
			# Verify installation
			if ! command -v 7z &> /dev/null && ! command -v 7za &> /dev/null; then
				log_error "p7zip installed but 7z/7za still not found in PATH"
				log_error "Please restart your terminal or run: hash -r"
				return 1
			fi
		fi
	elif [[ "$WHEELS_URL" == *.zip ]] || [[ "$WHEELS_URL" == *.ZIP ]]; then
		if ! command -v unzip &> /dev/null; then
			log "unzip not found, attempting to install..."
			if ! install_unzip; then
				return 1
			fi
			# Verify installation
			if ! command -v unzip &> /dev/null; then
				log_error "unzip installed but still not found in PATH"
				log_error "Please restart your terminal or run: hash -r"
				return 1
			fi
		fi
	fi
	
	return 0
}

# Main function
main() {
	log "=== Droidrun Installation Script ==="
	log ""
	log "Configuration:"
	if [ "$WHEELS_URL" = "$DEFAULT_WHEELS_URL" ]; then
		log "  WHEELS_URL: ${WHEELS_URL} (GitHub release)"
	else
		log "  WHEELS_URL: ${WHEELS_URL:-'(not provided, using existing wheels)'}"
	fi
	log "  WHEELS_DIR: $WHEELS_DIR"
	log "  PREFIX: $PREFIX"
	log ""
	
	# Check required tools if we need to download
	if [ -n "$WHEELS_URL" ] && [ "$WHEELS_URL" != "none" ] && ! wheels_exist "$WHEELS_DIR"; then
		if ! check_required_tools; then
			log_error "Please install the missing tools and try again."
			return 1
		fi
	fi

	# Check if wheels already exist before downloading
	if wheels_exist "$WHEELS_DIR"; then
		log "Wheels already exist, skipping download"
		# Update WHEELS_DIR if wheels are in subdirectory
		if [ -d "${WHEELS_DIR}/_x86_64_wheels" ] && [ "$(ls -A "${WHEELS_DIR}/_x86_64_wheels"/*.whl 2>/dev/null | wc -l)" -gt 0 ]; then
			log "Using wheels from _x86_64_wheels subdirectory"
			WHEELS_DIR="${WHEELS_DIR}/_x86_64_wheels"
		fi
	elif [ -n "$WHEELS_URL" ] && [ "$WHEELS_URL" != "none" ]; then
		# Download wheels if URL is provided (or use default GitHub release)
		download_wheels "$WHEELS_URL" "$WHEELS_DIR" || {
			log_error "Failed to download wheels"
			return 1
		}
		# Update WHEELS_DIR if extraction created _x86_64_wheels subdirectory (for 7z files)
		if [ -d "${WHEELS_DIR}/_x86_64_wheels" ] && [ "$(ls -A "${WHEELS_DIR}/_x86_64_wheels"/*.whl 2>/dev/null | wc -l)" -gt 0 ]; then
			log "Using wheels from _x86_64_wheels subdirectory"
			WHEELS_DIR="${WHEELS_DIR}/_x86_64_wheels"
		fi
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
  WHEELS_URL    (optional) URL to download wheels from (7z/zip/tar.gz/tar)
                Default: GitHub release (v1.0.0-wheels)
                Use "none" to skip download and use existing wheels
  WHEELS_DIR    (optional) Directory containing wheel files
                Default: \$HOME/droidrun-wheels

Environment Variables:
  PREFIX        Termux prefix directory
                Default: /data/data/com.termux/files/usr

Examples:
  # Download from GitHub release and install (default)
  $0

  # Download from custom URL
  $0 https://example.com/wheels.7z

  # Install from local directory (skip download)
  $0 none /path/to/wheels

  # Use default GitHub release with custom directory
  $0 "" /path/to/wheels

EOF
	exit 0
fi

# Run main function
main "$@"

