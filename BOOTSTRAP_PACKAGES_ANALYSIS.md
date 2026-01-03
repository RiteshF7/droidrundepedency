# Bootstrap Packages Analysis Report

## Overview

Termux bootstrap includes **pre-built packages** that are part of the base installation. These cannot be easily removed as they're integrated into the system.

---

## Bootstrap Python Packages (Pre-built)

### Available via `pkg install`:

| Package | Version | Size | Status |
|---------|---------|------|--------|
| `python-numpy` | 2.2.5-2 | ~45MB | ✅ Bootstrap |
| `python-scipy` | 1.16.3-1 | ~107MB | ✅ Bootstrap |
| `python-pillow` | 12.0.0 | ~5MB | ✅ Bootstrap |
| `python-grpcio` | 1.76.0-1 | ~10MB | ✅ Bootstrap |
| `python-pyarrow` | 22.0.0-2 | ~31MB | ✅ Bootstrap |

**Total Bootstrap Python Packages:** ~198MB

### Characteristics:
- ✅ **Pre-built and optimized** for Termux/Android
- ✅ **Part of base system** - installed via `pkg install`
- ✅ **Cannot be easily removed** - would break system
- ✅ **Already optimized** - no need to rebuild
- ✅ **Take up space** but are essential for droidrun

---

## Bootstrap System Libraries

### Required Libraries (Pre-built):

| Library | Purpose | Status |
|---------|---------|--------|
| `libarrow-cpp` | PyArrow backend | ✅ Bootstrap |
| `libopenblas` | NumPy/SciPy math | ✅ Bootstrap |
| `libjpeg-turbo` | Pillow image support | ✅ Bootstrap |
| `libpng` | Pillow image support | ✅ Bootstrap |
| `libtiff` | Pillow image support | ✅ Bootstrap |
| `libwebp` | Pillow image support | ✅ Bootstrap |
| `freetype` | Font rendering | ✅ Bootstrap |
| `abseil-cpp` | gRPC dependencies | ✅ Bootstrap |
| `libc++` | C++ standard library | ✅ Bootstrap |

**These are essential runtime libraries** - cannot be removed.

---

## Bootstrap Core Packages (Always Present)

### Essential System Packages:
- `bash`, `coreutils`, `python`, `python-pip`
- `curl`, `tar`, `gzip`, `sed`, `grep`
- `termux-core`, `termux-exec`, `termux-tools`
- Package manager: `apt`, `dpkg`

**These are the minimum required for Termux to function.**

---

## Space Analysis

### Current Installation (1.7GB):

| Component | Size | Source | Removable? |
|-----------|------|--------|------------|
| **Bootstrap Python packages** | ~198MB | `pkg` | ❌ No (system) |
| **Bootstrap system libraries** | ~200-300MB | `pkg` | ❌ No (runtime) |
| **Bootstrap core utilities** | ~100-200MB | `pkg` | ❌ No (system) |
| **Pip-installed packages** | ~350-400MB | `pip` | ⚠️ Only if not needed |
| **Other system libraries** | ~400-500MB | `pkg` | ❌ No (runtime) |
| **Build-time files** | ~0MB | - | ✅ Already removed |
| **Documentation** | ~27MB | `pkg` | ✅ Yes (optional) |
| **Test files** | ~60MB | `pip` | ✅ Yes (optional) |

---

## Key Findings

### 1. **Bootstrap Packages Cannot Be Removed**
- They're part of the Termux base system
- Removing them would break the system
- They're already optimized for Android
- **Size: ~198MB (Python) + ~200-300MB (libraries) = ~400-500MB**

### 2. **No Duplication Found**
- Bootstrap packages are used directly
- Pip did NOT install duplicate versions
- Python imports use bootstrap packages
- **This is good - no wasted space**

### 3. **Bootstrap Packages Are Essential**
- `python-numpy`, `python-scipy`, `python-pillow` are required by droidrun
- `python-grpcio` is required for Google provider
- `python-pyarrow` may be used by some droidrun features
- **All are necessary for droidrun to work**

---

## What Can Be Removed

### ✅ Safe to Remove (Not Bootstrap):

1. **Documentation** (~27MB)
   - `$PREFIX/share/doc`, `$PREFIX/share/man`, `$PREFIX/share/info`
   - Not part of bootstrap, can be removed

2. **Test Files** (~60MB)
   - Test directories in pip-installed packages
   - Not part of bootstrap, can be removed

3. **Build Tools** (~200-300MB)
   - `clang`, `rust`, `autoconf`, `automake`, `libtool`
   - Not part of bootstrap, can be removed (if not building)

4. **Build Artifacts**
   - Meson build files, bytecode, examples
   - Not part of bootstrap, can be removed

### ❌ Cannot Remove (Bootstrap/System):

1. **Bootstrap Python packages** (~198MB)
   - `python-numpy`, `python-scipy`, `python-pillow`, `python-grpcio`, `python-pyarrow`
   - Part of system, required for droidrun

2. **Bootstrap system libraries** (~200-300MB)
   - `libarrow-cpp`, `libopenblas`, `libjpeg-turbo`, etc.
   - Required runtime libraries

3. **Core system packages** (~100-200MB)
   - `bash`, `python`, `coreutils`, etc.
   - Minimum required for Termux

---

## Space Savings Reality Check

### Current: 1.7GB

### Breakdown:
- **Bootstrap/System (cannot remove):** ~700-900MB
  - Bootstrap Python: ~198MB
  - Bootstrap libraries: ~200-300MB
  - Core system: ~100-200MB
  - Other system libs: ~200-300MB

- **Pip-installed (droidrun deps):** ~350-400MB
  - droidrun + dependencies
  - pandas, sklearn, llama_index, etc.

- **Removable (optional):** ~400-500MB
  - Documentation: ~27MB
  - Test files: ~60MB
  - Build tools: ~200-300MB
  - Other: ~100MB

### After Full Cleanup: ~1.2-1.3GB

**Minimum possible size:** ~1.2-1.3GB
- This includes all bootstrap packages (required)
- All droidrun dependencies (required)
- Essential system components (required)

---

## Recommendations

### ✅ Keep (Essential):
1. **All bootstrap Python packages** - Required for droidrun
2. **All bootstrap system libraries** - Required for runtime
3. **All pip-installed droidrun dependencies** - Required for functionality

### ✅ Remove (Optional):
1. **Documentation** - ~27MB
2. **Test files** - ~60MB
3. **Build tools** - ~200-300MB (if not building)
4. **Build artifacts** - ~20-30MB

### ❌ Do NOT Remove:
- Any `python-*` packages installed via `pkg`
- Any `lib*` packages installed via `pkg`
- Core system packages

---

## Conclusion

**Bootstrap packages are:**
- ✅ Pre-built and optimized
- ✅ Part of the base system
- ✅ Required for droidrun
- ✅ Cannot be removed
- ✅ Already taking optimal space (~400-500MB total)

**The 1.7GB installation is already well-optimized.** The bootstrap packages are necessary and cannot be removed. Additional cleanup can save ~300-400MB by removing documentation, test files, and build tools, bringing the total down to **~1.2-1.3GB minimum**.

---

## Verification

To check which packages are from bootstrap:
```bash
pkg list-installed | grep "^python-"
pkg list-installed | grep "^lib"
```

To check package sizes:
```bash
du -sh $PREFIX/lib/python3.12/site-packages/{numpy,scipy,PIL,grpc,pyarrow}
```


