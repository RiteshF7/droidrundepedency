# Termux-Packages Python Cross-Compilation Analysis

## Executive Summary

This document analyzes the termux-packages codebase specifically for cross-compiling Python packages (wheel files) for Android architectures using a laptop. The termux-packages project provides a sophisticated build system that enables cross-compilation of Python packages from a Linux host to Android target architectures.

## Key Components

### 1. Cross-Compilation Architecture

The termux-packages build system supports cross-compilation for 4 Android architectures:
- **aarch64** (ARM 64-bit)
- **arm** (ARM 32-bit, armv7)
- **i686** (x86 32-bit)
- **x86_64** (x86 64-bit)

### 2. Core Build System (`build-package.sh`)

**Location**: `/termux-packages/build-package.sh`

The main build script orchestrates the entire cross-compilation process:

- **Architecture Selection**: Use `-a` flag to specify target architecture
  ```bash
  ./build-package.sh -a aarch64 python-numpy
  ```

- **Build Flow**:
  1. Setup variables and toolchain
  2. Get dependencies (including Python dependencies)
  3. Download/extract source
  4. Setup Python cross-compilation environment (crossenv)
  5. Configure, build, and install
  6. Package into .deb or .pkg.tar.xz

### 3. Python Cross-Compilation Setup (`termux_setup_python_pip.sh`)

**Location**: `/scripts/build/setup/termux_setup_python_pip.sh`

This is the **critical component** for Python wheel cross-compilation:

#### Crossenv Integration

The system uses **crossenv** (v1.4.0) to create a cross-compilation environment:

```bash
# Creates a cross-compilation Python environment
/usr/bin/python3.12 -m crossenv \
    "$TERMUX_PREFIX/bin/python3.12" \
    "${TERMUX_PYTHON_CROSSENV_PREFIX}"
```

**Key Features**:
- **build-pip**: Installs packages for the host (build) Python
- **cross-pip**: Installs packages for the target (Android) Python
- **Separate environments**: Build tools vs target libraries

**Environment Variables**:
- `TERMUX_PYTHON_CROSSENV_PREFIX`: Location of crossenv environment
  - Format: `$TERMUX_TOPDIR/python${VERSION}-crossenv-prefix-${LIBRARY}-${ARCH}`
  - Example: `~/.termux-build/python3.12-crossenv-prefix-bionic-aarch64`
- `TERMUX_PYTHON_HOME`: Target Python library location
- `PYTHONPATH`: Configured for cross-compilation

#### Wheel Building Tools

The system installs:
- `setuptools==78.1.0`
- `wheel==0.46.1`

Both in build and cross environments.

### 4. Toolchain Setup

**Location**: `/scripts/build/toolchain/termux_setup_toolchain_28c.sh`

#### Android NDK Integration

- Uses Android NDK to create standalone toolchains
- Supports NDK versions: 23c, 28c
- Creates architecture-specific toolchains in:
  `$TERMUX_COMMON_CACHEDIR/android-r${NDK_VERSION}-api-${API_LEVEL}`

#### Compiler Configuration

For each architecture, sets up:
- **CC/CXX**: `{arch}-linux-android{api}-clang`
- **Architecture-specific flags**:
  - ARM: `-march=armv7-a -mfpu=neon -mfloat-abi=softfp -mthumb`
  - i686: `-march=i686 -msse3 -mstackrealign -mfpmath=sse -fPIC`
  - aarch64/x86_64: Standard flags

#### Rust Support

For Rust-based Python packages (e.g., orjson):
- `CARGO_TARGET_NAME`: Set to `{arch}-linux-android`
- Special handling for arm → `armv7-linux-androideabi`

### 5. Python Package Build Patterns

#### Pattern 1: Standard Python Package (numpy example)

**Location**: `/packages/python-numpy/build.sh`

```bash
# Uses meson-python for building
TERMUX_PKG_PYTHON_COMMON_DEPS="wheel, 'Cython>=0.29.34,<3.1', 'meson-python>=0.15.0,<0.16.0', build"

termux_step_make() {
    python -m build -w -n -x --config-setting builddir=$TERMUX_PKG_BUILDDIR .
}

termux_step_make_install() {
    local _whl="numpy-$VERSION-cp${PYV}-cp${PYV}-linux_${ARCH}.whl"
    pip install --no-deps --prefix=$TERMUX_PREFIX --force-reinstall $TERMUX_PKG_SRCDIR/dist/$_whl
}
```

