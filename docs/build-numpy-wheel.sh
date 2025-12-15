#!/bin/bash
# build-numpy-wheel.sh
# Build numpy wheel with all prerequisites based on Error #2 fix
# This ensures patchelf and all build dependencies are installed first

set -e

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Building numpy wheel with all prerequisites"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Step 1: Install system build dependencies (required for patchelf/numpy)
echo "Step 1: Installing system build dependencies..."
pkg install -y autoconf automake libtool make binutils clang cmake ninja

# Step 2: Upgrade pip and install Python build tools
echo ""
echo "Step 2: Installing Python build tools..."
pip install --upgrade pip wheel build setuptools

# Step 3: Install meson-python (required for numpy)
echo ""
echo "Step 3: Installing meson-python..."
pip install "meson-python<0.19.0,>=0.16.0"

# Step 4: Set parallelism limits (prevents memory exhaustion)
echo ""
echo "Step 4: Setting build environment variables..."
export NINJAFLAGS="-j2"
export MAKEFLAGS="-j2"
export MAX_JOBS=2

# Step 5: Create wheels directory
echo ""
echo "Step 5: Preparing wheels directory..."
mkdir -p ~/wheels
cd ~/wheels

# Step 6: Download numpy source
echo ""
echo "Step 6: Downloading numpy source..."
pip download numpy --dest . --no-cache-dir

# Step 7: Build numpy wheel
echo ""
echo "Step 7: Building numpy wheel (this will take 20-40 minutes)..."
echo "Note: patchelf will be built automatically if needed"
pip wheel numpy --no-deps --wheel-dir .

# Step 8: Install numpy from wheel
echo ""
echo "Step 8: Installing numpy from wheel..."
pip install --find-links . --no-index numpy*.whl

# Step 9: Verify installation
echo ""
echo "Step 9: Verifying installation..."
pip show numpy
python3 -c "import numpy; print('✅ numpy version:', numpy.__version__)"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ numpy wheel built and installed successfully!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

