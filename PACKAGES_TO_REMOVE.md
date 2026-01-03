# Packages That Can Be Safely Removed

## Analysis of `pkg list-installed` Output

Based on your installed packages, here are the categories:

---

## ✅ SAFE TO REMOVE (Build-Time Only)

### Compilers and Build Tools:
```bash
pkg remove -y \
  clang \
  llvm \
  lld \
  mlir \
  cmake \
  ninja \
  make \
  m4 \
  rust-std-x86-64-linux-android
```

**Estimated savings:** ~300-500MB

**Note:** If you have `rust`, `autoconf`, `automake`, `libtool`, `patchelf`, `flang` installed, remove those too:
```bash
pkg remove -y rust autoconf automake libtool patchelf flang
```

---

## ✅ SAFE TO REMOVE (Optional Tools)

### Development Tools (if not using):
```bash
# Git (if not using version control)
pkg remove -y git

# Android tools (if not using ADB from Termux)
pkg remove -y android-tools

# Text editor (if using vim/other)
pkg remove -y nano

# Perl (if not needed)
pkg remove -y perl
```

**Estimated savings:** ~50-100MB

---

## ✅ AUTO-REMOVABLE (Can Remove)

These are marked as `[installed,auto-removable]` - safe to remove:

```bash
pkg remove -y \
  libandroid-complex-math-static \
  libandroid-complex-math \
  libltdl \
  m4 \
  mlir \
  rust-std-x86-64-linux-android
```

**Estimated savings:** ~50-100MB

---

## ❌ DO NOT REMOVE (Essential)

### Core Termux (Required for system):
- `bash`, `coreutils`, `python`, `python-pip`
- `apt`, `dpkg`
- `termux-core`, `termux-exec`, `termux-tools`, `termux-keyring`
- `curl`, `tar`, `gzip`, `sed`, `grep`, `findutils`, etc.

### Essential for Droidrun:
- `python-numpy`, `python-scipy`, `python-pillow`, `python-grpcio`, `python-pyarrow`
- `libarrow-cpp`, `libopenblas`
- `libjpeg-turbo`, `libpng`, `libtiff`, `libwebp`, `freetype`
- `abseil-cpp`, `libprotobuf`, `c-ares`, `libre2`

### Runtime Libraries (Required):
- `libc++`, `libcrypt`, `libffi`, `libsqlite`
- `openssl`, `zlib`, `libbz2`, `liblzma`
- All `lib*` packages that are dependencies

---

## Recommended Removal Commands

### Step 1: Remove Build Tools (Highest Priority)
```bash
pkg remove -y clang llvm lld mlir cmake ninja make m4 rust-std-x86-64-linux-android
```

### Step 2: Remove Auto-Removable Packages
```bash
pkg remove -y libandroid-complex-math-static libandroid-complex-math libltdl
```

### Step 3: Remove Optional Tools (if not using)
```bash
# Only if you don't use these:
pkg remove -y git android-tools nano perl
```

### Step 4: Check for Rust (if installed)
```bash
# If rust is installed and you're not building:
pkg remove -y rust
```

---

## Expected Space Savings

| Category | Packages | Estimated Savings |
|----------|----------|-------------------|
| **Build Tools** | clang, llvm, cmake, ninja, make | ~300-500MB |
| **Auto-Removable** | Various | ~50-100MB |
| **Optional Tools** | git, android-tools, nano, perl | ~50-100MB |
| **Total Potential** | | **~400-700MB** |

---

## Verification After Removal

After removing packages, verify droidrun still works:
```bash
python3 -c "import droidrun, numpy, scipy, pandas, sklearn, pillow, grpcio; print('All OK')"
droidrun --version
```

---

## Complete Removal Script (One Command)

```bash
# Remove all build tools and optional packages
pkg remove -y \
  clang llvm lld mlir cmake ninja make m4 \
  rust-std-x86-64-linux-android \
  libandroid-complex-math-static libandroid-complex-math libltdl \
  git android-tools nano perl 2>/dev/null || true
```

**Note:** Some packages might have dependencies, so run individually if the batch command fails.

---

## Summary

**Safe to remove:**
- ✅ Build tools: ~300-500MB
- ✅ Auto-removable: ~50-100MB  
- ✅ Optional tools: ~50-100MB

**Total removable:** ~400-700MB

**Must keep:**
- ❌ All `python-*` packages
- ❌ All `lib*` packages (runtime dependencies)
- ❌ Core Termux packages
- ❌ Essential utilities


