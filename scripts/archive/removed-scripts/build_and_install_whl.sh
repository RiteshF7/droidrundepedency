#!/bin/bash

# Usage: ./build_and_install_whl.sh <package> <version>
# Example: ./build_and_install_whl.sh pandas 2.2.3

PKG_NAME=$1
PKG_VERSION=$2

if [ -z "$PKG_NAME" ] || [ -z "$PKG_VERSION" ]; then
  echo "Usage: $0 <package> <version>"
  exit 1
fi

adb shell "run-as com.termux sh -c '
  export PREFIX=/data/data/com.termux/files/usr &&
  export HOME=/data/data/com.termux/files/home &&
  export PATH=\$PREFIX/bin:\$PATH &&
  cd ~/wheels &&
  echo \"=== Building $PKG_NAME $PKG_VERSION wheel ===\" &&
  export NPY_NUM_BUILD_JOBS=1 &&
  pip wheel $PKG_NAME==$PKG_VERSION --no-deps --wheel-dir . --no-cache-dir &&
  echo \"✅ $PKG_NAME $PKG_VERSION wheel built\" &&
  echo \"=== Installing globally ===\" &&
  pip install ~/wheels/$PKG_NAME-$PKG_VERSION-*.whl --no-deps &&
  echo \"✅ Installed $PKG_NAME $PKG_VERSION globally\"
'"

