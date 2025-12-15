# Complete Pre-build System for droidrun[google] - User Guide

This guide explains how to build ALL dependencies for droidrun[google] on your Android device and create a bootstrap package for zero-compilation installation.

## Overview

The pre-build system consists of four phases:

1. **Dependency Discovery** - Find all transitive dependencies and check wheel availability
2. **Build on Device** - Build all dependencies as wheels on Android device
3. **Export & Package** - Collect all wheels into a single bootstrap archive
4. **Zero-Compilation Installation** - Install using only pre-built packages

## Prerequisites

### On Your Computer (Host)
- ADB installed and configured
- Android device connected via USB or emulator running
- Access to the droidrunBuild repository

### On Android Device (Termux)
- Termux app installed
- Python 3.12+ installed: `pkg install -y python python-pip`
- Build tools installed (see Phase 2 setup)

## Phase 1: Dependency Discovery

### Step 1.1: Run Discovery Script

On your computer, navigate to the droidrunBuild directory and run:

```bash
cd droidrunBuild/scripts
./discover-all-dependencies.sh "droidrun[google]" 3.12
```

This will:
- Download droidrun[google] and all dependencies
- Check PyPI for wheel availability (aarch64 and x86_64)
- Parse all transitive dependencies
- Generate `droidrunBuild/depedencies/dependency-manifest.json`

### Step 1.2: Review Manifest

Check the generated manifest:

```bash
cat droidrunBuild/depedencies/dependency-manifest.json | python3 -m json.tool | less
```

The manifest contains:
- All packages with versions and constraints
- Wheel availability per architecture
- Build requirements (system packages, Python packages)
- Build order
- Special fixes needed

## Phase 2: Build on Android Device

### Step 2.1: Setup Termux Environment

On your Android device (via ADB or Termux directly):

```bash
# Install all system build dependencies
pkg install -y \
  python python-pip \
  autoconf automake libtool make binutils \
  clang cmake ninja \
  rust \
  flang blas-openblas \
  libjpeg-turbo libpng libtiff libwebp freetype \
  libarrow-cpp

# Create gfortran symlink for scipy compatibility
ln -sf $PREFIX/bin/flang $PREFIX/bin/gfortran

# Upgrade pip and build tools
pip install --upgrade pip wheel build setuptools Cython "meson-python<0.19.0,>=0.16.0" "maturin<2,>=1.9.4"

# Set parallelism limits (prevents memory exhaustion)
export NINJAFLAGS="-j2"
export MAKEFLAGS="-j2"
export MAX_JOBS=2

# Create wheels directory
mkdir -p ~/wheels
```

### Step 2.2: Transfer Files to Device

From your computer:

```bash
# Transfer manifest
adb push droidrunBuild/depedencies/dependency-manifest.json /data/data/com.termux/files/home/

# Transfer build scripts
adb push droidrunBuild/scripts/build-all-dependencies.sh /data/data/com.termux/files/home/
adb push droidrunBuild/scripts/build-system-packages.sh /data/data/com.termux/files/home/
adb push droidrunBuild/scripts/export-bootstrap.sh /data/data/com.termux/files/home/

# Transfer utility scripts
adb push -r droidrunBuild/scripts/utils /data/data/com.termux/files/home/
```

### Step 2.3: Make Scripts Executable

On device (via ADB):

```bash
adb shell "run-as com.termux sh -c 'chmod +x ~/build-all-dependencies.sh ~/build-system-packages.sh ~/export-bootstrap.sh ~/utils/*.sh ~/utils/*.py'"
```

### Step 2.4: Build All Dependencies

On device (via ADB or Termux directly):

```bash
# Set environment variables
export PREFIX=/data/data/com.termux/files/usr
export HOME=/data/data/com.termux/files/home
export PATH=$PREFIX/bin:$PATH
export NINJAFLAGS="-j2"
export MAKEFLAGS="-j2"
export MAX_JOBS=2

# Run build script
cd ~
./build-all-dependencies.sh ~/dependency-manifest.json
```

**This will take 2-4 hours** depending on your device. The script will:
- Build packages in dependency order
- Apply all fixes automatically (pandas meson fix, scikit-learn version.py fix, etc.)
- Track build progress
- Generate build report

### Step 2.5: Monitor Progress

You can check progress at any time:

```bash
# Via ADB
adb shell "run-as com.termux sh -c '~/utils/build-status.sh progress ~/dependency-manifest.json'"

# Or view build log
adb shell "run-as com.termux sh -c 'tail -f ~/wheels/build-all.log'"
```

### Step 2.6: Check System Packages (Optional)

Most system packages exist in Termux, but check if any need building:

```bash
./build-system-packages.sh ~/dependency-manifest.json
```

## Phase 3: Export & Package

