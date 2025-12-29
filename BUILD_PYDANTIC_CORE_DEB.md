# Building pydantic-core .deb Package for Termux

Yes, it's definitely possible to build a `.deb` package for `pydantic_core`! This guide shows you how.

## Overview

`pydantic_core` is a Rust-based Python package that provides core validation logic for pydantic. Building it as a `.deb` allows it to be installed via Termux's package manager.

## Prerequisites

1. **Termux build environment** set up
2. **Rust toolchain** installed
3. **maturin** (Rust-Python build tool)
4. **Python build tools** (build, wheel, setuptools)

## Package Structure

The package is located at:
```
termux-packages/packages/python-pydantic-core/
└── build.sh
```

## Build Process

### Step 1: Install Build Dependencies

```bash
# In Termux
pkg install rust python python-pip
pip install maturin build wheel setuptools
```

### Step 2: Build the Package

```bash
cd termux-packages
./build-package.sh python-pydantic-core
```

### Step 3: Install the .deb

The built `.deb` file will be in `termux-packages/output/`:

```bash
dpkg -i output/python-pydantic-core_*.deb
```

## How It Works

1. **termux_step_pre_configure**: Sets up Rust and ensures maturin is available
2. **termux_step_make**: Builds the wheel using `python -m build` (which uses maturin under the hood)
3. **termux_step_make_install**: Installs the built wheel into `$TERMUX_PREFIX`
4. **termux_step_create_debscripts**: Creates post-install script (optional)

## Key Features

- **Rust compilation**: Uses maturin to compile Rust code for the target architecture
- **Wheel-based**: Builds a wheel first, then installs it (standard Python package approach)
- **Architecture-specific**: Builds for the specific Termux architecture (aarch64, arm, x86_64, etc.)
- **Dependency management**: Lists system dependencies (python, libc++)

## Customization

### Update Version

Edit `TERMUX_PKG_VERSION` in `build.sh`:

```bash
TERMUX_PKG_VERSION="2.33.2"  # Update to latest version
```

### Get SHA256 Hash

```bash
# Download the source and get hash
wget https://pypi.org/packages/source/p/pydantic-core/pydantic-core-2.33.2.tar.gz
sha256sum pydantic-core-2.33.2.tar.gz
# Update TERMUX_PKG_SHA256 in build.sh
```

## Troubleshooting

### Rust Not Found
```bash
termux_setup_rust  # This should be called automatically
```

### Maturin Not Found
```bash
pip install maturin
```

### Build Fails
- Check Rust version: `rustc --version`
- Ensure sufficient memory (Rust builds can be memory-intensive)
- Try building with fewer parallel jobs: `export CARGO_BUILD_JOBS=1`

### Wheel Not Found After Build
The script has fallback logic to find the wheel even if the exact name doesn't match.

## Alternative: Use Pre-built Wheel

If you already have a built wheel file:

```bash
# Copy wheel to Termux
adb push pydantic_core-*.whl /sdcard/Download/

# In Termux
pip install /sdcard/Download/pydantic_core-*.whl
```

However, building as `.deb` provides:
- System-level integration
- Version management via `pkg upgrade`
- Dependency tracking
- Easier distribution

## Comparison: .deb vs pip install

| Aspect | .deb Package | pip install |
|--------|-------------|-------------|
| **Installation** | `pkg install python-pydantic-core` | `pip install pydantic-core` |
| **Updates** | `pkg upgrade` | `pip install --upgrade` |
| **System Integration** | ✅ Better | ⚠️ Limited |
| **Dependency Management** | ✅ System-level | ⚠️ pip-level |
| **Build Complexity** | ⚠️ More complex | ✅ Simpler |

## Notes

- The package builds from source, so it requires Rust and compilation time
- For faster installation, consider using pre-built wheels if available
- The `.deb` approach is best for system-wide installation and distribution

