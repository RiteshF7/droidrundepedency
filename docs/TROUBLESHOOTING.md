# Troubleshooting Guide

Common errors and solutions when building wheels for Android/Termux.

## Quick Reference

| Error | Solution |
|-------|----------|
| "autoreconf: inaccessible or not found" | `pkg install -y autoconf` |
| "Permission denied" writing to /tmp | Use `~/wheels` instead of `/tmp` |
| "gcc: command not found" | Use `clang` (Termux doesn't have gcc) |
| "Rust not found" | `pkg install -y rust` |
| "Unknown compiler(s): [['gfortran']]" | `pkg install -y flang blas-openblas && ln -sf $PREFIX/bin/flang $PREFIX/bin/gfortran` |
| System unresponsive during build | Set `export NINJAFLAGS="-j2" && export MAKEFLAGS="-j2"` |
| "RequiredDependencyException: jpeg" | `pkg install -y libjpeg-turbo libpng libtiff libwebp freetype` |
| "Could not execute version.py" | See scikit-learn fixes below |
| "CMake Error: Could not find Arrow" | `pkg install -y libarrow-cpp` |

## Common Issues

### Memory Exhaustion

**Symptoms**: System becomes unresponsive, high memory usage, swap full

**Solution**: Limit parallelism before building

```bash
export NINJAFLAGS="-j2"
export MAKEFLAGS="-j2"
export MAX_JOBS=2
```

### Missing Build Tools

**Symptoms**: Build fails with "command not found" errors

**Solution**: Install all build dependencies

```bash
pkg install -y autoconf automake libtool make binutils clang cmake ninja rust flang blas-openblas
```

### Package-Specific Issues

#### pandas

**Issue**: Meson build fails with version detection error

**Fix**: Automatically handled by build script. The script fixes `meson.build` line 5 to hardcode version.

#### scikit-learn

**Issue**: Meson cannot execute version.py

**Fix**: Automatically handled by build script. The script:
1. Adds shebang to version.py
2. Fixes meson.build to hardcode version

#### grpcio

**Issue**: Runtime import errors, missing abseil libraries

**Fix**: Automatically handled by build script. The script patches the wheel post-build to:
1. Add abseil library dependencies
2. Set RPATH
3. Configure LD_LIBRARY_PATH

#### pyarrow

**Issue**: CMake cannot find Arrow C++ libraries

**Solution**: Install pre-built libarrow-cpp

```bash
pkg install -y libarrow-cpp
```

#### pillow

**Issue**: Missing JPEG/image library headers

**Solution**: Install image libraries

```bash
pkg install -y libjpeg-turbo libpng libtiff libwebp freetype
```

## Detailed Solutions

For comprehensive error documentation, see the original troubleshooting document in the archive or refer to `DEPENDENCIES.md` which contains detailed solutions for all known issues.

## Getting Help

1. Check this troubleshooting guide
2. Review `DEPENDENCIES.md` for detailed solutions
3. Check build logs in `~/wheels/build-all-wheels.log`
4. Verify system dependencies are installed
5. Ensure build environment variables are set correctly

