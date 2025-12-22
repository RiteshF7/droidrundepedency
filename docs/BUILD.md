# Building WHL Files for Android/Termux

Complete guide for building Python wheel files for droidrun dependencies on Android devices using Termux.

## Quick Start

```bash
# On Android device with Termux installed
cd ~/droidrunBuild
./build.sh
```

## Prerequisites

### 1. Install System Dependencies

```bash
pkg install -y python python-pip autoconf automake libtool make binutils clang cmake ninja rust flang blas-openblas libjpeg-turbo libpng libtiff libwebp freetype libarrow-cpp openssl libc++ zlib protobuf libprotobuf abseil-cpp c-ares libre2 patchelf

# Create gfortran symlink for scipy compatibility
ln -sf $PREFIX/bin/flang $PREFIX/bin/gfortran
```

### 2. Setup Build Environment

```bash
# Set PREFIX (Termux default)
export PREFIX=${PREFIX:-/data/data/com.termux/files/usr}

# Build parallelization (limit to 2 jobs to avoid memory issues)
export NINJAFLAGS="-j2"
export MAKEFLAGS="-j2"
export MAX_JOBS=2

# CMAKE configuration
export CMAKE_PREFIX_PATH=$PREFIX
export CMAKE_INCLUDE_PATH=$PREFIX/include

# Compiler environment variables
export CC=$PREFIX/bin/clang
export CXX=$PREFIX/bin/clang++

# Temporary directory
export TMPDIR=$HOME/tmp
mkdir -p $TMPDIR

# Wheels directory
mkdir -p ~/wheels
```

### 3. Install Build Tools

```bash
pip install --upgrade pip wheel setuptools
pip install Cython "meson-python<0.19.0,>=0.16.0" "maturin<2,>=1.9.4"
```

## Build Process

### Using the Automated Script

The main build script (`build.sh`) automatically:
1. Sets up build environment
2. Scans source packages in `depedencies/source/`
3. Resolves dependencies
4. Builds wheels in correct order
5. Applies Termux-specific fixes

```bash
./build.sh
```

### Manual Build

If you need to build manually:

```bash
cd depedencies/source
python3 build_wheels.py --source-dir . --wheels-dir ~/wheels
```

## Build Order

Packages are built in dependency order:

1. **Build Tools**: Cython, meson-python, maturin
2. **Foundation**: numpy
3. **Scientific Stack**: scipy, pandas, scikit-learn
4. **Rust Packages**: jiter
5. **Other Compiled**: pyarrow, psutil, grpcio, pillow
6. **Optional**: tokenizers, safetensors, cryptography, pydantic-core, orjson

## Special Fixes Applied

The build script automatically applies fixes for:

- **pandas**: Fixes meson.build version detection
- **scikit-learn**: Fixes version.py permissions and meson.build
- **grpcio**: Patches wheel post-build (adds abseil libraries, sets RPATH)
- **pyarrow**: Sets ARROW_HOME environment variable
- **pillow**: Sets PKG_CONFIG_PATH, LDFLAGS, CPPFLAGS

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for detailed information about these fixes.

## Output

Built wheels are saved to `~/wheels/` directory.

To use the wheels:

```bash
pip install <package> --find-links ~/wheels --no-index
```

## See Also

- [DEPENDENCIES.md](../DEPENDENCIES.md) - Complete dependency information
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Common errors and solutions






