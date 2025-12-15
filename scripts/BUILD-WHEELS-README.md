# Automated Wheel Builder Script

## Overview

`build-all-wheels-automated.sh` is a comprehensive script that automatically builds all `.whl` files required for droidrun on any architecture. It handles dependency resolution, applies all necessary fixes, and exports wheels to a separate folder.

## Features

- ✅ **Auto-detects architecture** (aarch64, x86_64)
- ✅ **Checks for existing wheels** before building
- ✅ **Builds transitive dependencies first** automatically
- ✅ **Uses source files from `sources/` folder** (no downloads)
- ✅ **Applies all fixes and patches** automatically:
  - pandas meson.build fix
  - scikit-learn version.py fix
  - grpcio wheel patching (abseil libraries)
- ✅ **Installs dependencies in sequence** before building
- ✅ **Exports all wheels** to `wheels_export/{arch}/`
- ✅ **Creates manifest** of all built wheels
- ✅ **Comprehensive logging** to `build-all-wheels.log`

## Directory Structure

```
project_root/
├── sources/              # Source files (.tar.gz, .zip) - REQUIRED
│   ├── numpy-*.tar.gz
│   ├── scipy-*.tar.gz
│   ├── pandas-*.tar.gz
│   └── ...
├── wheels/              # Build directory (created automatically)
│   └── *.whl
└── wheels_export/       # Export directory (created automatically)
    ├── aarch64/
    │   └── *.whl
    └── x86_64/
        └── *.whl
```

## Prerequisites

### 1. System Dependencies

Install all required system packages:

```bash
pkg install -y \
  python python-pip \
  autoconf automake libtool make binutils \
  clang cmake ninja \
  rust \
  flang blas-openblas \
  libjpeg-turbo libpng libtiff libwebp freetype \
  libarrow-cpp \
  openssl libc++ zlib \
  protobuf libprotobuf \
  abseil-cpp c-ares libre2 \
  patchelf
```

### 2. Source Files

Place all source files (`.tar.gz` or `.zip`) in the `sources/` folder:

```bash
# Example: Copy sources to the sources directory
mkdir -p sources
cp /path/to/sources/*.tar.gz sources/
cp /path/to/sources/*.zip sources/
```

**Required source files:**
- numpy (any version >= 1.26.0)
- scipy (version >= 1.8.0, < 1.17.0)
- pandas (version < 2.3.0, e.g., 2.2.3)
- scikit-learn (any version >= 1.0.0)
- jiter (version 0.12.0)
- pyarrow (any version)
- psutil (any version)
- grpcio (any version)
- pillow (any version)
- tokenizers, safetensors, cryptography, pydantic-core, orjson (optional)

**Note:** The script will look for source files with various naming patterns:
- `package-version.tar.gz`
- `package-version-fixed.tar.gz`
- `package_version.tar.gz`

## Usage

### Basic Usage

```bash
cd scripts
./build-all-wheels-automated.sh
```

### Custom Directories

You can override default directories using environment variables:

```bash
SOURCES_DIR=/path/to/sources \
WHEELS_DIR=/path/to/wheels \
EXPORT_DIR=/path/to/export \
./build-all-wheels-automated.sh
```

### From ADB (Windows/Linux)

```bash
# Push script to device
adb push scripts/build-all-wheels-automated.sh /data/local/tmp/

# Push sources (if needed)
adb push sources/ /sdcard/sources/

# Run script
adb shell "run-as com.termux sh -c '
  export PREFIX=/data/data/com.termux/files/usr
  export HOME=/data/data/com.termux/files/home
  export PATH=\$PREFIX/bin:\$PATH
  cp /data/local/tmp/build-all-wheels-automated.sh \$HOME/
  chmod +x \$HOME/build-all-wheels-automated.sh
  cd \$HOME
  SOURCES_DIR=/sdcard/sources ./build-all-wheels-automated.sh
'"
```

## How It Works

### 1. Architecture Detection

The script automatically detects the architecture:
- `aarch64` or `arm64` → `linux_aarch64`
- `x86_64` or `amd64` → `linux_x86_64`

### 2. Dependency Resolution

For each package, the script:
1. Checks if a wheel already exists for this architecture
2. If not, gets transitive dependencies
3. Builds dependencies first (recursively)
4. Then builds the main package

### 3. Build Process

For each package:
1. **Find source file** in `sources/` directory
2. **Install system dependencies** (if needed)
3. **Extract source** to temporary directory
4. **Apply fixes** (pandas, scikit-learn, etc.)
5. **Repackage** if fixes were applied
6. **Build wheel** using `pip wheel`
7. **Apply post-build fixes** (grpcio patching)
8. **Install wheel** for use by dependent packages

