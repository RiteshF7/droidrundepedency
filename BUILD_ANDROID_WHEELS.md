# Building Python Wheels for Android x86_64

## Overview

This document explains how we built the `orjson` wheel for Android x86_64 using the existing Termux build system.

## Approach

We use the **Termux build system** (`termux-packages`) which already has the infrastructure for cross-compiling Python packages to Android.

## Files Used

1. **`termux-packages/packages/python-orjson/build.sh`** - The build script (follows Termux package pattern)
2. **`build_orjson_using_termux.sh`** - Wrapper script that sets up environment and calls build.sh

## Key Steps

### 1. Setup Environment
- Find Android NDK in SDK directory
- Set `TERMUX_ARCH=x86_64`
- Configure Rust target: `x86_64-linux-android`
- Point Cargo to use Android NDK compiler

### 2. The Problem: Missing Libraries
PyO3 (Rust-Python bridge) tries to link against:
- `libpython3.12.so` 
- `libunwind.so`

These don't exist during cross-compilation but will be available at runtime on Android.

### 3. The Fix: Stub Libraries
Create empty stub libraries that satisfy the linker:
```bash
# Create empty stub
echo "void stub() {}" > stub.c
$CC -shared -o libpython3.12.so stub.c
$CC -shared -o libunwind.so stub.c

# Add to library search path
export LIBRARY_PATH="$STUB_LIB_DIR:$LIBRARY_PATH"
```

The linker finds these stubs during build, but at runtime Android will use the real libraries.

### 4. Build Process
1. Download orjson source from PyPI
2. Run `termux_step_pre_configure()` - sets up Rust and maturin
3. Run `termux_step_make()` - builds wheel with maturin
4. Copy wheel to `wheels/` directory

## Build Command

```bash
./build_orjson_using_termux.sh
```

## Output

Wheel file: `wheels/orjson-3.11.5-cp312-cp312-linux_x86_64.whl`

## Why This Works

- **Termux build.sh pattern**: Reuses proven cross-compilation setup
- **Stub libraries**: Tricks linker into thinking libraries exist
- **Maturin**: Handles Rust-to-Python compilation for Android target
- **Runtime linking**: Real Python libraries available when wheel runs on Android

## For Other Packages

To build other Rust-based Python packages:
1. Create `termux-packages/packages/python-<package>/build.sh` following the same pattern
2. Use the same stub library approach
3. Adjust package-specific build steps as needed