### Step 3.1: Export Bootstrap

On device:

```bash
./export-bootstrap.sh ~/dependency-manifest.json
```

This creates:
- `~/droidrun-bootstrap/` - Bootstrap directory with all wheels organized by architecture
- `~/droidrun-bootstrap-YYYYMMDD-HHMMSS.tar.gz` - Single archive file

### Step 3.2: Pull Archive to Computer

From your computer:

```bash
# Pull the archive
adb pull /data/data/com.termux/files/home/droidrun-bootstrap-*.tar.gz ./

# Verify archive
tar -tzf droidrun-bootstrap-*.tar.gz | head -20
```

## Phase 4: Zero-Compilation Installation

### Step 4.1: Transfer Bootstrap to Target Device

```bash
# Transfer archive to target device
adb push droidrun-bootstrap-*.tar.gz /sdcard/Download/
```

### Step 4.2: Extract and Install

On target device (Termux):

```bash
# Extract archive
cd ~
cp /sdcard/Download/droidrun-bootstrap-*.tar.gz .
tar -xzf droidrun-bootstrap-*.tar.gz
cd droidrun-bootstrap

# Run installation script
./scripts/install.sh
```

The installation script will:
- Auto-detect architecture (aarch64 or x86_64)
- Install all pre-built wheels in dependency order
- Install droidrun[google] using pre-built dependencies
- **No compilation required** - everything is pre-built

### Step 4.3: Verify Installation

```bash
python3 -c "import droidrun; print('droidrun installed successfully')"
python3 -c "import numpy, scipy, pandas, sklearn; print('All dependencies working')"
```

## Troubleshooting

### Build Fails for a Package

1. Check build log: `cat ~/wheels/build-all.log | grep -A 20 "ERROR"`
2. Check if all system dependencies are installed
3. Retry specific package: Reset status and rebuild
   ```bash
   ~/utils/build-status.sh reset <package-name>
   # Then manually build that package
   ```

### Missing Wheels During Installation

- Ensure you built for the correct architecture
- Check that export script copied all wheels
- Verify manifest includes all dependencies

### Memory Issues During Build

- Ensure `NINJAFLAGS="-j2"` and `MAKEFLAGS="-j2"` are set
- Build one package at a time if needed
- Restart Termux if system becomes unresponsive

### Installation Fails

- Check architecture detection: `uname -m`
- Verify wheels exist for your architecture
- Check pip version: `pip --version` (should be recent)

## Advanced Usage

### Resume Failed Build

If build is interrupted, you can resume:

```bash
# Check what's built
~/utils/build-status.sh progress ~/dependency-manifest.json

# Reset failed packages
~/utils/build-status.sh reset <failed-package>

# Re-run build (will skip already-built packages)
./build-all-dependencies.sh ~/dependency-manifest.json
```

### Build for Specific Architecture Only

Modify the build script to filter by architecture, or build on device with matching architecture.

### Custom System Packages

If you need to build custom system packages, edit `build-system-packages.sh` to add build logic for specific packages.

## File Locations

### On Device
- Wheels: `~/wheels/*.whl`
- Build log: `~/wheels/build-all.log`
- Build status: `~/wheels/build-status.json`
- Build report: `~/wheels/build-report.json`
- Bootstrap: `~/droidrun-bootstrap/`
- Archive: `~/droidrun-bootstrap-*.tar.gz`

### On Computer
- Manifest: `droidrunBuild/depedencies/dependency-manifest.json`
- Scripts: `droidrunBuild/scripts/`
- Utilities: `droidrunBuild/scripts/utils/`

## Special Fixes Applied Automatically

The build script automatically applies these fixes:

1. **Pandas meson.build** - Hardcodes version to avoid script execution issues
2. **Scikit-learn version.py** - Fixes permissions and adds shebang
3. **grpcio** - Uses `--no-build-isolation` to make Cython available
4. **PyArrow** - Matches version with installed Arrow C++ library
5. **Pillow** - Ensures image libraries are installed

## Success Criteria

After completing all phases:

- ✅ All dependencies built as wheels
- ✅ Single archive contains everything
- ✅ Installation completes without compilation
- ✅ Works on both aarch64 and x86_64
- ✅ All version constraints satisfied
- ✅ No missing dependencies

## Next Steps

Once you have the bootstrap archive:

1. **Share the archive** - Upload to GitHub Releases or file sharing service
2. **Document versions** - Note which versions are included
3. **Test on clean device** - Verify installation works on fresh Termux install
4. **Update as needed** - Rebuild when dependencies update

## Support

For issues:
- Check `termux-build-errors-and-solutions.md` for known fixes
- Review build logs for specific errors
- Verify all prerequisites are installed
- Check Termux and Python versions match requirements

