#!/bin/bash

# Usage: ./build_and_install_whl.sh <package> <version>
# Example: ./build_and_install_whl.sh pandas 2.2.3

PKG_NAME=$1
PKG_VERSION=$2

if [ -z "$PKG_NAME" ] || [ -z "$PKG_VERSION" ]; then
  echo "Usage: $0 <package> <version>"
  exit 1
fi

export PREFIX=/data/data/com.termux/files/usr
export HOME=/data/data/com.termux/files/home
export PATH=$PREFIX/bin:$PATH
cd ~/wheels

echo "=== Building $PKG_NAME $PKG_VERSION wheel ==="
export NPY_NUM_BUILD_JOBS=1
pip wheel $PKG_NAME==$PKG_VERSION --no-deps --wheel-dir . --no-cache-dir

if [ $? -eq 0 ]; then
  echo "✅ $PKG_NAME $PKG_VERSION wheel built"
  echo "=== Installing globally ==="
  pip install --force-reinstall --no-deps ~/wheels/$PKG_NAME-$PKG_VERSION-*.whl
  if [ $? -eq 0 ]; then
    echo "✅ Installed $PKG_NAME $PKG_VERSION globally"
    python -c "import $PKG_NAME; print(f'Version: {$PKG_NAME.__version__}')" 2>/dev/null || echo "Note: Could not verify version"
  else
    echo "❌ Failed to install $PKG_NAME"
    exit 1
  fi
else
  echo "❌ Failed to build $PKG_NAME wheel"
  exit 1
fi

