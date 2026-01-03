# Stable Method for Building Python Wheels via Cross-Compilation

## Overview

The **most stable method** for building Python wheels for Android/Termux is using the **Termux build system** (`termux-packages`) with the official `build-package.sh` script. This method leverages the proven infrastructure that Termux uses to build all its packages.

## Method 1: Using Termux build-package.sh (Recommended - Most Stable)

### Prerequisites

1. **Termux build system setup:**
   ```bash
   cd termux-packages
   # Ensure you have the build system dependencies
   ```

2. **Android SDK/NDK:**
   ```bash
   export ANDROID_SDK_ROOT="/path/to/android/sdk"
   export NDK="$ANDROID_SDK_ROOT/ndk/r26b"  # or your NDK version
   ```

3. **Set architecture:**
   ```bash
   export TERMUX_ARCH=x86_64  # or aarch64, arm, i686
   export TERMUX_PYTHON_VERSION=3.12  # or your Python version
   ```

### Build Process

```bash
cd termux-packages

# Build a single package (handles dependencies automatically)
./build-package.sh python-numpy

# Build multiple packages in dependency order
./build-package.sh python-numpy python-scipy python-scikit-learn

# Build with output to specific directory
TERMUX_PKG_OUTPUT_DIR=~/wheels ./build-package.sh python-numpy
```

### Advantages

✅ **Automatic dependency resolution** - Builds dependencies in correct order  
✅ **Proven infrastructure** - Used by Termux for all packages  
✅ **Cross-compilation toolchain** - Properly configured NDK toolchain  
✅ **Wheel extraction** - Automatically extracts wheels from build output  
✅ **Consistent environment** - Same environment as official Termux builds  

### How It Works

1. `build-package.sh` sources the package's `build.sh`
2. Build script follows Termux conventions:
   - `termux_step_pre_configure()` - Setup environment
   - `termux_step_configure()` - Configure build
   - `termux_step_make()` - Build wheel
   - `termux_step_make_install()` - Install/extract wheel
3. Dependencies are automatically built first
4. Wheels are extracted to output directory

---

## Method 2: Standalone build.sh with Utility Scripts

For packages that need to be built outside the full Termux build system, use the utility scripts in `buildutilscripts/`.

### Structure

```bash
termux-packages/
├── buildutilscripts/
│   ├── setup_android_env.sh          # Android SDK/NDK setup
│   ├── setup_ndk_toolchain.sh        # Cross-compilation toolchain
│   ├── setup_android_compiler_flags.sh # Compiler flags
│   ├── create_meson_cross_file.sh    # Meson cross-compilation
│   ├── install_python_deps.sh        # Python dependencies
│   ├── download_pypi_source.sh       # Download from PyPI
│   ├── create_stub_libs.sh           # Stub libraries (Rust packages)
│   ├── setup_rust_android.sh         # Rust cross-compilation
│   └── copy_wheel_to_output.sh       # Extract wheels
└── packages/
    └── python-<package>/
        └── build.sh                   # Package build script
```

### Example build.sh Template

```bash
#!/bin/bash
set -e

# Source utility scripts
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILDUTIL_DIR="$(cd "$SCRIPT_DIR/../../buildutilscripts" && pwd)"
source "$BUILDUTIL_DIR/setup_android_env.sh"
source "$BUILDUTIL_DIR/setup_ndk_toolchain.sh"
source "$BUILDUTIL_DIR/setup_android_compiler_flags.sh"
source "$BUILDUTIL_DIR/create_meson_cross_file.sh"
source "$BUILDUTIL_DIR/install_python_deps.sh"
source "$BUILDUTIL_DIR/download_pypi_source.sh"
source "$BUILDUTIL_DIR/copy_wheel_to_output.sh"

# Package metadata
TERMUX_PKG_VERSION="1.0.0"
TERMUX_PKG_SRCURL="https://pypi.io/packages/source/p/package/package-${TERMUX_PKG_VERSION}.tar.gz"

termux_step_pre_configure() {
    # Setup NDK toolchain
    if [ -z "$CC" ] && [ -n "$NDK" ]; then
        setup_ndk_toolchain
        setup_android_compiler_flags
        
        # For meson-based packages
        local _meson_cross_file="$TERMUX_PKG_SRCDIR/meson-cross.ini"
        create_meson_cross_file "$_meson_cross_file"
    fi
    
    # Install Python build dependencies
    install_python_deps "numpy>=2.0" "scipy>=1.10.0"
}

termux_step_make() {
    # Build wheel
    python3 -m pip wheel . --no-deps --no-build-isolation --wheel-dir dist
}

termux_step_make_install() {
    # Extract wheel to output
    copy_wheel_to_output "package_name" "$TERMUX_PKG_VERSION" "$TERMUX_PKG_SRCDIR"
}

# Standalone execution
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    setup_android_sdk_ndk || exit 1
    setup_termux_build_env
    
    # Download source
    download_pypi_source "package" "$TERMUX_PKG_VERSION" "$TERMUX_PKG_SRCDIR"
    tar -xzf "package-${TERMUX_PKG_VERSION}.tar.gz" --strip-components=1
    
    # Run build steps
    termux_step_pre_configure
    termux_step_make
    
    # Copy wheel
    copy_wheel_to_output "package_name" "$TERMUX_PKG_VERSION" "$TERMUX_PKG_SRCDIR"
fi
```

