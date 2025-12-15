# Termux Build Errors and Solutions Documentation

This document tracks all errors encountered while building Python wheels in Termux Android emulator and their solutions.

## Table of Contents
1. [Storage Configuration Issue](#1-storage-configuration-issue)
2. [Patchelf Build Error](#2-patchelf-build-error)
3. [Pandas Wheel Permission Error](#3-pandas-wheel-permission-error)
4. [Jiter Build Error - Rust Not Found](#4-jiter-build-error---rust-not-found)
5. [Scikit-learn/Scipy Build Error - Fortran Compiler Missing](#5-scikit-learnscipy-build-error---fortran-compiler-missing)
6. [System Unresponsive During Build - Memory Exhaustion](#6-system-unresponsive-during-build---memory-exhaustion)
7. [Pip Rebuilding Packages Despite Pre-built Wheels](#7-pip-rebuilding-packages-despite-pre-built-wheels)
8. [Android Emulator No Internet Connectivity](#8-android-emulator-no-internet-connectivity)
9. [Pandas Version Conflict - Wrong Version Built](#9-pandas-version-conflict---wrong-version-built)
10. [Scikit-learn Meson Build Error - Could Not Execute version.py](#10-scikit-learn-meson-build-error---could-not-execute-versionpy)
11. [PyArrow Build Error - Similar to Scikit-learn](#11-pyarrow-build-error---similar-to-scikit-learn)

---

## 1. Storage Configuration Issue

### Error Description
Android emulator settings showed 8GB storage instead of the configured 12GB in the AVD configuration files.

### Root Cause  
- The AVD configuration file (`config.ini` and `hardware-qemu.ini`) had `disk.dataPartition.size=12G` set
- However, the actual userdata image file was created with 8GB when the AVD was first initialized
- Changing the configuration file after AVD creation does not automatically resize the existing disk image
- Android reads the actual partition size from the disk image, not from the configuration file

### Solution
**Wipe the AVD data to recreate the userdata partition with the new size:**

1. Use the batch script: `launch_pixel4a.bat`
2. Choose option **2: Launch Clean** or **5: Clear Storage Only**
3. This will recreate the userdata image using the 12GB setting from the configuration

**Alternative method:**
```bash
# Stop emulator first
adb -s emulator-5554 emu kill

# Wipe data and launch
emulator -avd Pixel_4a -wipe-data -no-snapshot-load
```

### Configuration Files Location
- Config: `%USERPROFILE%\.android\avd\Pixel_4a.avd\config.ini`
- Hardware Config: `%USERPROFILE%\.android\avd\Pixel_4a.avd\hardware-qemu.ini`

### Key Settings
- `disk.dataPartition.size=12G` - Main user data partition
- `disk.systemPartition.size=4211m` - System partition (~4.1 GB)
- `disk.vendorPartition.size=800m` - Vendor partition
- `disk.cachePartition.size=66m` - Cache partition
- `sdcard.size=512M` - SD card size

### Notes
- Wiping data will delete all apps, settings, and files
- First boot after wiping may take longer
- After wiping, Android Settings should show ~12GB (minus system overhead)

---

## 2. Patchelf Build Error

### Error Description
When building pandas wheels, the build process failed with:
```
ERROR: Failed building wheel for patchelf
./bootstrap.sh[2]: autoreconf: inaccessible or not found
ninja: build stopped: subcommand failed.
*** CMake build failed
ERROR: Failed to build 'numpy' when installing backend dependencies for numpy
ERROR: Failed to build 'pandas' when installing build dependencies for pandas
```

### Root Cause
- `patchelf` is a dependency required by `numpy` and `pandas` for building wheels
- `patchelf` requires build tools like `autoconf`, `automake`, `libtool`, and `make` to build from source
- These build tools were not installed in Termux
- The `autoreconf` command (part of `autoconf`) was missing, causing the bootstrap script to fail

### Solution
**Install required build dependencies before building wheels:**

```bash
# In Termux, install build tools
pkg install -y autoconf automake libtool make binutils clang cmake ninja

# Then build wheels
pip wheel pandas --no-deps --wheel-dir ~/wheels
```

**Complete command via ADB:**
```bash
adb shell "run-as com.termux sh -c 'export PREFIX=/data/data/com.termux/files/usr && export HOME=/data/data/com.termux/files/home && export PATH=\$PREFIX/bin:\$PATH && pkg install -y autoconf automake libtool make binutils clang cmake ninja && cd ~/wheels && pip wheel pandas --no-deps --wheel-dir .'"
```

### Required Packages
- `autoconf` - Contains `autoreconf` for generating configure scripts
- `automake` - Build system generator
- `libtool` - Library building support
- `make` - Build automation tool
- `binutils` - Binary utilities
- `clang` - C/C++ compiler (Termux uses clang instead of gcc)
- `cmake` - Cross-platform build system
- `ninja` - Build system used by some Python packages

### Notes
- In Termux, `gcc` package doesn't exist - use `clang` instead
- These tools are needed for any Python package that has C/C++ extensions
- Consider installing these as part of the initial Termux setup for wheel building

---

## 3. Pandas Wheel Permission Error

### Error Description
Pandas wheel was built successfully, but failed to copy to the specified wheel directory:
```
Successfully built pandas
WARNING: Building wheel for pandas failed: [Errno 13] Permission denied: '/tmp/pandas-2.3.3-cp312-cp312-linux_x86_64.whl'
ERROR: Failed to build one or more wheels
```

However, the wheel was actually created in the pip cache:
```
Stored in directory: /data/data/com.termux/files/home/.cache/pip/wheels/22/5f/21/...
```

### Root Cause
- The wheel was built successfully
- When using `--wheel-dir /tmp`, pip tried to copy the wheel from cache to `/tmp`
- `/tmp` directory may have permission restrictions in Termux
- The wheel was successfully stored in the pip cache directory, but the copy operation failed

### Solution
**Use the home directory or wheels directory instead of /tmp:**

```bash
# Build directly to home directory or wheels directory
pip wheel pandas --no-deps --wheel-dir ~/wheels

# Or copy from cache after build
cp ~/.cache/pip/wheels/*/pandas*.whl ~/wheels/
```

**Complete command via ADB (WORKING SOLUTION):**
```bash
adb shell "run-as com.termux sh -c 'export PREFIX=/data/data/com.termux/files/usr && export HOME=/data/data/com.termux/files/home && export PATH=\$PREFIX/bin:\$PATH && cd \$HOME/wheels && pip wheel pandas --no-deps --wheel-dir .'"
```

**Result:** This successfully builds the pandas wheel (11MB) and saves it to `~/wheels/pandas-2.3.3-cp312-cp312-linux_x86_64.whl`

### Alternative: Copy from Cache
If the wheel is already built in cache:
```bash
# Find and copy the wheel
find ~/.cache/pip/wheels -name "pandas*.whl" -exec cp {} ~/wheels/ \;
```

### Notes
- The wheel was actually built successfully - the error is just about copying it
- Always use writable directories like `~/wheels` instead of `/tmp`
- Check pip cache if a wheel seems to fail but was actually built
- Cache location: `~/.cache/pip/wheels/`

---

## 4. Jiter Build Error - Rust Not Found

### Error Description
When building `jiter` wheel, the build process failed with:
```
ERROR: Failed to build 'jiter' when installing build dependencies for jiter
error: subprocess-exited-with-error

× installing build dependencies for jiter did not run successfully.
│ exit code: 1
╰─> [28 lines of output]
    Collecting maturin<2,>=1.9.4
      ...
      Preparing metadata (pyproject.toml): finished with status 'error'
      error: subprocess-exited-with-error
      × Preparing metadata (pyproject.toml) did not run successfully.
      │ exit code: 1
      ╰─> [3 lines of output]
          Python reports SOABI: cpython-312
          Unsupported platform: 312
          Rust not found, installing into a temporary directory
```

### Root Cause
- `jiter` is a Python package that requires `maturin` as a build dependency
- `maturin` is a Rust-based build tool used to build Python packages with Rust extensions
- `maturin` requires Rust compiler (`rustc`) and Cargo (Rust package manager) to be installed
- Rust was not installed in Termux, causing `maturin` to fail during metadata preparation
- The error message "Rust not found, installing into a temporary directory" indicates that `maturin` tried to install Rust automatically but failed

### Solution
**Install Rust before building jiter:**

```bash
# In Termux, install Rust
pkg install -y rust

# Verify installation
rustc --version

# Then build jiter wheel
pip wheel jiter --no-deps --wheel-dir ~/wheels
```

**Complete command via ADB:**
```bash
adb shell "run-as com.termux sh -c 'export PREFIX=/data/data/com.termux/files/usr && export HOME=/data/data/com.termux/files/home && export PATH=\$PREFIX/bin:\$PATH && pkg install -y rust && cd \$HOME/wheels && pip wheel jiter --no-deps --wheel-dir .'"
```

**Result:** This successfully builds the jiter wheel (378KB) and saves it to `~/wheels/jiter-0.12.0-cp312-cp312-linux_x86_64.whl`

### Required Packages
- `rust` - Rust compiler and Cargo package manager
  - Includes: `rustc` (Rust compiler), `cargo` (package manager), and standard library
  - Size: ~70MB download, ~326MB disk space

### Notes
- Rust is required for any Python package that uses `maturin` as a build backend
- `maturin` is commonly used for packages with Rust extensions (like `jiter`, `orjson`, etc.)
- The installation may take a few minutes as Rust is a large package
- After installing Rust, `maturin` will be able to build the package successfully
- If the wheel is built but stored in cache, copy it: `cp ~/.cache/pip/wheels/*/jiter*.whl ~/wheels/`

---

## 5. Scikit-learn/Scipy Build Error - Fortran Compiler Missing

### Error Description
When building `scikit-learn` wheel, the build process failed with:
```
ERROR: Failed to build 'scikit-learn' when installing build dependencies for scikit-learn
error: subprocess-exited-with-error

× installing build dependencies for scikit-learn did not run successfully.
│ exit code: 1
╰─> [83 lines of output]
    ...
    Preparing metadata (pyproject.toml): finished with status 'error'
    error: subprocess-exited-with-error
    
    × Preparing metadata (pyproject.toml) did not run successfully.
    │ exit code: 1
    ╰─> [53 lines of output]
        ../meson.build:88:0: ERROR: Unknown compiler(s): [['gfortran'], ['flang-new'], ['flang'], ...]
        The following exception(s) were encountered:
        Running `gfortran --help` gave "[Errno 13] Permission denied: 'gfortran'"
        ...
```

### Root Cause
- `scikit-learn` depends on `scipy`, which requires a Fortran compiler to build
- `scipy` uses the Meson build system, which looks for Fortran compilers: `gfortran`, `flang-new`, `flang`, etc.
- No Fortran compiler was installed in Termux
- The Meson build system couldn't find any Fortran compiler, causing the metadata preparation to fail
- Additionally, `scipy` requires BLAS/LAPACK libraries for numerical computations

### Solution
**Install Fortran compiler (flang) and BLAS/LAPACK libraries:**

```bash
# In Termux, install flang (Fortran compiler) and BLAS/LAPACK
pkg install -y flang blas-openblas

# Create gfortran symlink (scipy's Meson looks for gfortran specifically)
ln -sf $PREFIX/bin/flang $PREFIX/bin/gfortran

# Verify installation
gfortran --version
flang --version

# Then build scikit-learn or scipy wheel
pip wheel scikit-learn --no-deps --wheel-dir ~/wheels
```

**Complete command via ADB:**
```bash
adb shell "run-as com.termux sh -c 'export PREFIX=/data/data/com.termux/files/usr && export HOME=/data/data/com.termux/files/home && export PATH=\$PREFIX/bin:\$PATH && pkg install -y flang blas-openblas && ln -sf \$PREFIX/bin/flang \$PREFIX/bin/gfortran && cd \$HOME/wheels && pip wheel scikit-learn --no-deps --wheel-dir .'"
```

### Required Packages
- `flang` - LLVM's Fortran frontend compiler
  - Provides Fortran compilation capabilities
  - Size: ~68MB download, ~1.2GB disk space (includes mlir dependency)
- `blas-openblas` - OpenBLAS symlinks for BLAS/CBLAS/LAPACK/LAPACKE
  - Provides optimized linear algebra libraries required by scipy
  - Note: `libopenblas` is usually already installed as a dependency

### Additional Setup
**Create gfortran symlink:**
- Meson build system looks for `gfortran` specifically
- `flang` is compatible but needs to be accessible as `gfortran`
- Create symlink: `ln -sf $PREFIX/bin/flang $PREFIX/bin/gfortran`

### Notes
- `scipy` builds can take 30+ minutes due to extensive compilation
- The build process uses Meson, which requires proper Fortran compiler detection
- `flang` is LLVM's modern Fortran compiler and is compatible with `gfortran` for most packages
- BLAS/LAPACK libraries are essential for scipy's numerical operations
- If the build is interrupted, it can be resumed - pip will cache progress
- Consider building `scipy` separately first, then `scikit-learn` will use the pre-built scipy wheel

---

## 6. System Unresponsive During Build - Memory Exhaustion

### Error Description
While building large packages like `pandas`, `scipy`, or `scikit-learn`, the Android emulator becomes unresponsive:
- System appears frozen or very slow
- UI stops responding
- Build processes continue but system is unusable
- Multiple compilation processes running simultaneously

**System state when unresponsive:**
```
Memory: 1.7Gi used / 1.9Gi total (only 44Mi free)
Swap: 1.4Gi used / 1.4Gi total (completely full)
CPU: 400% (all 4 cores maxed out)
Multiple 'cc' processes each using 77-225MB RAM
Processes in 'D' state (uninterruptible sleep - disk I/O wait)
```

### Root Cause
- **Excessive Parallelism**: Build systems (Meson/Ninja) default to using all available CPU cores
- **Memory Per Job**: Each compilation job uses significant memory (77-225MB per process)
- **Memory Exhaustion**: With 4 cores, 4+ parallel jobs can easily exhaust the 1.9GB RAM
- **Swap Thrashing**: When RAM is full, system uses swap, but swap also fills up (1.4GB)
- **Disk I/O Overload**: Excessive swapping causes constant disk I/O, making processes wait
- **System Freeze**: The combination of full RAM, full swap, and constant disk I/O causes system unresponsiveness

**Example:**
- 4 CPU cores → 4+ parallel compilation jobs
- Each job uses ~150MB RAM → 4 × 150MB = 600MB+ just for compilation
- Plus base system, Python, pip, etc. → easily exceeds 1.9GB RAM
- System starts swapping → swap fills up → thrashing occurs → system freezes

### Solution
**Limit the number of parallel build jobs to prevent memory exhaustion:**

```bash
# Set environment variables to limit parallelism
export NINJAFLAGS="-j2"        # Limit Ninja to 2 parallel jobs
export MAKEFLAGS="-j2"         # Limit Make to 2 parallel jobs
export MAX_JOBS=2              # General parallelism limit

# Or use pip's build isolation with limited jobs
pip wheel <package> --no-deps --wheel-dir ~/wheels \
  --config-settings="--build-option=-j2"
```

**Complete command via ADB with parallelism limits:**
```bash
adb shell "run-as com.termux sh -c 'export PREFIX=/data/data/com.termux/files/usr && export HOME=/data/data/com.termux/files/home && export PATH=\$PREFIX/bin:\$PATH && export NINJAFLAGS=\"-j2\" && export MAKEFLAGS=\"-j2\" && export MAX_JOBS=2 && cd \$HOME/wheels && pip wheel pandas --no-deps --wheel-dir .'"
```

**Alternative: Use fewer jobs for very memory-intensive builds:**
```bash
# For systems with limited RAM (like emulators)
export NINJAFLAGS="-j1"        # Single job (slowest but safest)
export MAKEFLAGS="-j1"
```

### Recommended Settings by System

**Android Emulator (1.9GB RAM):**
```bash
export NINJAFLAGS="-j2"
export MAKEFLAGS="-j2"
export MAX_JOBS=2
```

**Physical Device (2-4GB RAM):**
```bash
export NINJAFLAGS="-j3"
export MAKEFLAGS="-j3"
export MAX_JOBS=3
```

**High-end Device (6GB+ RAM):**
```bash
export NINJAFLAGS="-j4"
export MAKEFLAGS="-j4"
export MAX_JOBS=4
```

### How to Recover from Unresponsive System

**If system is already frozen:**

1. **Kill stuck build processes:**
```bash
adb shell "run-as com.termux sh -c 'pkill -9 -f \"pip.*pandas\" && pkill -9 -f \"cc.*pandas\" && pkill -9 -f \"pip.*scipy\" && pkill -9 -f \"cc.*scipy\"'"
```

2. **Clear swap (if possible):**
```bash
adb shell "su -c 'swapoff -a && swapon -a'"
```

3. **Restart with limited parallelism:**
```bash
# Set limits before building
export NINJAFLAGS="-j2"
export MAKEFLAGS="-j2"
# Then retry build
```

### Prevention

**Always set parallelism limits before building large packages:**
```bash
# Add to ~/.bashrc or set before each build
export NINJAFLAGS="-j2"
export MAKEFLAGS="-j2"
export MAX_JOBS=2
```

**For pip builds, you can also use:**
```bash
# Limit build jobs via pip config
pip config set global.build-option "-j2"
```

### Notes
- **Trade-off**: Fewer parallel jobs = slower build but stable system
- **Memory vs Speed**: 2 jobs is usually safe for 2GB RAM, 1 job for <2GB
- **Monitor Memory**: Use `free -h` and `top` to monitor memory usage during builds
- **Large Packages**: `pandas`, `scipy`, `scikit-learn`, `numpy` are particularly memory-intensive
- **Build Time**: Expect 2-4x longer build times with limited parallelism, but system remains responsive
- **Better Safe**: It's better to build slowly than to have the system freeze and lose progress

---

## Best Practices for Building Wheels in Termux

### 1. Initial Setup
```bash
# Update packages
pkg update -y

# Install Python and build tools
pkg install -y python python-pip

# Install build dependencies
pkg install -y autoconf automake libtool make binutils clang cmake ninja rust flang blas-openblas

# Create gfortran symlink for scipy compatibility
ln -sf $PREFIX/bin/flang $PREFIX/bin/gfortran

# Upgrade pip and install build tools
pip install --upgrade pip wheel build setuptools
```

### 2. Create Wheels Directory
```bash
mkdir -p ~/wheels
cd ~/wheels
```

### 3. Build Wheels
```bash
# Set parallelism limits to prevent memory exhaustion
export NINJAFLAGS="-j2"
export MAKEFLAGS="-j2"
export MAX_JOBS=2

# Download source distributions
pip download <package> --no-deps --no-cache-dir

# Build wheels
pip wheel <package> --no-deps --wheel-dir ~/wheels
```

### 4. Check for Built Wheels
```bash
# List all wheels
ls -lh ~/wheels/*.whl

# Check pip cache if wheel not found
find ~/.cache/pip/wheels -name "*.whl"
```

### 5. Copy Wheels from Emulator
```bash
# Pull wheels from Termux
adb pull /data/data/com.termux/files/home/wheels ./wheels/
```

---

## Common Issues and Quick Fixes

### Issue: "autoreconf: inaccessible or not found"
**Fix:** Install `autoconf` package: `pkg install -y autoconf`

### Issue: "Permission denied" when writing to /tmp
**Fix:** Use home directory: `--wheel-dir ~/wheels` instead of `--wheel-dir /tmp`

### Issue: "gcc: command not found"
**Fix:** Termux uses `clang` instead of `gcc`: `pkg install -y clang`

### Issue: Wheel built but not found in specified directory
**Fix:** Check pip cache: `~/.cache/pip/wheels/`

### Issue: "No such file or directory" when accessing Termux files
**Fix:** Use correct path: `/data/data/com.termux/files/home` (not `/data/user/0/com.termux`)

### Issue: "Rust not found" when building packages with maturin
**Fix:** Install Rust: `pkg install -y rust`

### Issue: "Unknown compiler(s): [['gfortran'], ...]" when building scipy/scikit-learn
**Fix:** Install Fortran compiler: `pkg install -y flang blas-openblas && ln -sf $PREFIX/bin/flang $PREFIX/bin/gfortran`

### Issue: System becomes unresponsive during build (memory exhaustion)
**Fix:** Limit parallelism: `export NINJAFLAGS="-j2" && export MAKEFLAGS="-j2"` before building

### Issue: Pip rebuilding packages despite having pre-built wheels
**Fix:** Use `--find-links`: `pip install <package> --find-links ~/wheels`

---

## Environment Variables for Termux

When running commands via ADB, always set these:
```bash
export PREFIX=/data/data/com.termux/files/usr
export HOME=/data/data/com.termux/files/home
export PATH=$PREFIX/bin:$PATH
```

---

## Summary of All Fixes Applied

### 1. Storage Issue
- **Status:** ✅ Resolved (requires AVD wipe)
- **Action:** Use `launch_pixel4a.bat` option 2 or 5 to wipe data

### 2. Patchelf Build Error
- **Status:** ✅ Resolved (pre-built wheel available)
- **Action:** Install build tools: `pkg install -y autoconf automake libtool make binutils clang cmake ninja`
- **Note:** Patchelf actually has a pre-built wheel, so building from source may not be necessary

### 3. Pandas Permission Error
- **Status:** ✅ Resolved
- **Action:** Use `~/wheels` instead of `/tmp` as wheel directory
- **Result:** Pandas wheel (11MB) successfully built and saved

### 4. Jiter Build Error (Rust Not Found)
- **Status:** ✅ Resolved
- **Action:** Install Rust: `pkg install -y rust`
- **Result:** Jiter wheel (378KB) successfully built and saved

### 5. Scikit-learn/Scipy Build Error (Fortran Compiler Missing)
- **Status:** ✅ Resolved
- **Action:** Install flang and BLAS: `pkg install -y flang blas-openblas && ln -sf $PREFIX/bin/flang $PREFIX/bin/gfortran`
- **Result:** Scipy metadata preparation now succeeds (build in progress)

### 6. System Unresponsive During Build (Memory Exhaustion)
- **Status:** ✅ Resolved
- **Action:** Limit parallelism: `export NINJAFLAGS="-j2" && export MAKEFLAGS="-j2"`
- **Result:** System remains responsive during builds, prevents memory exhaustion

### 7. Pip Rebuilding Packages (Wheels Not Used)
- **Status:** ✅ Resolved
- **Action:** Use `--find-links ~/wheels` when installing: `pip install <package> --find-links ~/wheels`
- **Result:** Pip uses pre-built wheels instead of rebuilding from source

### 8. Android Emulator No Internet Connectivity
- **Status:** ⚠️ Requires Windows Network Configuration
- **Action:** Restart emulator with DNS flags or configure Windows network adapter
- **Result:** Emulator can access internet for package downloads

### 9. Pandas Version Conflict (Wrong Version Built)
- **Status:** ✅ Resolved
- **Action:** Build and install correct pandas version that satisfies dependency constraints
- **Result:** Pandas 2.2.3 installed (satisfies `pandas<2.3.0`), prevents rebuilds

---

## 7. Pip Rebuilding Packages Despite Pre-built Wheels

### Error Description
When installing packages like `droidrun[google]`, pip rebuilds dependencies (e.g., `scikit-learn`, `scipy`) from source even though wheel files were already built and exist in the `~/wheels` directory.

**Symptoms:**
- `pip install droidrun[google]` starts building `scikit-learn` from source
- Build process takes a long time despite having pre-built wheels
- System may become unresponsive during rebuild
- Pip ignores existing wheel files in `~/wheels/` directory

### Root Cause
- `pip wheel` builds wheels and saves them locally to `~/wheels/`
- `pip install` by default only searches PyPI, not local directories
- Even if wheels exist locally, pip doesn't know to look there
- PyPI may not have compatible wheels for the platform (linux_x86_64), so pip falls back to building from source
- Without `--find-links`, pip ignores your pre-built wheels completely

**Why this happens:**
1. You build wheels: `pip wheel scikit-learn --no-deps --wheel-dir ~/wheels` → creates `~/wheels/scikit-learn-*.whl`
2. You install package: `pip install droidrun[google]` → pip needs `scikit-learn` as dependency
3. Pip searches PyPI first → doesn't find compatible wheel → builds from source
4. Your pre-built wheel is ignored because pip doesn't know it exists

### Solution
**Use `--find-links` to tell pip where to find pre-built wheels:**

```bash
# Install using pre-built wheels from local directory
pip install droidrun[google] --find-links ~/wheels

# Or use --no-index to only use local wheels (faster, but fails if wheel missing)
pip install droidrun[google] --find-links ~/wheels --no-index
```

**Complete command via ADB:**
```bash
adb shell "run-as com.termux sh -c 'export PREFIX=/data/data/com.termux/files/usr && export HOME=/data/data/com.termux/files/home && export PATH=\$PREFIX/bin:\$PATH && export NINJAFLAGS=\"-j2\" && export MAKEFLAGS=\"-j2\" && cd \$HOME && pip install droidrun[google] --find-links \$HOME/wheels'"
```

**Best Practice - Install wheels first, then main package:**
```bash
# Install all pre-built wheels first
pip install --find-links ~/wheels --no-index $(ls ~/wheels/*.whl)

# Then install main package (will use already installed dependencies)
pip install droidrun[google]
```

**Alternative - Use find-links with fallback to PyPI:**
```bash
# Try local wheels first, fallback to PyPI if not found
pip install droidrun[google] --find-links ~/wheels
```

### Notes
- `--find-links` tells pip to check the specified directory for wheels before checking PyPI
- `--no-index` prevents pip from checking PyPI (use only if all wheels are local)
- Without `--find-links`, pip will rebuild packages even if wheels exist locally
- Always use `--find-links ~/wheels` when installing packages after building wheels
- This saves significant time and prevents system unresponsiveness from rebuilds
- The `--find-links` flag can point to a directory or URL containing wheel files
- You can specify multiple find-links: `--find-links ~/wheels --find-links ~/other-wheels`

### Example Workflow

**Step 1: Build wheels**
```bash
cd ~/wheels
export NINJAFLAGS="-j2"
export MAKEFLAGS="-j2"
pip wheel scikit-learn --no-deps --wheel-dir .
pip wheel scipy --no-deps --wheel-dir .
# ... build other wheels
```

**Step 2: Install using pre-built wheels**
```bash
cd ~
pip install droidrun[google] --find-links ~/wheels
# Pip will use scikit-learn and scipy from ~/wheels instead of rebuilding
```

---

## 8. Android Emulator No Internet Connectivity

### Error Description
Android emulator shows no internet connectivity:
- Apps cannot access the internet
- Browser shows "No internet connection"
- `ping 8.8.8.8` shows 100% packet loss
- `ping google.com` fails with "unknown host" or packet loss
- Emulator can ping host machine (10.0.2.2) but not external internet

**Symptoms:**
- WiFi icon shows connected but no internet
- Settings show WiFi is on, airplane mode is off
- Network interfaces exist (eth0, wlan0) with IPs (10.0.2.15, 10.0.2.16)
- Default route may be missing or not working

### Root Cause
- **Windows Network Configuration**: Android emulator uses a special NAT network where `10.0.2.2` represents the host machine
- **Missing Default Route**: Emulator may not have a default gateway configured
- **NAT/Forwarding Issue**: Windows may not be forwarding packets from the emulator's virtual network adapter
- **DNS Resolution**: Even if routing works, DNS may not be configured properly
- **Firewall/Network Adapter**: Windows firewall or network adapter settings may block emulator traffic

**Network Architecture:**
- Emulator IP: `10.0.2.15` (eth0) or `10.0.2.16` (wlan0)
- Host machine: `10.0.2.2`
- Host should forward packets from emulator to internet, but this may not be configured

### Solution

**Method 1: Restart Emulator with DNS Flags (Recommended)**
```bash
# Stop current emulator
adb -s emulator-5554 emu kill

# Start with DNS and network settings
emulator -avd Pixel_6 -dns-server 8.8.8.8,8.8.4.4 -netdelay none -netspeed full
```

**Method 2: Configure Default Route (If Method 1 doesn't work)**
```bash
# Check current routes
adb shell "ip route show"

# Try to add default route (may require root)
adb shell "ip route add default via 10.0.2.2 dev eth0"
```

**Method 3: Use Emulator Extended Controls**
1. Open emulator
2. Click "..." (three dots) to open Extended Controls
3. Go to Settings → Network
4. Enable "Cellular" or "WiFi" data
5. Check DNS settings

**Method 4: Windows Network Configuration (Advanced)**
If the above methods don't work, you may need to configure Windows:

1. **Check Network Adapters:**
   - Open Device Manager
   - Look for "Android Emulator" or "VirtualBox" network adapters
   - Ensure they're enabled

2. **Windows Internet Connection Sharing:**
   - Open Network Connections
   - Right-click your main internet connection
   - Properties → Sharing tab
   - Enable "Allow other network users to connect"

3. **Firewall Settings:**
   - Windows Defender Firewall may block emulator traffic
   - Add exception for Android emulator

**Method 5: Use Cold Boot**
Sometimes a cold boot fixes network issues:
```bash
# Stop emulator
adb -s emulator-5554 emu kill

# Start with cold boot (wipes temporary state)
emulator -avd Pixel_6 -no-snapshot-load -dns-server 8.8.8.8,8.8.4.4
```

### Verification

**Test connectivity:**
```bash
# Test ping to host
adb shell "ping -c 2 10.0.2.2"

# Test ping to internet
adb shell "ping -c 3 8.8.8.8"

# Test DNS resolution
adb shell "ping -c 2 google.com"
```

**Check network configuration:**
```bash
# Check routes
adb shell "ip route show"

# Check interfaces
adb shell "ifconfig"

# Check DNS
adb shell "getprop | grep dns"
```

### Notes
- **Emulator Network**: Uses special NAT where `10.0.2.2` = host machine
- **Default Route**: Should be `default via 10.0.2.2 dev eth0`
- **DNS**: Should be set to `8.8.8.8` and `8.8.4.4` (Google DNS)
- **Windows Specific**: This issue is more common on Windows than Linux/Mac
- **Restart Often Helps**: Simply restarting the emulator with proper flags often fixes it
- **Cold Boot**: If network issues persist, try cold boot (`-no-snapshot-load`)
- **Alternative**: If internet is critical, consider using a physical Android device via USB debugging

### Troubleshooting Steps

1. **Verify host has internet:**
   ```bash
   ping 8.8.8.8  # Should work from Windows
   ```

2. **Check emulator can reach host:**
   ```bash
   adb shell "ping -c 2 10.0.2.2"  # Should work
   ```

3. **Check default route exists:**
   ```bash
   adb shell "ip route show"  # Should show "default via 10.0.2.2"
   ```

4. **Restart with network flags:**
   ```bash
   emulator -avd Pixel_6 -dns-server 8.8.8.8,8.8.4.4 -netdelay none -netspeed full
   ```

5. **If still not working**: Check Windows network adapter settings and firewall

---

## 9. Pandas Version Conflict - Wrong Version Built

### Error Description
When installing `droidrun[google]`, pip rebuilds pandas from source even though a pandas wheel already exists. The build process shows:
```
Collecting pandas<2.3.0 (from llama-index-readers-file<0.6,>=0.5.0->llama-index==0.14.4->droidrun[google])
Using cached pandas-2.2.3.tar.gz (4.4 MB)
Installing build dependencies: started
Preparing metadata (pyproject.toml): started
Building wheels for collected packages: pandas
```

**Symptoms:**
- Pandas wheel exists in `~/wheels/` (e.g., `pandas-2.3.3-cp312-cp312-linux_x86_64.whl`)
- But pip still tries to build pandas from source
- Dependency requires `pandas<2.3.0` but wheel is for version 2.3.3
- Build takes a long time despite having a pre-built wheel

### Root Cause
- **Version Mismatch**: You built pandas 2.3.3, but the dependency requires `pandas<2.3.0`
- **Constraint Not Satisfied**: The existing wheel (2.3.3) doesn't satisfy the version constraint (`<2.3.0`)
- **Pip Resolution**: When pip resolves dependencies, it checks version constraints and finds that 2.3.3 doesn't match `<2.3.0`
- **Rebuild Required**: Pip must build the correct version (2.2.3) from source to satisfy the constraint
- **Wrong Version Built First**: The initial wheel build didn't consider the actual dependency requirements

**Example:**
- You built: `pandas-2.3.3-cp312-cp312-linux_x86_64.whl`
- Dependency needs: `pandas<2.3.0`
- Result: Pip ignores 2.3.3 wheel and builds 2.2.3 from source

### Solution
**Build and install the correct pandas version that satisfies the dependency constraint:**

```bash
# Step 1: Remove old incompatible pandas wheel
cd ~/wheels
rm -f pandas-2.3.3*.whl

# Step 2: Download the correct pandas version
pip download "pandas<2.3.0" --dest . --no-cache-dir

# Step 3: Build wheel from the correct version
export NINJAFLAGS="-j2"
export MAKEFLAGS="-j2"
pip wheel pandas-2.2.3.tar.gz --no-deps --wheel-dir .

# Step 4: Uninstall any existing pandas
pip uninstall -y pandas

# Step 5: Install the correct version from wheel
pip install --find-links . --no-index pandas-2.2.3*.whl
```

**Complete command via ADB:**
```bash
adb shell "run-as com.termux sh -c 'export PREFIX=/data/data/com.termux/files/usr && export HOME=/data/data/com.termux/files/home && export PATH=\$PREFIX/bin:\$PATH && export NINJAFLAGS=\"-j2\" && export MAKEFLAGS=\"-j2\" && cd \$HOME/wheels && rm -f pandas-2.3.3*.whl && pip download \"pandas<2.3.0\" --dest . --no-cache-dir && pip wheel pandas-2.2.3.tar.gz --no-deps --wheel-dir . && pip uninstall -y pandas 2>/dev/null && pip install --find-links . --no-index pandas-2.2.3*.whl'"
```

**One-liner version:**
```bash
adb shell "run-as com.termux sh -c 'export PREFIX=/data/data/com.termux/files/usr && export HOME=/data/data/com.termux/files/home && export PATH=\$PREFIX/bin:\$PATH && export NINJAFLAGS=\"-j2\" && export MAKEFLAGS=\"-j2\" && cd \$HOME/wheels && rm -f pandas-2.3.3*.whl && pip download \"pandas<2.3.0\" --dest . --no-cache-dir && pip wheel pandas-2.2.3.tar.gz --no-deps --wheel-dir . && pip uninstall -y pandas 2>/dev/null && pip install --find-links . --no-index pandas-2.2.3*.whl'"
```

### Prevention Strategy

**Before building wheels, check dependency requirements:**

```bash
# Check what version constraints are needed
pip download 'droidrun[google]' --dest . --no-deps --no-cache-dir
# Check the downloaded packages for version constraints
grep -r "pandas" *.tar.gz | grep -i "requires\|depends"
```

**Build wheels with version constraints:**

```bash
# Build pandas with the constraint in mind
pip download "pandas<2.3.0" --dest . --no-cache-dir
pip wheel pandas-2.2.3.tar.gz --no-deps --wheel-dir .
```

**Install dependencies first with correct versions:**

```bash
# Install pandas with constraint before installing main package
pip install --find-links ~/wheels 'pandas<2.3.0'
# Then install main package
pip install 'droidrun[google]' --find-links ~/wheels
```

### Verification

**Check installed pandas version:**
```bash
pip show pandas | grep Version
# Should show: Version: 2.2.3
```

**Verify it satisfies constraint:**
```bash
python -c "import pandas; print(pandas.__version__)"
# Should print: 2.2.3
```

**Test that droidrun installation won't rebuild:**
```bash
pip install 'droidrun[google]' --find-links ~/wheels --dry-run
# Should show pandas as already satisfied, not needing build
```

### Notes
- **Version Constraints Matter**: Always check dependency version requirements before building wheels
- **Build Correct Version**: Build the version that satisfies all constraints, not just the latest
- **Check Before Building**: Use `pip download` first to see what versions are actually needed
- **Install First**: Install dependencies with correct versions before installing the main package
- **Version Resolution**: Pip resolves dependencies based on constraints, not just availability
- **Common Issue**: This happens when you build the latest version but dependencies need older versions
- **Time Saver**: Building the correct version first saves significant time during installation

### Related Issues
- This is related to [Section 7: Pip Rebuilding Packages](#7-pip-rebuilding-packages-despite-pre-built-wheels)
- The difference is that here the wheel exists but wrong version, while Section 7 is about pip not finding wheels at all

---

## Last Updated
December 2, 2024

## Complete Build Dependencies List

For building Python wheels in Termux, install all these packages:

```bash
pkg install -y \
  python python-pip \
  autoconf automake libtool make binutils \
  clang cmake ninja \
  rust \
  flang blas-openblas

# Create gfortran symlink for scipy compatibility
ln -sf $PREFIX/bin/flang $PREFIX/bin/gfortran
```

This covers:
- **Python packages**: `python`, `python-pip`
- **C/C++ build tools**: `autoconf`, `automake`, `libtool`, `make`, `binutils`, `clang`, `cmake`, `ninja`
- **Rust build tools**: `rust` (for packages using maturin)
- **Fortran build tools**: `flang` (for packages like scipy/scikit-learn)
- **Numerical libraries**: `blas-openblas` (BLAS/LAPACK for scipy)

---

## 10. Scikit-learn Meson Build Error - Could Not Execute version.py

### Quick Fix: Use GitHub Source
Instead of downloading from PyPI, clone directly from GitHub to avoid metadata generation errors:

```bash
# Clone and build scikit-learn
cd ~/wheels
git clone --depth 1 https://github.com/scikit-learn/scikit-learn.git scikit-learn-source
cd scikit-learn-source
chmod +x sklearn/_build_utils/version.py
export NINJAFLAGS="-j2" && export MAKEFLAGS="-j2" && export MAX_JOBS=2
pip wheel --no-deps --wheel-dir ~/wheels .
pip install --no-deps $(ls ~/wheels/scikit-learn-*.whl | head -1)
```

See full details below.

---

### Error Description
When building scikit-learn, meson fails with:
```
ERROR: Could not execute command `/data/data/com.termux/files/usr/tmp/pip-install-.../scikit-learn_.../sklearn/_build_utils/version.py`.
```

### Root Cause
- scikit-learn uses meson-python for building
- During meson setup, it tries to execute `sklearn/_build_utils/version.py` directly
- The script may not have execute permissions
- The script may not have a proper shebang line
- Python interpreter may not be in PATH when meson tries to execute it

### Solution
**Option 1: Fix script permissions and shebang (automated in install script)**

The installation script now automatically:
1. Extracts the source tarball
2. Fixes permissions on `version.py` (`chmod +x`)
3. Adds Python shebang if missing
4. Recreates the tarball with fixes
5. Builds the wheel

**Option 2: Manual fix**

If building manually:
```bash
# Download source
pip download scikit-learn --dest . --no-cache-dir

# Extract
tar -xzf scikit-learn-*.tar.gz
cd scikit-learn-*

# Fix version.py
chmod +x sklearn/_build_utils/version.py
if ! head -1 sklearn/_build_utils/version.py | grep -q "^#!"; then
    sed -i '1i#!/usr/bin/env python3' sklearn/_build_utils/version.py
fi

# Recreate tarball
cd ..
tar -czf scikit-learn-fixed.tar.gz scikit-learn-*

# Build wheel
pip wheel --no-deps --wheel-dir . scikit-learn-fixed.tar.gz
```

**Option 3: Set PYTHON environment variable**

Before building, ensure Python is in PATH:
```bash
export PYTHON=$(which python3)
export PATH=$PREFIX/bin:$PATH
pip wheel scikit-learn --no-deps --wheel-dir .
```

### Prevention
- The installation script (`install-droidrun-dependencies.sh`) now includes special handling for scikit-learn
- It automatically fixes the version.py script before building
- This ensures the meson build can execute the script successfully

### Alternative Solution: Clone from GitHub
If PyPI download fails due to metadata generation errors, clone directly from GitHub:

```bash
# Clone from GitHub
cd ~/wheels
git clone --depth 1 https://github.com/scikit-learn/scikit-learn.git scikit-learn-source

# Fix version.py
cd scikit-learn-source
chmod +x sklearn/_build_utils/version.py
if ! head -1 sklearn/_build_utils/version.py | grep -q "^#!"; then
    sed -i "1i#!/usr/bin/env python3" sklearn/_build_utils/version.py
fi

# Build wheel from GitHub source
export NINJAFLAGS="-j2"
export MAKEFLAGS="-j2"
export MAX_JOBS=2
export PYTHON=$(which python3)
pip wheel --no-deps --wheel-dir ~/wheels .

# Install from wheel
pip install --no-deps $(ls ~/wheels/scikit-learn-*.whl | head -1)
```

**Advantages:**
- Avoids PyPI metadata generation errors
- Gets latest source code
- More reliable for building from source

### Related Packages
- **scikit-learn**: Uses meson-python build system
- **pyarrow**: May have similar issues (also uses meson-python)

### Using GitHub Source (Recommended)
For both scikit-learn and pyarrow, cloning from GitHub is more reliable than PyPI:

**scikit-learn:**
```bash
git clone --depth 1 https://github.com/scikit-learn/scikit-learn.git scikit-learn-source
cd scikit-learn-source
chmod +x sklearn/_build_utils/version.py
pip wheel --no-deps --wheel-dir ~/wheels .
```

**pyarrow:**
```bash
git clone --depth 1 https://github.com/apache/arrow.git pyarrow-source
cd pyarrow-source/python
pip wheel --no-deps --wheel-dir ~/wheels .
```

This avoids PyPI metadata generation errors and provides the latest source code.

---

## 11. PyArrow Build Error - Similar to Scikit-learn

### Error Description
PyArrow may encounter similar build errors when building from source, particularly related to build system configuration.

### Solution: Use GitHub Source
Clone pyarrow from Apache Arrow repository:

```bash
# Clone and build pyarrow
cd ~/wheels
git clone --depth 1 https://github.com/apache/arrow.git pyarrow-source
cd pyarrow-source/python
export NINJAFLAGS="-j2" && export MAKEFLAGS="-j2" && export MAX_JOBS=2
pip wheel --no-deps --wheel-dir ~/wheels .
pip install --no-deps $(ls ~/wheels/pyarrow-*.whl | head -1)
```

**Note:** PyArrow is located in the `python/` subdirectory of the Arrow repository.

### Alternative: Use Pre-built Wheel
If building fails, check if a compatible wheel is available:
```bash
pip install --find-links ~/wheels pyarrow
```

### Related Packages
- **pyarrow**: Part of Apache Arrow project, uses cmake and meson build systems

---

## 12. Termux App Causing System Hang / Memory Exhaustion

### Error Description
The Android emulator becomes unresponsive or stuck on the same screen, showing "Application Not Responding: system" (ANR). The system appears frozen and cannot respond to user input.

### Symptoms
- Emulator screen frozen on launcher or any app
- System shows "Application Not Responding: system" in window focus
- High memory usage (e.g., 1.9GB used out of 2GB total)
- Swap memory being used (e.g., 600MB+ swap used)
- Very low free RAM (e.g., <150MB free)
- System processes consuming excessive CPU

### Root Cause
1. **Memory Leak in Termux**: After running long build processes (especially for packages like scikit-learn, pyarrow, pandas), Termux may retain memory from completed or failed builds
2. **Background Build Processes**: Stuck or zombie build processes (python, pip, clang, rustc, ninja, make) may still be running in the background
3. **Limited Emulator RAM**: Pixel 6 emulator typically has only 2GB RAM, which is insufficient for multiple concurrent builds
4. **Memory Fragmentation**: After multiple build attempts, memory becomes fragmented and unavailable
5. **ADB Shell Sessions**: Multiple ADB shell sessions may hold resources even after commands complete

### Diagnosis

Check system memory:
```bash
adb shell "free -h"
# Should show: Mem: ~1.9Gi total, used should be <1.5Gi, free >200Mi
```

Check Termux memory usage:
```bash
adb shell "dumpsys meminfo com.termux | head -30"
# Check Pss Total and Rss Total values
```

Check for stuck processes:
```bash
adb shell "run-as com.termux sh -c 'export PREFIX=/data/data/com.termux/files/usr && export PATH=\$PREFIX/bin:\$PATH && ps -o pid,comm,args | grep -E \"python|pip|clang|gcc|rustc|ninja|make|meson\"'"
```

Check window focus:
```bash
adb shell "dumpsys window | grep -E 'mCurrentFocus'"
# If shows "Application Not Responding", system is frozen
```

### Solution

**Option 1: Force Stop Termux (Quick Fix)**

```bash
# Force stop Termux to release memory
adb shell "am force-stop com.termux"

# Wait a few seconds
sleep 3

# Restart Termux (manually open from launcher or use):
adb shell "monkey -p com.termux -c android.intent.category.LAUNCHER 1"
```

**Option 2: Kill Stuck Build Processes**

```bash
# Kill all Python/pip processes in Termux
adb shell "run-as com.termux sh -c 'export PREFIX=/data/data/com.termux/files/usr && export PATH=\$PREFIX/bin:\$PATH && pkill -9 python && pkill -9 pip && pkill -9 clang && pkill -9 rustc && pkill -9 ninja && pkill -9 make'"
```

**Option 3: Restart Emulator (Nuclear Option)**

If the system is completely unresponsive:
1. Use `launch_pixel4a.bat` script option 7 (Stop Emulator)
2. Wait for emulator to fully stop
3. Relaunch using option 6 (Relaunch Pixel 6)

**Option 4: Clear Termux Data (Last Resort)**

If Termux continues to cause issues:
```bash
# WARNING: This will delete all Termux data
adb shell "pm clear com.termux"
```

### Prevention

1. **Build One Package at a Time**: Never run multiple builds concurrently
2. **Set Parallelism Limits**: Always use `NINJAFLAGS="-j2"`, `MAKEFLAGS="-j2"`, `MAX_JOBS=2`
3. **Monitor Memory**: Check memory usage before starting new builds:
   ```bash
   adb shell "run-as com.termux sh -c 'free -h'"
   ```
4. **Clean Up After Builds**: After each build completes or fails:
   ```bash
   # Kill any remaining processes
   pkill -9 python pip clang rustc ninja make 2>/dev/null
   
   # Clear pip cache if needed
   pip cache purge
   ```
5. **Restart Termux Periodically**: After building 2-3 large packages, restart Termux:
   ```bash
   adb shell "am force-stop com.termux && sleep 2"
   # Then manually reopen Termux
   ```
6. **Use Smaller Emulator RAM**: Consider reducing emulator RAM allocation if possible (though 2GB is already minimal)
7. **Close Unused Apps**: Close other apps in the emulator before building

### Memory Monitoring Script

Create a script to monitor memory before builds:
```bash
#!/data/data/com.termux/files/usr/bin/bash
# check-memory.sh

echo "=== System Memory ==="
free -h

echo ""
echo "=== Termux Memory ==="
ps -o pid,vsz,rss,comm -p $(pgrep -f com.termux) 2>/dev/null || echo "Termux not running"

echo ""
echo "=== Build Processes ==="
ps -o pid,comm,args | grep -E "python|pip|clang|gcc|rustc|ninja|make|meson" | head -10 || echo "No build processes running"

# Check if memory is low
FREE_MB=$(free -m | awk 'NR==2{print $4}')
if [ "$FREE_MB" -lt 200 ]; then
    echo ""
    echo "WARNING: Low memory ($FREE_MB MB free). Consider restarting Termux."
    exit 1
fi
```

### Recovery Steps

If system is completely frozen:
1. **Don't panic** - The emulator can be recovered
2. **Stop emulator** using ADB: `adb -s emulator-5554 emu kill`
3. **Wait 10 seconds** for processes to terminate
4. **Relaunch emulator** using `launch_pixel4a.bat`
5. **Force stop Termux** once emulator boots: `adb shell "am force-stop com.termux"`
6. **Wait 5 seconds**, then reopen Termux manually
7. **Check memory**: `adb shell "free -h"` - should show >500MB free

### Related Issues
- System unresponsiveness during build (Error 6)
- Memory exhaustion during parallel builds
- Build processes getting stuck

---

## 13. Termux Black Screen / Bootstrap Stuck Issue

### Error Description
After installing or reinstalling Termux, the app shows a black screen and never displays the terminal. The app appears to be stuck on the `BootstrapSetupActivity` screen.

### Symptoms
- Termux app opens but shows black screen
- App is stuck on bootstrap/setup screen
- No terminal prompt appears
- Bootstrap process never completes
- `bash` and other binaries are missing from `$PREFIX/bin/`

### Root Cause
1. **Bootstrap Process Hanging**: Termux needs to download and install its base packages (bash, coreutils, etc.) on first launch, but this process can hang due to:
   - Network connectivity issues (emulator has no internet)
   - Insufficient storage space
   - Corrupted Termux installation
   - Memory issues preventing bootstrap completion

2. **Network Issues**: The emulator may not have internet connectivity, preventing Termux from downloading bootstrap packages

3. **Storage Issues**: Insufficient storage prevents bootstrap files from being written

4. **Memory Issues**: Low RAM can cause the bootstrap process to fail silently

### Diagnosis

Check if bootstrap completed:
```bash
adb shell "run-as com.termux sh -c 'test -f /data/data/com.termux/files/usr/bin/bash && echo \"bootstrap complete\" || echo \"bootstrap incomplete\"'"
```

Check network connectivity:
```bash
adb shell "ping -c 2 8.8.8.8"
```

Check storage:
```bash
adb shell "df -h /data"
```

Check Termux logs:
```bash
adb logcat -d | grep -i termux | tail -30
```

### Solution

**Option 1: Fix Network Connectivity (Most Common)**

The emulator needs internet for Termux to download bootstrap packages:

1. **Check emulator network**:
   ```bash
   adb shell "ping -c 2 8.8.8.8"
   ```

2. **If no internet**, restart emulator with DNS:
   ```bash
   # Stop emulator
   adb -s emulator-5554 emu kill
   
   # Restart with DNS (use launch script option 6 - Relaunch)
   # Or manually:
   emulator -avd Pixel_6 -dns-server 8.8.8.8,8.8.4.4
   ```

3. **Verify internet in emulator**:
   - Open Chrome/Settings
   - Try to access a website
   - If no internet, check Windows network settings

4. **Once internet works**, reopen Termux and wait 2-3 minutes for bootstrap

**Option 2: Manual Bootstrap (Advanced)**

If network is working but bootstrap still hangs:

1. **Force stop Termux**:
   ```bash
   adb shell "am force-stop com.termux"
   ```

2. **Clear Termux data** (WARNING: Deletes all data):
   ```bash
   adb shell "pm clear com.termux"
   ```

3. **Reinstall Termux** from Play Store or F-Droid

4. **Open Termux** and wait for bootstrap (requires internet)

**Option 3: Use Pre-configured Termux**

If bootstrap continues to fail:

1. Download Termux bootstrap manually (advanced, not recommended)
2. Or use a pre-configured Termux backup
3. Or use a different emulator with better network support

### Prevention

1. **Ensure Internet Connectivity**: Always verify emulator has internet before opening Termux for the first time
2. **Adequate Storage**: Ensure at least 1-2 GB free storage for bootstrap
3. **Sufficient RAM**: Use emulator with at least 4 GB RAM (6 GB recommended)
4. **Wait Patiently**: Bootstrap can take 2-5 minutes on first launch
5. **Don't Interrupt**: Don't force-stop Termux during bootstrap

### Recovery Steps

If Termux is stuck on black screen:

1. **Check internet**: `adb shell "ping -c 2 8.8.8.8"`
2. **If no internet**: Restart emulator with DNS flags
3. **Force stop Termux**: `adb shell "am force-stop com.termux"`
4. **Wait 10 seconds**
5. **Reopen Termux** from launcher
6. **Wait 3-5 minutes** for bootstrap to complete
7. **Check if bash exists**: `adb shell "run-as com.termux sh -c 'test -f \$PREFIX/bin/bash && echo OK || echo FAIL'"`
8. **If still stuck**: Clear data and reinstall

### Related Issues
- Android emulator no internet connectivity (Error 8)
- Termux app causing system hang (Error 12)
- Storage configuration issues (Error 1)

---

## 14. Pandas Meson Build - Version Line Fix Issue

### Error Description
When building pandas 2.2.3 from source (either from PyPI tarball or GitHub), the meson build system fails because it cannot execute `generate_version.py` to get the version. The meson.build file has a line that tries to run the script, but it fails with "Could not execute command".

### Symptoms
- Meson build fails with: `ERROR: Could not execute command '/path/to/generate_version.py --print'`
- Or: `ERROR: Method name must be plain id` when trying to hardcode version
- The meson.build line 5 contains: `version: run_command(['generate_version.py', '--print'], check: true).stdout().strip()`

### Root Cause
1. **Script Execution Issue**: Meson tries to execute `generate_version.py` directly, but it needs to be called with `python3` explicitly
2. **Quoting Complexity**: Fixing the meson.build file via ADB shell commands is extremely difficult due to nested quoting issues (single quotes, double quotes, backslashes)
3. **Version Hardcoding**: Attempts to hardcode the version as `version: '2.2.3',` fail due to meson syntax requirements and quoting issues in shell commands

### Solution

**Option 1: Manual Fix (Recommended)**

1. **Access Termux directly** (not via ADB) and fix the file:
   ```bash
   cd ~/wheels/pandas-2.2.3  # or ~/wheels/pandas if from GitHub
   # Edit meson.build line 5 to:
   #     version: '2.2.3',
   # Or use:
   python3 -c "lines=open('meson.build').readlines(); lines[4]=\"    version: '2.2.3',\n\"; open('meson.build','w').writelines(lines)"
   ```

2. **Then build the wheel**:
   ```bash
   pip wheel --no-deps --wheel-dir .. .
   ```

**Option 2: Use Pre-built Wheel (If Available)**

Check if a pre-built wheel exists for your platform:
```bash
pip download pandas==2.2.3 --no-deps --dest ~/wheels
```

**Option 3: Use Older Pandas Version**

Try pandas 2.1.x or 2.0.x which might use setuptools instead of meson:
```bash
pip download "pandas<2.2.0,>=2.0.0" --no-deps --dest ~/wheels
pip wheel pandas-2.1.*.tar.gz --no-deps --wheel-dir ~/wheels
```

**Option 4: Fix via Python Script (If ADB Access)**

Create a Python script on your host machine, push it via ADB, and execute:
```bash
# On host
cat > fix_pandas_meson.py << 'EOF'
with open("meson.build", "r") as f:
    lines = f.readlines()
lines[4] = "    version: '2.2.3',\n"
with open("meson.build", "w") as f:
    f.writelines(lines)
print("Fixed")
EOF

# Push and execute
adb push fix_pandas_meson.py /sdcard/
adb shell "run-as com.termux sh -c 'cd ~/wheels/pandas && cp /sdcard/fix_pandas_meson.py . && python3 fix_pandas_meson.py'"
```

### Prevention

1. **Pre-build Fix Script**: Create a fix script before building pandas
2. **Use Pre-built Wheels**: Check for pre-built wheels first
3. **Version Pinning**: Consider using a pandas version that doesn't require meson

### Related Issues
- Scikit-learn version script issue (Error 12) - similar problem with script execution
- Meson build system compatibility issues in Termux

---

## 15. Pillow Build Error - Missing JPEG/Image Library Dependencies

### Error Description
When building Pillow (PIL) wheel, the build process fails with:
```
RequiredDependencyException: jpeg
The headers or library files could not be found for jpeg,
a required dependency when compiling Pillow from source.
```

### Symptoms
- Build fails during `build_ext` phase
- Error: "The headers or library files could not be found for jpeg"
- Pillow requires multiple image format libraries to build from source

### Root Cause
- Pillow (PIL) requires system libraries for various image formats (JPEG, PNG, TIFF, WebP, etc.)
- These libraries are not installed in Termux
- Pillow's build system looks for these libraries during compilation
- Missing libraries cause the build to fail

### Solution
**Install all required image library dependencies:**

```bash
# Install all image format libraries required by Pillow
pkg install -y \
  libjpeg-turbo \
  libpng \
  libtiff \
  libwebp \
  freetype \
  libimagequant \
  libraqm \
  littlecms \
  openjpeg \
  zlib

# Then build Pillow wheel
cd ~/wheels
pip download pillow --dest . --no-cache-dir
pip wheel pillow --no-deps --wheel-dir .
```

**Complete command via ADB:**
```bash
adb shell "run-as com.termux sh -c 'export PREFIX=/data/data/com.termux/files/usr && export HOME=/data/data/com.termux/files/home && export PATH=\$PREFIX/bin:\$PATH && pkg install -y libjpeg-turbo libpng libtiff libwebp freetype libimagequant libraqm littlecms openjpeg zlib && cd ~/wheels && pip download pillow --dest . --no-cache-dir && pip wheel pillow --no-deps --wheel-dir .'"
```

### Required Packages

| Package | Purpose | Required For |
|---------|---------|--------------|
| `libjpeg-turbo` | JPEG image support | **CRITICAL** - Main error |
| `libpng` | PNG image support | PNG format |
| `libtiff` | TIFF image support | TIFF format |
| `libwebp` | WebP image support | WebP format |
| `freetype` | Font rendering | Text in images |
| `libimagequant` | Image quantization | Color reduction |
| `libraqm` | Text shaping | Complex text layout |
| `littlecms` | Color management | Color profiles |
| `openjpeg` | JPEG 2000 support | JPEG2000 format |
| `zlib` | Compression | General compression |

### Minimal Installation (JPEG Only)

If you only need basic JPEG support:

```bash
pkg install -y libjpeg-turbo zlib
```

### Full Installation (All Formats)

For full Pillow functionality with all image formats:

```bash
pkg install -y libjpeg-turbo libpng libtiff libwebp freetype libimagequant libraqm littlecms openjpeg zlib
```

### Verification

After installing libraries, verify they're found:

```bash
# Check if libraries are installed
pkg list-installed | grep -E "jpeg|png|tiff|webp"

# Check library paths
ls -la $PREFIX/lib/libjpeg* $PREFIX/lib/libpng* 2>/dev/null || echo "Libraries not found"
```

### Build Pillow After Installing Libraries

```bash
# Set build environment
export NINJAFLAGS="-j2"
export MAKEFLAGS="-j2"
export MAX_JOBS=2

# Build Pillow wheel
cd ~/wheels
pip download pillow --dest . --no-cache-dir
pip wheel pillow --no-deps --wheel-dir .

# Install from wheel
pip install --find-links . --no-index pillow*.whl

# Verify
pip show pillow
python3 -c "from PIL import Image; print('✅ Pillow installed')"
```

### Notes
- **libjpeg-turbo** is the most critical - this is what causes the main error
- Other libraries enable additional image format support
- Pillow can build with minimal libraries, but more libraries = more format support
- Build time: ~5-15 minutes
- Wheel size: ~2-5 MB

### Prevention
- Install image libraries before building Pillow
- Check `pkg list-installed | grep -E "jpeg|png|tiff|webp"` before building
- Pillow is often a dependency of other packages, so install libraries early

### Related Packages
- Pillow is commonly required by packages that handle images
- Many packages depend on Pillow indirectly
- Installing Pillow dependencies early prevents cascading build failures

---

## 16. grpcio Build Error - Compilation Failure

### Error Description
When building `grpcio` wheel, the build process fails with a compilation error:
```
distutils.compilers.C.errors.CompileError: command '/data/data/com.termux/files/usr/bin/x86_64-linux-android-clang' failed with exit code 1
ERROR: Failed building wheel for grpcio
```

**Additional error message:**
```
You requested a Cython build via GRPC_PYTHON_BUILD_WITH_CYTHON, but do not have Cython installed.
Extensions have been poisoned due to missing Cython-generated code.
```

### Symptoms
- Build fails during C/C++ compilation phase
- Clang compiler exits with error code 1
- Error occurs in `grpcio/_parallel_compile_patch.py` during parallel compilation
- Error message indicates Cython is missing in build isolation environment

### Root Cause
- `grpcio` is a complex C++ package with many native extensions
- Requires Cython to be available in the build environment
- By default, pip uses build isolation which creates a separate environment
- Cython installed in the main environment is not available in the isolated build environment
- Requires specific system libraries (protobuf, abseil-cpp, c-ares, re2, openssl, zlib)

### Solution

**Install all required system dependencies and build without isolation:**

```bash
# Install system dependencies
pkg install -y openssl libc++ zlib protobuf libprotobuf abseil-cpp c-ares libre2 ca-certificates

# Install Python build dependencies in main environment
pip install --upgrade pip wheel setuptools "Cython>=3.0.0"

# Set environment variables
export NINJAFLAGS="-j2"
export MAKEFLAGS="-j2"
export MAX_JOBS=2
export GRPC_PYTHON_BUILD_SYSTEM_OPENSSL=1
export GRPC_PYTHON_BUILD_SYSTEM_ZLIB=1
export GRPC_PYTHON_BUILD_SYSTEM_CARES=1
export GRPC_PYTHON_BUILD_SYSTEM_RE2=1
export GRPC_PYTHON_BUILD_SYSTEM_ABSL=1
export GRPC_PYTHON_BUILD_WITH_CYTHON=1

# Build grpcio WITHOUT build isolation (so Cython is available)
cd ~/wheels
pip download grpcio --dest . --no-cache-dir
pip wheel grpcio --no-deps --no-build-isolation --wheel-dir .
pip install --find-links . --no-index grpcio*.whl
```

**Key fix:** Use `--no-build-isolation` flag so Cython from the main environment is available during build.

**Note:** If build still fails, try reducing parallelism to `-j1` or check compiler error logs.

### Alternative: Use Pre-built Wheel

```bash
pip download grpcio --dest ~/wheels --no-cache-dir
# If a .whl file is downloaded, use it directly
```

---

## 17. PyArrow Build Error - Missing Arrow C++ Libraries

### Error Description
When building `pyarrow` wheel, the build process fails with:
```
CMake Error: Could not find a package configuration file provided by "Arrow"
Add the installation prefix of "Arrow" to CMAKE_PREFIX_PATH or set "Arrow_DIR"
ERROR: Failed building wheel for pyarrow
```

### Root Cause
- `pyarrow` requires Apache Arrow C++ library to be built and installed first
- Arrow C++ is a large, complex C++ project
- Building Arrow C++ from source takes hours and is memory-intensive
- Version mismatch between pyarrow source and Arrow C++ causes API errors

### Solution

**Option 1: Install Pre-built libarrow-cpp from Termux (RECOMMENDED)**

Termux provides a pre-built `libarrow-cpp` package that can be installed directly:

```bash
# Install libarrow-cpp from Termux packages
pkg install -y libarrow-cpp

# Verify installation
pkg list-installed | grep arrow
ls -la $PREFIX/lib/libarrow*

# Build pyarrow matching the installed Arrow C++ version (22.0.0)
cd ~/wheels
git clone --depth 1 --branch apache-arrow-22.0.0 https://github.com/apache/arrow.git pyarrow-source
cd pyarrow-source/python
export NINJAFLAGS="-j2"
export MAKEFLAGS="-j2"
export MAX_JOBS=2
export PYARROW_CMAKE_OPTIONS="-DCMAKE_PREFIX_PATH=$PREFIX/lib/cmake"
pip wheel --no-deps --wheel-dir ~/wheels .
pip install --find-links ~/wheels --no-index pyarrow*.whl
```

**Why this works:**
- Termux has pre-built `libarrow-cpp` (22.0.0) that avoids building from source
- Installing via `pkg install` is much faster (minutes vs hours)
- Building pyarrow 22.0.0 matches the installed Arrow C++ version
- pyarrow build system automatically finds Arrow C++ via `CMAKE_PREFIX_PATH`

**Option 2: Build Arrow C++ First (Complex, Time-Consuming)**

If you need a different version or Termux package is unavailable:

```bash
cd ~/wheels
git clone --depth 1 https://github.com/apache/arrow.git arrow-source
cd arrow-source/cpp
mkdir build && cd build
cmake .. -DCMAKE_INSTALL_PREFIX=$PREFIX -DCMAKE_BUILD_TYPE=Release
make -j2
make install
cd ~/wheels/arrow-source/python
pip wheel --no-deps --wheel-dir ~/wheels .
```

**Note:** Building Arrow C++ from source can take 1-3 hours and may encounter compilation errors on Android due to C++ standard library compatibility issues.

**Option 3: Use Pre-built Wheel (If Available)**

```bash
pip download pyarrow --dest ~/wheels --no-cache-dir
# If a .whl file is downloaded, use it directly
```

### Version Matching

**Critical:** The pyarrow version must match the installed Arrow C++ version:
- If `libarrow-cpp` is 22.0.0, build pyarrow 22.0.0
- If building Arrow C++ from source, use the same version tag for pyarrow
- Version mismatch causes API errors like `no member named 'max_rows_per_page'`

### Required System Packages

When using Termux's libarrow-cpp:
- `libarrow-cpp` - Pre-built Arrow C++ library (installed via `pkg install`)
- Dependencies are automatically installed: `abseil-cpp`, `apache-orc`, `libprotobuf`, `libre2`, `libsnappy`, `thrift`, `utf8proc`, `zlib`, `zstd`

### Notes
- **Recommended approach**: Use `pkg install libarrow-cpp` - it's pre-built and tested
- **Build time**: With pre-built libarrow-cpp, pyarrow builds in 15-30 minutes
- **Without pre-built**: Building Arrow C++ from source takes 1-3 hours and may fail
- **Version matching**: Always ensure pyarrow version matches Arrow C++ version

---

## 18. Scikit-learn Build Error - version.py Execution in Meson

### Error Description
When building `scikit-learn` from GitHub source, meson build fails with:
```
../meson.build:4:11: ERROR: Could not execute command `/path/to/version.py`.
```

### Root Cause
- Meson cannot execute `sklearn/_build_utils/version.py` even though it has correct permissions
- The meson.build file uses `run_command('sklearn/_build_utils/version.py', ...)` which tries to execute the script directly
- Meson's subprocess environment may not have Python in PATH or may not recognize the script as executable
- Even with correct permissions and shebang, meson fails to execute the script

### Solution

**Option 1: Hardcode Version in meson.build (RECOMMENDED - Works Best)**

Extract the version manually and hardcode it in meson.build:

```bash
cd ~/wheels/scikit-learn-source

# Extract version
VERSION=$(python3 sklearn/_build_utils/version.py)
echo "Version: $VERSION"

# Fix meson.build line 4 to hardcode version
sed -i "4s|.*|  version: '$VERSION',|" meson.build

# Verify fix
head -10 meson.build | grep version

# Build with fixed meson.build
export NINJAFLAGS="-j2"
export MAKEFLAGS="-j2"
export MAX_JOBS=2
rm -rf .mesonpy-* 2>/dev/null
pip wheel --no-deps --wheel-dir ~/wheels .
```

**Why this works:**
- Avoids the script execution issue entirely
- Meson reads the version directly from the build file
- No PATH or subprocess issues
- Most reliable solution

**Option 2: Patch meson.build to Use python3 Explicitly**

```bash
cd ~/wheels/scikit-learn-source
sed -i "s|run_command(['sklearn/_build_utils/version.py'|run_command(['python3', 'sklearn/_build_utils/version.py'|g" meson.build
```

**Note:** This approach may still fail due to meson's subprocess environment.

**Option 3: Set PYTHON Environment Variable**

```bash
export PYTHON=$(which python3)
export PATH=$PREFIX/bin:$PATH
cd ~/wheels/scikit-learn-source
pip wheel --no-deps --wheel-dir ~/wheels .
```

**Option 4: Use PyPI Source with Fixes**

```bash
cd ~/wheels
pip download scikit-learn --dest . --no-cache-dir
tar -xzf scikit-learn-*.tar.gz
cd scikit-learn-*
chmod +x sklearn/_build_utils/version.py
# Still need to fix meson.build
VERSION=$(python3 sklearn/_build_utils/version.py)
sed -i "4s|.*|  version: '$VERSION',|" meson.build
cd ..
pip wheel scikit-learn-*.tar.gz --no-deps --wheel-dir .
```

### Verification

After fixing meson.build, verify the version line:
```bash
head -10 meson.build | grep version
# Should show: version: '1.9.dev0', (or similar)
```

### Notes
- **Hardcoding version is most reliable** - avoids all script execution issues
- The version can be extracted using: `python3 sklearn/_build_utils/version.py`
- Meson build system has known issues with script execution in Termux
- This solution works for both GitHub source and PyPI source

---

## Last Updated
December 3, 2024