### 4. Fixes Applied Automatically

#### pandas
- Fixes `meson.build` line 5: replaces `run_command` with hardcoded version `'2.2.3'`

#### scikit-learn
- Adds shebang to `version.py`
- Hardcodes version in `meson.build` line 4
- Uses `--no-build-isolation` flag

#### grpcio
- Sets GRPC build environment variables
- Patches wheel after build to add abseil library dependencies
- Sets RPATH for shared libraries

### 5. Export

After building all wheels:
- Copies all wheels to `wheels_export/{arch}/`
- Creates `wheel-manifest.txt` with list of all wheels
- Logs total count

## Build Order

The script builds packages in the correct order:

1. **Phase 1:** Build tools (Cython, meson-python, maturin)
2. **Phase 2:** Foundation (numpy)
3. **Phase 3:** Scientific stack (scipy, pandas, scikit-learn)
4. **Phase 4:** Rust packages (jiter)
5. **Phase 5:** Other compiled (pyarrow, psutil, grpcio, pillow)
6. **Phase 6:** Optional compiled (tokenizers, safetensors, etc.)

## Output

### Log File

All build activity is logged to:
```
wheels/build-all-wheels.log
```

### Export Directory

All built wheels are copied to:
```
wheels_export/{arch}/
```

### Manifest File

A manifest is created at:
```
wheels_export/{arch}/wheel-manifest.txt
```

Example manifest:
```
# Wheel Manifest for x86_64
# Generated: 2024-12-15 10:30:00
# Python: 3.12
# Platform: linux_x86_64

## Built Wheels:
  - numpy-2.3.5-cp312-cp312-linux_x86_64.whl
  - scipy-1.16.3-cp312-cp312-linux_x86_64.whl
  - pandas-2.2.3-cp312-cp312-linux_x86_64.whl
  ...

## Total Wheels: 15
```

## Troubleshooting

### Source File Not Found

**Error:** `Source file not found for package-name in sources/`

**Solution:** 
- Check that source file exists in `sources/` directory
- Verify naming matches expected patterns
- Check file permissions

### Build Fails

**Error:** Build fails for a specific package

**Solution:**
- Check build log: `wheels/build-all-wheels.log`
- Verify system dependencies are installed
- Check that dependencies are built first
- Ensure sufficient disk space and memory

### Wheel Already Exists

**Message:** `Wheel for package-name already exists, skipping build`

**Solution:** This is normal - the script skips packages that already have wheels. To force rebuild, delete the existing wheel.

### Architecture Mismatch

**Error:** `Unsupported architecture: ...`

**Solution:** The script currently supports:
- `aarch64` / `arm64`
- `x86_64` / `amd64`

For other architectures, modify the architecture detection section.

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `SOURCES_DIR` | `$PROJECT_ROOT/sources` | Directory containing source files |
| `WHEELS_DIR` | `$HOME/wheels` | Directory for building wheels |
| `EXPORT_DIR` | `$PROJECT_ROOT/wheels_export/{arch}` | Directory for exported wheels |
| `BUILD_LOG` | `$WHEELS_DIR/build-all-wheels.log` | Log file path |
| `PREFIX` | `/data/data/com.termux/files/usr` | Termux prefix |

## Notes

- The script uses `--no-deps` flag to avoid downloading dependencies
- All source files must be pre-downloaded to `sources/` folder
- The script installs wheels after building to satisfy dependencies
- Parallelism is limited to 2 jobs (`-j2`) to prevent memory issues
- All fixes from `DEPENDENCIES.md` are applied automatically

## Example Workflow

```bash
# 1. Prepare sources
mkdir -p sources
# Copy all .tar.gz and .zip files to sources/

# 2. Install system dependencies
pkg install -y python python-pip autoconf automake libtool make binutils clang cmake ninja rust flang blas-openblas libjpeg-turbo libpng libtiff libwebp freetype libarrow-cpp openssl libc++ zlib protobuf libprotobuf abseil-cpp c-ares libre2 patchelf

# 3. Run script
cd scripts
./build-all-wheels-automated.sh

# 4. Check results
ls -lh ../wheels_export/*/
cat ../wheels_export/*/wheel-manifest.txt
```

## Support

For issues or questions:
1. Check the build log: `wheels/build-all-wheels.log`
2. Review `DEPENDENCIES.md` for package-specific requirements
3. Check `docs/termux-build-errors-and-solutions.md` for common issues