### Usage

```bash
# Set environment
export TERMUX_ARCH=x86_64
export TERMUX_PYTHON_VERSION=3.12
export WHEELS_DIR=~/wheels

# Run build script
cd termux-packages/packages/python-<package>
bash build.sh
```

---

## Method 3: Using buildutilscripts for Custom Builds

For packages that don't fit the standard pattern, use utility scripts directly:

```bash
# Source utilities
source buildutilscripts/setup_android_env.sh
source buildutilscripts/setup_ndk_toolchain.sh
source buildutilscripts/setup_android_compiler_flags.sh

# Setup environment
setup_android_sdk_ndk
setup_termux_build_env
setup_ndk_toolchain
setup_android_compiler_flags

# Build wheel
python3 -m pip wheel package-name --wheel-dir ~/wheels
```

---

## Key Principles

### 1. **Use Termux build system when possible**
   - Most stable and proven
   - Handles dependencies automatically
   - Consistent with official packages

### 2. **Follow Termux build.sh conventions**
   - Use `termux_step_*` functions
   - Set `TERMUX_PKG_*` variables
   - Handle cross-compilation properly

### 3. **Dependency management**
   - Build dependencies in order: numpy → scipy → scikit-learn
   - Use wheels when available: check `WHEELS_DIR` first
   - Install from source only when needed

### 4. **Cross-compilation considerations**
   - Use NDK toolchain (not host compiler)
   - Set proper compiler flags for Android
   - Handle stub libraries for Rust packages
   - Use meson cross files for meson-based builds

### 5. **Wheel extraction**
   - Wheels are built in `dist/` directory
   - Extract to `WHEELS_DIR` for reuse
   - Use `copy_wheel_to_output.sh` utility

---

## Comparison of Methods

| Method | Stability | Complexity | Dependency Handling | Recommended For |
|--------|-----------|------------|---------------------|-----------------|
| **build-package.sh** | ⭐⭐⭐⭐⭐ | Low | Automatic | Production builds |
| **Standalone build.sh** | ⭐⭐⭐⭐ | Medium | Manual | Custom packages |
| **Direct utility scripts** | ⭐⭐⭐ | High | Manual | One-off builds |

---

## Best Practices

1. **Always use `build-package.sh` for official Termux packages**
2. **Check for existing wheels before building**
3. **Build dependencies in correct order**
4. **Use `--no-build-isolation` when dependencies are already installed**
5. **Use `--find-links` to point to wheels directory**
6. **Test wheels on actual Android device before distribution**

---

## Example: Building Scientific Stack

```bash
# Method 1: Using build-package.sh (Recommended)
cd termux-packages
export TERMUX_ARCH=x86_64
export TERMUX_PYTHON_VERSION=3.12
./build-package.sh python-numpy python-scipy python-scikit-learn

# Method 2: Using workflow script
./build_scientific_stack.sh

# Method 3: Manual with utilities
source buildutilscripts/setup_android_env.sh
setup_android_sdk_ndk
# ... build each package in order
```

---

## Troubleshooting

### Issue: "Cannot find cross-compilation Python"
**Solution:** Ensure `TERMUX_PYTHON_VERSION` is set and cross-compilation Python is built

### Issue: "Missing libraries during linking"
**Solution:** Use `create_stub_libs.sh` for Rust packages (orjson, pydantic-core)

### Issue: "Meson cross-compilation fails"
**Solution:** Ensure `create_meson_cross_file.sh` is called and `MESON_CROSS_FILE` is set

### Issue: "Dependencies not found"
**Solution:** Build dependencies first, or use `--find-links` to point to wheels directory

---

## Conclusion

**The most stable method is Method 1: Using `build-package.sh`** because it:
- Uses proven Termux infrastructure
- Handles all edge cases automatically
- Ensures consistency with official packages
- Requires minimal manual configuration

For custom packages or one-off builds, use Method 2 (standalone build.sh) or Method 3 (direct utilities) as needed.