**Key Points**:
- Uses `python -m build` with wheel flag (`-w`)
- Wheel naming: `{package}-{version}-cp{pyver}-cp{pyver}-linux_{arch}.whl`
- Installs wheel directly to `$TERMUX_PREFIX`

#### Pattern 2: Rust-based Package (orjson example)

**Location**: `/packages/python-orjson/build.sh`

```bash
TERMUX_PKG_PYTHON_COMMON_DEPS="maturin, build, wheel, setuptools"

termux_step_make() {
    maturin build --release --target "$CARGO_TARGET_NAME" \
        --out dist --interpreter "python${TERMUX_PYTHON_VERSION}" \
        --skip-auditwheel
}
```

**Key Points**:
- Uses `maturin` for Rust-based Python extensions
- Requires Rust toolchain setup
- May need stub libraries for cross-compilation

#### Pattern 3: Cython-based Package (grpcio example)

**Location**: `/packages/python-grpcio/build.sh`

```bash
TERMUX_PKG_PYTHON_COMMON_DEPS="wheel, setuptools, 'Cython>=3.0.0'"
```

Uses standard Python build tools with Cython for C extensions.

### 6. Dependency Management

**Location**: `/scripts/build/termux_step_get_dependencies_python.sh`

The system handles three types of Python dependencies:

1. **TERMUX_PKG_PYTHON_COMMON_DEPS**: Installed in both build and cross environments
2. **TERMUX_PKG_PYTHON_BUILD_DEPS**: Only for build environment (host tools)
3. **TERMUX_PKG_PYTHON_TARGET_DEPS**: Only for target environment

**Installation Process**:
- Uses `build-pip` for build dependencies
- Uses `cross-pip` for target dependencies
- Tracks installed packages to avoid redundant installs

### 7. Wheel File Naming Convention

Termux uses PEP 425 wheel naming:
```
{package}-{version}-cp{pyver}-cp{pyver}-linux_{arch}.whl
```

**Architecture Mapping**:
- `aarch64` → `linux_aarch64`
- `arm` → `linux_armv7` (sometimes `linux_arm`)
- `i686` → `linux_i686`
- `x86_64` → `linux_x86_64`

**Python Version**:
- Extracted from `TERMUX_PYTHON_VERSION` (e.g., `3.12` → `cp312`)

### 8. Build Environment Variables

Critical environment variables for cross-compilation:

```bash
# Architecture
TERMUX_ARCH=aarch64|arm|i686|x86_64

# Python
TERMUX_PYTHON_VERSION=3.12
TERMUX_PYTHON_CROSSENV_PREFIX=~/.termux-build/python3.12-crossenv-prefix-bionic-aarch64
TERMUX_PYTHON_HOME=$TERMUX_PREFIX/lib/python3.12

# Toolchain
TERMUX_STANDALONE_TOOLCHAIN=~/.termux-build/_cache/android-r28c-api-24
TERMUX_HOST_PLATFORM=aarch64-linux-android
CC=aarch64-linux-android24-clang
CXX=aarch64-linux-android24-clang++

# Paths
TERMUX_PREFIX=/data/data/com.termux/files/usr
PYTHONPATH=$TERMUX_PYTHON_HOME/site-packages
```

### 9. Build Process Flow

```
1. Setup Variables (termux_step_setup_variables)
   ↓
2. Setup Toolchain (termux_step_setup_toolchain)
   - Create/use NDK standalone toolchain
   - Set CC, CXX, flags
   ↓
3. Get Dependencies (termux_step_get_dependencies)
   ↓
4. Get Python Dependencies (termux_step_get_dependencies_python)
   - Setup crossenv if TERMUX_PKG_SETUP_PYTHON=true
   - Install build and cross dependencies
   ↓
5. Get Source (termux_step_get_source)
   ↓
6. Configure (termux_step_configure)
   - May use meson, cmake, or autotools
   ↓
7. Make (termux_step_make)
   - Build wheel: `python -m build -w` or `maturin build`
   ↓
8. Make Install (termux_step_make_install)
   - Install wheel: `pip install --prefix=$TERMUX_PREFIX wheel.whl`
   ↓
9. Massage (termux_step_massage)
   - Clean up, fix paths, strip binaries
   ↓
10. Create Package (termux_step_create_debian_package)
    - Package into .deb or .pkg.tar.xz
```

