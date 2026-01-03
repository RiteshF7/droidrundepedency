# Droidrun Essential Files Analysis Report

## Executive Summary

**Current Installation Size:** 1.7GB (after initial cleanup)

**Essential Runtime Size:** ~726MB (Python packages)
**Optional/Removable:** ~974MB

---

## Essential Components (MUST KEEP)

### 1. Python Packages (726MB) - **REQUIRED**
Location: `$PREFIX/lib/python3.12/site-packages/`

**Core Droidrun Dependencies:**
- `droidrun/` - Main package
- `numpy/` - Numerical computing (~45MB)
- `scipy/` - Scientific computing (~107MB)
- `pandas/` - Data manipulation (~84MB)
- `sklearn/` - Machine learning (~69MB)
- `pillow/` - Image processing
- `grpcio/` - gRPC communication
- `pydantic/` + `pydantic_core/` - Data validation
- `pyarrow/` - Columnar data (~31MB)
- `psutil/` - System utilities
- `joblib/` - Parallel processing
- `threadpoolctl/` - Thread pool control
- `fastapi/` - Web framework
- `aiohttp/` - Async HTTP
- `llama_index/` - LLM integration (~37MB)
- `phoenix/` - Observability (~25MB)

**Total Essential Packages:** ~726MB

### 2. System Libraries (Required)
Location: `$PREFIX/lib/`

- Shared libraries (`.so` files) - 387 files
- Required for Python extensions to work
- Includes: libopenblas, libarrow, libjpeg, libpng, etc.

### 3. Python Runtime
- Python 3.12 interpreter
- Standard library
- Essential binaries in `$PREFIX/bin/`

### 4. System Binaries (Essential)
- `python3`, `pip3` - Required
- Termux core utilities

---

## Optional Components (CAN BE REMOVED)

### 1. Build-Time Files

#### Headers (`$PREFIX/include/`) - **~288MB** ✅ REMOVABLE
- C/C++ header files
- Only needed for compilation
- **Safe to remove:** Yes
- **Impact:** None (runtime)

#### Rust Libraries (`$PREFIX/lib/rustlib/`) - **~126MB** ✅ REMOVABLE
- Rust standard library
- Only needed for building Rust packages
- **Safe to remove:** Yes (if not building)
- **Impact:** None (runtime)

#### Build Tools
- `clang`, `clang++` - C/C++ compiler
- `rust`, `rustc`, `cargo` - Rust compiler
- `autoconf`, `automake`, `libtool` - Build system
- `patchelf` - ELF binary patcher
- `flang` - Fortran compiler
- `maturin` - Rust-Python bridge builder
- `Cython` - Python to C compiler
- `meson-python` - Build backend

**Total Build Tools:** ~200-300MB

### 2. Documentation (~96MB) ✅ REMOVABLE

#### Manual Pages (`$PREFIX/share/man/`) - **~59MB**
- Command documentation
- **Safe to remove:** Yes
- **Impact:** Can't use `man` command

#### Documentation (`$PREFIX/share/doc/`) - **~27MB**
- Package documentation
- **Safe to remove:** Yes
- **Impact:** No documentation files

#### Info Pages (`$PREFIX/share/info/`) - **~10MB**
- GNU info documentation
- **Safe to remove:** Yes
- **Impact:** Can't use `info` command

### 3. Test Files (~60MB) ✅ REMOVABLE

Location: `$PREFIX/lib/python3.12/site-packages/*/test*/`

**Largest test directories:**
- `pandas/tests/` - ~46MB
- `pyarrow/tests/` - ~6.6MB
- `nltk/test/` - ~2.6MB
- `setuptools/tests/` - ~2.0MB
- `sklearn/tests/` - ~1.6MB
- Others - ~1.2MB

**Safe to remove:** Yes
**Impact:** Can't run package tests (not needed for runtime)

### 4. Build Artifacts

#### Meson Build Files (`mesonbuild/`) - **~12MB** ✅ REMOVABLE
- Build system files
- **Safe to remove:** Yes
- **Impact:** None (runtime)

#### Python Bytecode (`__pycache__/`, `*.pyc`) - **~10-20MB** ✅ REMOVABLE
- Compiled Python files
- Regenerated automatically
- **Safe to remove:** Yes
- **Impact:** Slight startup delay (regenerated on first import)

### 5. Examples (~5-10MB) ✅ REMOVABLE
- Example code in packages
- **Safe to remove:** Yes
- **Impact:** None

### 6. Cache Files (~3MB) ✅ REMOVABLE
- `~/.cache/` - User cache
- **Safe to remove:** Yes
- **Impact:** Cache regenerated as needed

---

## Space Savings Summary

| Category | Size | Removable | Priority |
|----------|------|-----------|----------|
| **Headers** | ~288MB | ✅ Yes | High |
| **Rust Libraries** | ~126MB | ✅ Yes | High |
| **Documentation** | ~96MB | ✅ Yes | Medium |
| **Test Files** | ~60MB | ✅ Yes | Medium |
| **Build Tools** | ~200-300MB | ✅ Yes | High |
| **Meson Build** | ~12MB | ✅ Yes | Low |
| **Bytecode** | ~10-20MB | ✅ Yes | Low |
| **Examples** | ~5-10MB | ✅ Yes | Low |
| **Cache** | ~3MB | ✅ Yes | Low |
| **TOTAL REMOVABLE** | **~800-900MB** | | |

---

## Minimum Required Size

**Essential Components Only:**
- Python packages: ~726MB
- System libraries: ~400-500MB
- Python runtime: ~50-100MB
- Essential binaries: ~50-100MB
- **Total Minimum: ~1.2-1.4GB**

**Current Size:** 1.7GB
**Potential Minimum:** ~1.2-1.4GB
**Savings Potential:** ~300-500MB

---

## Recommendations

### Priority 1 (High Impact, Safe)
1. Remove headers (`$PREFIX/include/`) - **288MB**
2. Remove Rust libraries (`$PREFIX/lib/rustlib/`) - **126MB**
3. Remove build tools - **200-300MB**

**Total Priority 1 Savings: ~614-714MB**

### Priority 2 (Medium Impact, Safe)
4. Remove documentation - **96MB**
5. Remove test files - **60MB**

**Total Priority 2 Savings: ~156MB**

### Priority 3 (Low Impact, Safe)
6. Remove bytecode - **10-20MB**
7. Remove examples - **5-10MB**
8. Remove cache - **3MB**

**Total Priority 3 Savings: ~18-33MB**

---

## Final Size Estimates

| Scenario | Size | Savings |
|----------|------|---------|
| **Current** | 1.7GB | - |
| **After Priority 1** | ~1.0GB | ~700MB |
| **After Priority 1+2** | ~850MB | ~850MB |
| **After All Cleanup** | ~800MB | ~900MB |

---

## Conclusion

**For droidrun to work, you need:**
- ✅ Python packages (~726MB) - **ESSENTIAL**
- ✅ System libraries (~400-500MB) - **ESSENTIAL**
- ✅ Python runtime (~50-100MB) - **ESSENTIAL**
- ✅ Essential binaries (~50-100MB) - **ESSENTIAL**

**Total Essential: ~1.2-1.4GB**

**Everything else (~300-500MB) can be safely removed** without affecting droidrun functionality.

---

## Verification Commands

After cleanup, verify droidrun still works:
```bash
python3 -c "import droidrun, numpy, scipy, pandas, sklearn, pillow, grpcio; print('All essential packages OK')"
droidrun --version
```


