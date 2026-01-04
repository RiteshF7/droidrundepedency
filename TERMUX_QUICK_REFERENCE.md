# Termux Python Cross-Compilation Quick Reference

## Quick Start Commands

### Build a Python Package for Specific Architecture
```bash
# For aarch64 (ARM 64-bit)
./build-package.sh -a aarch64 python-numpy

# For arm (ARM 32-bit)
./build-package.sh -a arm python-numpy

# For x86_64
./build-package.sh -a x86_64 python-numpy

# For i686 (x86 32-bit)
./build-package.sh -a i686 python-numpy

# For all architectures
./build-package.sh -a all python-numpy
```

### Force Rebuild
```bash
./build-package.sh -f -a aarch64 python-numpy
```

### Build with Debug Symbols
```bash
./build-package.sh -d -a aarch64 python-numpy
```

## Key Environment Variables

```bash
# Architecture (set via -a flag)
TERMUX_ARCH=aarch64|arm|i686|x86_64

# Python version
TERMUX_PYTHON_VERSION=3.12

# Crossenv location
TERMUX_PYTHON_CROSSENV_PREFIX=~/.termux-build/python3.12-crossenv-prefix-bionic-aarch64

# Target prefix
TERMUX_PREFIX=/data/data/com.termux/files/usr

# Toolchain
TERMUX_STANDALONE_TOOLCHAIN=~/.termux-build/_cache/android-r28c-api-24
```

## Standard Python Package Build Template

```bash
TERMUX_PKG_HOMEPAGE=https://example.com
TERMUX_PKG_DESCRIPTION="Package description"
TERMUX_PKG_LICENSE="MIT"
TERMUX_PKG_MAINTAINER="@termux"
TERMUX_PKG_VERSION="1.0.0"
TERMUX_PKG_SRCURL=https://files.pythonhosted.org/packages/source/p/package/package-${TERMUX_PKG_VERSION}.tar.gz
TERMUX_PKG_SHA256="..."
TERMUX_PKG_DEPENDS="python"
TERMUX_PKG_PYTHON_COMMON_DEPS="wheel, build"

termux_step_make() {
    python -m build -w -n -x .
}

termux_step_make_install() {
    local _pyv="${TERMUX_PYTHON_VERSION//./}"
    local _arch="$TERMUX_ARCH"
    case "$TERMUX_ARCH" in
        arm) _arch="armv7" ;;
    esac
    local _whl="package-${TERMUX_PKG_VERSION}-cp${_pyv}-cp${_pyv}-linux_${_arch}.whl"
    pip install --no-deps --prefix=$TERMUX_PREFIX --force-reinstall $TERMUX_PKG_SRCDIR/dist/$_whl
}
```

## Rust-Based Package Template

```bash
TERMUX_PKG_PYTHON_COMMON_DEPS="maturin, build, wheel, setuptools"
TERMUX_PKG_BUILD_DEPENDS="rust"

termux_step_pre_configure() {
    termux_setup_rust
}

termux_step_make() {
    maturin build --release --target "$CARGO_TARGET_NAME" \
        --out dist --interpreter "python${TERMUX_PYTHON_VERSION}" \
        --skip-auditwheel
}
```

## Meson-Based Package Template

```bash
TERMUX_PKG_PYTHON_COMMON_DEPS="wheel, 'Cython>=0.29.34', 'meson-python>=0.15.0', build"
TERMUX_MESON_WHEEL_CROSSFILE="$TERMUX_PKG_TMPDIR/wheel-cross-file.txt"

termux_step_configure() {
    termux_setup_meson
    cp -f $TERMUX_MESON_CROSSFILE $TERMUX_MESON_WHEEL_CROSSFILE
    # Add Python-specific config
    sed -i 's|^\(\[binaries\]\)$|\1\npython = '\'$(command -v python)\''|g' \
        $TERMUX_MESON_WHEEL_CROSSFILE
}

termux_step_make() {
    python -m build -w -n -x --config-setting builddir=$TERMUX_PKG_BUILDDIR .
}
```

## Wheel Naming Convention

```
{package}-{version}-cp{pyver}-cp{pyver}-linux_{arch}.whl
```

### Architecture Mapping
- `aarch64` → `linux_aarch64`
- `arm` → `linux_armv7` or `linux_arm`
- `i686` → `linux_i686`
- `x86_64` → `linux_x86_64`

### Python Version
- `3.12` → `cp312`
- `3.11` → `cp311`

## Python Dependency Types

```bash
# Common: installed in both build and cross environments
TERMUX_PKG_PYTHON_COMMON_DEPS="wheel, build"

# Build: only for host (build tools)
TERMUX_PKG_PYTHON_BUILD_DEPS="cython, setuptools"

# Target: only for Android (runtime)
TERMUX_PKG_PYTHON_TARGET_DEPS="numpy"
```

## Crossenv Commands

```bash
# Activate crossenv (done automatically by termux_setup_python_pip)
. "${TERMUX_PYTHON_CROSSENV_PREFIX}/bin/activate"

# Install in build environment (host)
build-pip install package

# Install in cross environment (target)
cross-pip install package

# Use build Python
build-python script.py

# Use cross Python
cross-python script.py
```

## Toolchain Compilers

```bash
# Architecture-specific compilers
aarch64-linux-android24-clang
armv7a-linux-androideabi24-clang
i686-linux-android24-clang
x86_64-linux-android24-clang
```

## Common Build Issues

### Issue: Wheel not found after build
**Solution**: Check `$TERMUX_PKG_SRCDIR/dist/` for generated wheel

### Issue: Wrong architecture in wheel name
**Solution**: Verify `TERMUX_ARCH` and wheel naming logic

### Issue: Missing dependencies
**Solution**: Add to `TERMUX_PKG_PYTHON_COMMON_DEPS` or appropriate deps variable

### Issue: Rust linking errors
**Solution**: Ensure `CARGO_TARGET_NAME` is set correctly, check stub libraries

### Issue: Crossenv not found
**Solution**: Run `termux_setup_python_pip` which creates crossenv automatically

## File Locations

- **Build scripts**: `packages/{package}/build.sh`
- **Output packages**: `output/` or `-o` specified directory
- **Wheels (temp)**: `$TERMUX_PKG_SRCDIR/dist/`
- **Crossenv**: `~/.termux-build/python{VERSION}-crossenv-prefix-{LIBRARY}-{ARCH}/`
- **Toolchain**: `~/.termux-build/_cache/android-r{NDK}-api-{API}/`
- **Source cache**: `~/.termux-build/{package}/cache/`

## Useful Scripts

```bash
# Setup Ubuntu build environment
./scripts/setup-ubuntu.sh

# Setup Termux on-device environment
./scripts/setup-termux.sh

# Setup CGCT (for glibc packages)
./scripts/setup-cgct.sh
```

## Build Process Checklist

- [ ] Set `TERMUX_PKG_SETUP_PYTHON=true` (auto if deps specified)
- [ ] Add Python dependencies to appropriate `*_DEPS` variable
- [ ] Implement `termux_step_make()` to build wheel
- [ ] Implement `termux_step_make_install()` to install wheel
- [ ] Test with `-a aarch64` first (most common)
- [ ] Verify wheel naming matches PEP 425
- [ ] Check wheel installs correctly on target