### 10. Key Scripts and Their Roles

| Script | Purpose |
|--------|---------|
| `build-package.sh` | Main orchestrator |
| `termux_setup_python_pip.sh` | Setup crossenv for Python |
| `termux_step_get_dependencies_python.sh` | Install Python dependencies |
| `termux_setup_toolchain_28c.sh` | Setup Android NDK toolchain |
| `termux_step_setup_variables.sh` | Initialize build variables |
| `termux_step_massage.sh` | Post-build cleanup and fixes |

### 11. Crossenv Patches

**Location**: `/scripts/build/setup/python-crossenv-PYTHONPATH.patch`

The system patches crossenv to:
- Add build site-packages to PYTHONPATH
- Fix import issues with Python 3.11+
- Ensure proper path resolution for cross-compilation

### 12. Build Tools Integration

#### Meson
- Used for packages like numpy
- Creates cross-file for wheel building
- Location: `TERMUX_MESON_WHEEL_CROSSFILE`

#### CMake
- Standard CMake cross-compilation
- Uses `TERMUX_PKG_CMAKE_CROSSCOMPILING=true`

#### Build (PEP 517)
- Modern Python build backend
- Used via `python -m build -w`

### 13. Practical Usage Examples

#### Building a Python Package

```bash
# Build for aarch64
./build-package.sh -a aarch64 python-numpy

# Build for all architectures
./build-package.sh -a all python-numpy

# Force rebuild
./build-package.sh -f -a aarch64 python-numpy
```

#### Custom Package Build Script

```bash
TERMUX_PKG_HOMEPAGE=...
TERMUX_PKG_DESCRIPTION=...
TERMUX_PKG_VERSION=1.0.0
TERMUX_PKG_PYTHON_COMMON_DEPS="wheel, build"

termux_step_make() {
    python -m build -w -n -x .
}

termux_step_make_install() {
    local _whl="package-$TERMUX_PKG_VERSION-cp${TERMUX_PYTHON_VERSION//./}-cp${TERMUX_PYTHON_VERSION//./}-linux_$TERMUX_ARCH.whl"
    pip install --no-deps --prefix=$TERMUX_PREFIX --force-reinstall $TERMUX_PKG_SRCDIR/dist/$_whl
}
```

### 14. Challenges and Solutions

#### Challenge 1: Native Extensions
**Solution**: Use crossenv to separate build and target environments

#### Challenge 2: Rust Dependencies
**Solution**: Setup Rust toolchain with Android targets, use maturin

#### Challenge 3: Build Tools Detection
**Solution**: Use `build-pip` for host tools, `cross-pip` for target

#### Challenge 4: Library Linking
**Solution**: Proper LDFLAGS and library paths in toolchain setup

### 15. Output Locations

- **Built packages**: `output/` directory (or `-o` specified directory)
- **Wheel files**: `$TERMUX_PKG_SRCDIR/dist/*.whl` (temporary)
- **Installed files**: `$TERMUX_PKG_MASSAGEDIR/$TERMUX_PREFIX/`
- **Cache**: `$TERMUX_TOPDIR/_cache/` (crossenv, toolchains)

### 16. Key Takeaways

1. **Crossenv is Essential**: The crossenv tool creates the bridge between host and target Python environments

2. **Architecture-Specific Builds**: Each architecture requires a separate build with proper toolchain setup

3. **Wheel Naming Matters**: Follow PEP 425 conventions for proper wheel identification

4. **Dependency Separation**: Build dependencies vs target dependencies must be clearly separated

5. **Toolchain Setup**: Android NDK toolchain must be properly configured for each architecture

6. **Modern Build Tools**: The system uses modern Python build tools (`build`, `meson-python`, `maturin`)

## Conclusion

The termux-packages build system provides a comprehensive solution for cross-compiling Python packages to Android. The key innovation is the use of crossenv to create separate build and target Python environments, combined with proper Android NDK toolchain setup. This allows building Python wheels with native extensions on a Linux host for Android target architectures.

