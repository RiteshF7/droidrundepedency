# droidrun Dependencies - Complete Guide

## System Dependencies

```bash
pkg install -y python python-pip autoconf automake libtool make binutils clang cmake ninja rust flang blas-openblas libjpeg-turbo libpng libtiff libwebp freetype libarrow-cpp openssl libc++ zlib protobuf libprotobuf abseil-cpp c-ares libre2 patchelf
ln -sf $PREFIX/bin/flang $PREFIX/bin/gfortran
```

**Package Notes:**
- **python, python-pip**: Python runtime and package manager
- **autoconf, automake, libtool, make, binutils**: Build tools required for compiling packages
- **clang, cmake, ninja**: Compilers and build systems
- **rust**: Required for building Rust-based packages (e.g., jiter)
- **flang**: Fortran compiler (linked as gfortran for numpy/scipy)
- **blas-openblas**: BLAS library for numpy/scipy/scikit-learn
- **libjpeg-turbo, libpng, libtiff, libwebp, freetype**: Image libraries required for Pillow
- **libarrow-cpp**: Required for building pyarrow from source (if no pre-built wheel available)
- **openssl, libc++, zlib**: Core system libraries
- **protobuf, libprotobuf**: Protocol buffers (required for grpcio)
- **abseil-cpp**: Required for grpcio (used by grpcio build system)
- **c-ares, libre2**: Required for grpcio (network and regex libraries)
- **patchelf**: Required for fixing grpcio wheel after building (adds abseil library dependencies to .so files)

## Build Environment Setup

**Required environment variables for successful builds:**

```bash
# Set PREFIX if not already set (Termux default)
export PREFIX=${PREFIX:-/data/data/com.termux/files/usr}

# Build parallelization (limit to 2 jobs to avoid memory issues)
export NINJAFLAGS="-j2"
export MAKEFLAGS="-j2"
export MAX_JOBS=2

# CMAKE configuration (required for patchelf and other CMake-based builds)
export CMAKE_PREFIX_PATH=$PREFIX
export CMAKE_INCLUDE_PATH=$PREFIX/include

# Compiler environment variables
export CC=$PREFIX/bin/clang
export CXX=$PREFIX/bin/clang++

# Temporary directory (fixes compiler permission issues)
export TMPDIR=$HOME/tmp
mkdir -p $TMPDIR

# Ensure wheels directory exists
mkdir -p ~/wheels
```

**Note:** These environment variables should be set before building any packages. They fix common issues including:
- CMake not finding Android headers (`/include/android/api-level.h` error)
- Compiler unable to create temporary files (permission denied)
- Build system configuration problems

## Build Order

### Phase 1: Build Tools (Pure Python)
```
Cython → numpy, scipy, pandas, scikit-learn
meson-python<0.19.0,>=0.16.0 → pandas, scikit-learn
maturin<2,>=1.9.4 → jiter
```

**Install:**
```bash
pip install Cython "meson-python<0.19.0,>=0.16.0" "maturin<2,>=1.9.4"
```

### Phase 2: Foundation
```
numpy → scipy, pandas, scikit-learn, pyarrow
patchelf → numpy (optional, usually has wheel)
```

**Prerequisites:**
```bash
# Ensure build environment is set up (see "Build Environment Setup" section above)
# Install system patchelf package (avoids Python patchelf build issues)
pkg install -y patchelf

# Ensure all build environment variables are set (see "Build Environment Setup" section)
export PREFIX=${PREFIX:-/data/data/com.termux/files/usr}
export CMAKE_PREFIX_PATH=$PREFIX
export CMAKE_INCLUDE_PATH=$PREFIX/include
export CC=$PREFIX/bin/clang
export CXX=$PREFIX/bin/clang++
export TMPDIR=$HOME/tmp
mkdir -p $TMPDIR
```

**Build:**
```bash
cd ~/wheels
pip download numpy --dest . --no-cache-dir
pip wheel numpy --no-deps --wheel-dir .
pip install --find-links . --no-index numpy*.whl
```

### Phase 3: Scientific Stack
```
scipy → scikit-learn
pandas<2.3.0 → llama-index-readers-file
scikit-learn → arize-phoenix
```

**Build scipy:**

**Prerequisites:**
```bash
# numpy must be installed first (from Phase 2)
# Ensure build environment is set up (see "Build Environment Setup" section)
export PREFIX=${PREFIX:-/data/data/com.termux/files/usr}
export NINJAFLAGS="-j2"
export MAKEFLAGS="-j2"
export MAX_JOBS=2
```

**Build:**
```bash
pip download "scipy>=1.8.0,<1.17.0" --dest . --no-cache-dir
pip wheel scipy --no-deps --wheel-dir .
pip install --find-links . --no-index scipy*.whl
```

**Build pandas (fix meson.build line 5: `version: '2.2.3'`):**

**Prerequisites:**
```bash
# numpy must be installed first (from Phase 2)
# meson-python must be installed (from Phase 1)
# Ensure build environment is set up (see "Build Environment Setup" section)
```

**Build steps:**
```bash
cd ~/wheels
pip download "pandas<2.3.0" --dest . --no-cache-dir

# Fix meson.build version detection issue
# Extract tarball, fix meson.build, then repackage
tar -xzf pandas-2.2.3.tar.gz
sed -i "s/version: run_command.*/version: '2.2.3',/" pandas-2.2.3/meson.build
tar -czf pandas-2.2.3.tar.gz pandas-2.2.3/

# Build wheel from fixed tarball
pip wheel pandas-2.2.3.tar.gz --no-deps --wheel-dir .

# Install the wheel
pip install --find-links . --no-index pandas*.whl
```

**Note:** The meson.build file uses `run_command(['generate_version.py', '--print'], ...)` which fails in Termux. The fix replaces this with the hardcoded version `'2.2.3'`.

**Build scikit-learn (use pre-fixed tarball from GitHub + --no-build-isolation):**

**Prerequisites:**
```bash
# numpy and scipy must be installed first (from Phase 2 and Phase 3)
# meson-python must be installed (from Phase 1)
# Ensure build environment is set up (see "Build Environment Setup" section)
```

**Build steps:**
```bash
cd ~/wheels
# Download pre-fixed tarball from GitHub (already has version.py shebang and meson.build fixes)
pip wheel https://raw.githubusercontent.com/RiteshF7/termux-packages/master/tmp_scikit_fixed.tar.gz --no-deps --no-build-isolation --wheel-dir .

# Install missing dependencies first (required before installing scikit-learn)
pip install joblib>=1.3.0 threadpoolctl>=3.2.0

# Install the wheel
pip install --find-links . --no-index scikit_learn*.whl
```

**Alternative (if you need to fix locally):**
```bash
pip download scikit-learn --dest . --no-cache-dir
# Fix sklearn/_build_utils/version.py: add `#!/usr/bin/env python3`
# Fix meson.build line 4: use extracted version
pip wheel scikit-learn --no-deps --no-build-isolation --wheel-dir .
pip install joblib>=1.3.0 threadpoolctl>=3.2.0
pip install --find-links . --no-index scikit-learn*.whl
```

### Phase 4: Rust Packages
```
jiter==0.12.0 → arize-phoenix
```

**Build:**

**Prerequisites:**
```bash
# maturin must be installed (from Phase 1)
# rust must be installed (system dependency)
```

**Build:**
```bash
pip download jiter==0.12.0 --dest . --no-cache-dir
pip wheel jiter --no-deps --wheel-dir .
pip install --find-links . --no-index jiter*.whl
```

### Phase 5: Other Compiled
```
pyarrow → arize-phoenix (needs libarrow-cpp)
psutil → arize-phoenix
grpcio → google-cloud packages (needs --no-build-isolation + env vars)
Pillow → image processing (needs libjpeg-turbo, libpng, etc.)
```

**Build pyarrow:**
```bash
pip download pyarrow --dest . --no-cache-dir
# Note: pyarrow usually has a pre-built wheel available, try installing directly first
pip install --find-links . --no-index pyarrow*.whl 2>/dev/null || {
    # If no wheel, build from source (requires libarrow-cpp system package)
    # Ensure libarrow-cpp is installed: pkg install -y libarrow-cpp
    # Set build environment variables
    export PREFIX=${PREFIX:-/data/data/com.termux/files/usr}
    export CMAKE_PREFIX_PATH=$PREFIX
    export CMAKE_INCLUDE_PATH=$PREFIX/include
    export ARROW_HOME=$PREFIX
    export CC=$PREFIX/bin/clang
    export CXX=$PREFIX/bin/clang++
    pip wheel pyarrow --no-deps --wheel-dir .
    pip install --find-links . --no-index pyarrow*.whl
}
```

**Build from source (if wheel not available for your architecture):**
```bash
# Prerequisites: Install system dependencies
pkg install -y libarrow-cpp

# Set build environment
export PREFIX=${PREFIX:-/data/data/com.termux/files/usr}
export CMAKE_PREFIX_PATH=$PREFIX
export CMAKE_INCLUDE_PATH=$PREFIX/include
export ARROW_HOME=$PREFIX
export CC=$PREFIX/bin/clang
export CXX=$PREFIX/bin/clang++
export TMPDIR=$HOME/tmp
mkdir -p $TMPDIR

# Download and build
pip download pyarrow --dest . --no-cache-dir
pip wheel pyarrow --no-deps --wheel-dir .
pip install --find-links . --no-index pyarrow*.whl
```

**Build psutil:**

**Prerequisites:**
```bash
# No special prerequisites required
# Ensure build environment is set up (see "Build Environment Setup" section)
```

**Build:**
```bash
pip download psutil --dest . --no-cache-dir
pip wheel psutil --no-deps --wheel-dir .
pip install --find-links . --no-index psutil*.whl
```

**Build grpcio (prerequisites + build + patch wheel):**

**Prerequisites:**
```bash
# Ensure patchelf is installed (required for fixing the wheel)
pkg install -y patchelf

# Ensure abseil-cpp is installed (required system dependency)
pkg install -y abseil-cpp

# Set PREFIX
export PREFIX=${PREFIX:-/data/data/com.termux/files/usr}
```

**Build steps:**
```bash
# Step 1: Set GRPC build flags to use system libraries
export GRPC_PYTHON_BUILD_SYSTEM_OPENSSL=1 GRPC_PYTHON_BUILD_SYSTEM_ZLIB=1 GRPC_PYTHON_BUILD_SYSTEM_CARES=1 GRPC_PYTHON_BUILD_SYSTEM_RE2=1 GRPC_PYTHON_BUILD_SYSTEM_ABSL=1 GRPC_PYTHON_BUILD_WITH_CYTHON=1

# Step 2: Download and build wheel
pip download grpcio --dest . --no-cache-dir
pip wheel grpcio --no-deps --no-build-isolation --wheel-dir .

# Step 3: CRITICAL - Fix the wheel to add abseil library dependencies
WHEEL_FILE=$(ls grpcio-*.whl | head -1)
echo "Fixing wheel: $WHEEL_FILE"

# Extract wheel
unzip -q "$WHEEL_FILE" -d grpcio_extract

# Find and patch the .so file
SO_FILE=$(find grpcio_extract -name "cygrpc*.so" | head -1)
if [ -z "$SO_FILE" ]; then
    echo "Error: cygrpc*.so not found in wheel"
    exit 1
fi

# Add abseil libraries to NEEDED list and set RPATH
patchelf --add-needed libabsl_flags_internal.so "$SO_FILE"
patchelf --add-needed libabsl_flags.so "$SO_FILE"
patchelf --add-needed libabsl_flags_commandlineflag.so "$SO_FILE"
patchelf --add-needed libabsl_flags_reflection.so "$SO_FILE"
patchelf --set-rpath "$PREFIX/lib" "$SO_FILE"

# Repackage the wheel
cd grpcio_extract
python3 << 'PYEOF'
import zipfile
import os
zf = zipfile.ZipFile('../grpcio-fixed.whl', 'w', zipfile.ZIP_DEFLATED)
for root, dirs, files in os.walk('.'):
    for file in files:
        filepath = os.path.join(root, file)
        arcname = os.path.relpath(filepath, '.')
        zf.write(filepath, arcname)
zf.close()
print('Fixed wheel created: grpcio-fixed.whl')
PYEOF
cd ..

# Replace original wheel with fixed one
rm -rf grpcio_extract
rm "$WHEEL_FILE"
mv grpcio-fixed.whl "$WHEEL_FILE"
echo "Wheel fixed and ready for installation"

# Step 4: Install the fixed wheel
pip install --find-links . --no-index grpcio*.whl

# Step 5: Set LD_LIBRARY_PATH for runtime (REQUIRED for grpcio to work)
export LD_LIBRARY_PATH=$PREFIX/lib:$LD_LIBRARY_PATH
# Add to ~/.bashrc for permanent fix (so it's set in all future sessions)
if ! grep -q "LD_LIBRARY_PATH.*PREFIX/lib" ~/.bashrc 2>/dev/null; then
    echo "export LD_LIBRARY_PATH=\$PREFIX/lib:\$LD_LIBRARY_PATH" >> ~/.bashrc
fi
echo "LD_LIBRARY_PATH configured. Restart terminal or run: source ~/.bashrc"
```

**Build Pillow:**

**Prerequisites:**
```bash
# Ensure libjpeg-turbo and other image libraries are installed
pkg install -y libjpeg-turbo libpng libtiff libwebp freetype
```

**Build steps:**
```bash
# Set build environment variables
export PREFIX=${PREFIX:-/data/data/com.termux/files/usr}
export PKG_CONFIG_PATH=$PREFIX/lib/pkgconfig:$PKG_CONFIG_PATH
export LDFLAGS="-L$PREFIX/lib"
export CPPFLAGS="-I$PREFIX/include"

# Download and build
pip download pillow --dest . --no-cache-dir
pip wheel pillow --no-deps --wheel-dir .
pip install --find-links . --no-index pillow*.whl
```

**Note:** Pillow requires libjpeg-turbo headers to build. If build fails with "jpeg headers not found", ensure `libjpeg-turbo` is installed via `pkg install -y libjpeg-turbo`.

### Phase 6: Additional Compiled (if needed)
```
tokenizers → transformers → llama-index-llms-deepseek (may have wheel)
safetensors → transformers (may have wheel)
cryptography → google-auth, authlib (may have wheel)
pydantic-core → pydantic (may have wheel)
orjson → fastapi, arize-phoenix (may have wheel)
```

**Prerequisites:**
```bash
# Ensure build environment is set up (see "Build Environment Setup" section)
# No special system dependencies required beyond standard build tools
```

**Check if wheels exist first, build only if needed:**
```bash
# These usually have pre-built wheels, try install first
# Note: pip install will automatically build wheels if no pre-built wheels are available
pip install tokenizers safetensors cryptography pydantic-core orjson || {
    # Manual build fallback (if pip install fails for other reasons)
    pip download tokenizers safetensors cryptography pydantic-core orjson --dest . --no-cache-dir
    pip wheel tokenizers --no-deps --wheel-dir . || true
    pip wheel safetensors --no-deps --wheel-dir . || true
    pip wheel cryptography --no-deps --wheel-dir . || true
    pip wheel pydantic-core --no-deps --wheel-dir . || true
    pip wheel orjson --no-deps --wheel-dir . || true
    pip install --find-links . --no-index tokenizers*.whl safetensors*.whl cryptography*.whl pydantic-core*.whl orjson*.whl
}
```

**Note:** These packages build successfully from source with standard build environment setup. No special fixes or prerequisites are required. If no pre-built wheels are available for your architecture, `pip install` will automatically build them.

### Phase 7: Main Package + LLM Providers

**Base droidrun (pure Python deps install automatically):**
```bash
cd ~
pip install 'droidrun' --find-links ~/wheels
```

**LLM Provider Extras (all pure Python):**
```bash
# Google
pip install 'droidrun[google]' --find-links ~/wheels

# Anthropic
pip install 'droidrun[anthropic]' --find-links ~/wheels

# OpenAI
pip install 'droidrun[openai]' --find-links ~/wheels

# DeepSeek
pip install 'droidrun[deepseek]' --find-links ~/wheels

# Ollama
pip install 'droidrun[ollama]' --find-links ~/wheels

# OpenRouter
pip install 'droidrun[openrouter]' --find-links ~/wheels

# All providers
pip install 'droidrun[google,anthropic,openai,deepseek,ollama,openrouter]' --find-links ~/wheels
```

## Complete Dependency Tree

```
droidrun
├── Core Dependencies (pure Python)
│   ├── async-adbutils → droidrun
│   ├── llama-index (0.14.4) → droidrun
│   ├── arize-phoenix (>=12.3.0) → droidrun
│   ├── llama-index-readers-file (<0.6, >=0.5.0) → droidrun
│   ├── llama-index-workflows (==2.8.3) → droidrun
│   ├── llama-index-callbacks-arize-phoenix (>=0.6.1) → droidrun
│   ├── httpx (>=0.27.0) → droidrun
│   ├── pydantic (>=2.11.10) → droidrun
│   ├── rich (>=14.1.0) → droidrun
│   ├── posthog (>=6.7.6) → droidrun
│   └── aiofiles (>=25.1.0) → droidrun
│
├── Compiled Dependencies (MUST BUILD - in order)
│   ├── numpy (>=1.26.0) → scipy, pandas, scikit-learn, pyarrow
│   ├── scipy (>=1.8.0,<1.17.0) → scikit-learn
│   ├── pandas (<2.3.0) → llama-index-readers-file
│   ├── scikit-learn (>=1.0.0) → arize-phoenix
│   ├── jiter (==0.12.0) → arize-phoenix
│   ├── pyarrow → arize-phoenix
│   ├── psutil → arize-phoenix
│   ├── grpcio → google-auth, opentelemetry packages
│   └── Pillow → image processing
│
├── Optional Compiled (check for wheels first)
│   ├── tokenizers → transformers → llama-index-llms-deepseek
│   ├── safetensors → transformers
│   ├── cryptography → google-auth, authlib
│   ├── pydantic-core → pydantic
│   └── orjson → fastapi, arize-phoenix
│
└── LLM Provider Extras (pure Python)
    ├── [google] → llama-index-llms-google-genai, google-genai
    ├── [anthropic] → anthropic, llama-index-llms-anthropic
    ├── [openai] → openai, llama-index-llms-openai, llama-index-llms-openai-like
    ├── [deepseek] → llama-index-llms-deepseek, transformers, huggingface-hub
    ├── [ollama] → llama-index-llms-ollama, ollama
    └── [openrouter] → llama-index-llms-openrouter
```

## Pure Python Dependencies (install automatically)

These install automatically with pip (no building needed):
- Core: aiofiles, httpx, pydantic, rich, posthog, anyio, aiohttp, aiohappyeyeballs
- llama-index ecosystem: llama-index-core, llama-index-cli, llama-index-embeddings-openai, llama-index-instrumentation, llama-index-indices-managed-llama-cloud, llama-index-readers-llama-parse
- LLM providers: anthropic, openai, ollama, google-genai, transformers, huggingface-hub
- Utilities: beautifulsoup4, pypdf, striprtf, banks, dirtyjson, filetype, tenacity, tqdm
- Web: fastapi, starlette, uvicorn, websockets, aiosqlite, aioitertools
- Data: python-dateutil, pytz, tzdata, six
- Auth: google-auth, authlib, cachetools, requests, certifi
- GraphQL: strawberry-graphql, graphql-core, alembic, sqlalchemy
- Observability: opentelemetry-*, openinference-*, prometheus-client
- Other: click, platformdirs, python-dotenv, networkx, nltk, jinja2, markupsafe, mako, pyyaml, regex, backoff, propcache, and 100+ more pure Python packages

## Quick Install Script

```bash
#!/bin/bash
set -e

# Build Environment Setup (REQUIRED - see "Build Environment Setup" section)
export PREFIX=${PREFIX:-/data/data/com.termux/files/usr}
export NINJAFLAGS="-j2" MAKEFLAGS="-j2" MAX_JOBS=2
export CMAKE_PREFIX_PATH=$PREFIX
export CMAKE_INCLUDE_PATH=$PREFIX/include
export CC=$PREFIX/bin/clang
export CXX=$PREFIX/bin/clang++
export TMPDIR=$HOME/tmp
mkdir -p $TMPDIR ~/wheels
cd ~/wheels

# Phase 1
pip install Cython "meson-python<0.19.0,>=0.16.0" "maturin<2,>=1.9.4"

# Phase 2 - Install patchelf system package (avoids Python patchelf build issues)
pkg install -y patchelf
pip download numpy --dest . --no-cache-dir && pip wheel numpy --no-deps --wheel-dir . && pip install --find-links . --no-index numpy*.whl

# Phase 3
pip download "scipy>=1.8.0,<1.17.0" --dest . --no-cache-dir && pip wheel scipy --no-deps --wheel-dir . && pip install --find-links . --no-index scipy*.whl

# Build pandas (with meson.build fix)
pip download "pandas<2.3.0" --dest . --no-cache-dir
tar -xzf pandas-2.2.3.tar.gz && sed -i "s/version: run_command.*/version: '2.2.3',/" pandas-2.2.3/meson.build && tar -czf pandas-2.2.3.tar.gz pandas-2.2.3/
pip wheel pandas-2.2.3.tar.gz --no-deps --wheel-dir . && pip install --find-links . --no-index pandas*.whl

pip wheel https://raw.githubusercontent.com/RiteshF7/termux-packages/master/tmp_scikit_fixed.tar.gz --no-deps --no-build-isolation --wheel-dir . && pip install joblib>=1.3.0 threadpoolctl>=3.2.0 && pip install --find-links . --no-index scikit_learn*.whl

# Phase 4
pip download jiter==0.12.0 --dest . --no-cache-dir && pip wheel jiter --no-deps --wheel-dir . && pip install --find-links . --no-index jiter*.whl

# Phase 5
pip download pyarrow psutil grpcio pillow --dest . --no-cache-dir
# pyarrow: try pre-built wheel first, build from source if needed
pip install --find-links . --no-index pyarrow*.whl 2>/dev/null || {
    pkg install -y libarrow-cpp
    export ARROW_HOME=$PREFIX
    pip wheel pyarrow --no-deps --wheel-dir .
}
pip wheel psutil --no-deps --wheel-dir .
# grpcio: Prerequisites, build, then patch wheel (CRITICAL - prevents runtime symbol errors)
# Prerequisites: Ensure patchelf and abseil-cpp are installed
pkg install -y patchelf abseil-cpp
# Set GRPC build flags
export GRPC_PYTHON_BUILD_SYSTEM_OPENSSL=1 GRPC_PYTHON_BUILD_SYSTEM_ZLIB=1 GRPC_PYTHON_BUILD_SYSTEM_CARES=1 GRPC_PYTHON_BUILD_SYSTEM_RE2=1 GRPC_PYTHON_BUILD_SYSTEM_ABSL=1 GRPC_PYTHON_BUILD_WITH_CYTHON=1
# Build wheel
pip wheel grpcio --no-deps --no-build-isolation --wheel-dir .
# Fix wheel: extract, patch .so, repackage
WHEEL_FILE=$(ls grpcio-*.whl | head -1)
unzip -q "$WHEEL_FILE" -d grpcio_extract
SO_FILE=$(find grpcio_extract -name "cygrpc*.so" | head -1)
if [ -z "$SO_FILE" ]; then echo "Error: cygrpc*.so not found"; exit 1; fi
patchelf --add-needed libabsl_flags_internal.so "$SO_FILE"
patchelf --add-needed libabsl_flags.so "$SO_FILE"
patchelf --add-needed libabsl_flags_commandlineflag.so "$SO_FILE"
patchelf --add-needed libabsl_flags_reflection.so "$SO_FILE"
patchelf --set-rpath "$PREFIX/lib" "$SO_FILE"
cd grpcio_extract && python3 << 'PYEOF'
import zipfile, os
zf = zipfile.ZipFile('../grpcio-fixed.whl', 'w', zipfile.ZIP_DEFLATED)
for root, dirs, files in os.walk('.'):
    for file in files:
        zf.write(os.path.join(root, file), os.path.relpath(os.path.join(root, file), '.'))
zf.close()
PYEOF
cd .. && rm -rf grpcio_extract && mv grpcio-fixed.whl "$WHEEL_FILE"
# Set LD_LIBRARY_PATH for runtime (REQUIRED - add to ~/.bashrc for permanent fix)
export LD_LIBRARY_PATH=$PREFIX/lib:$LD_LIBRARY_PATH
if ! grep -q "LD_LIBRARY_PATH.*PREFIX/lib" ~/.bashrc 2>/dev/null; then
    echo "export LD_LIBRARY_PATH=\$PREFIX/lib:\$LD_LIBRARY_PATH" >> ~/.bashrc
fi
# pillow: Prerequisites, then build
pkg install -y libjpeg-turbo libpng libtiff libwebp freetype
export PKG_CONFIG_PATH=$PREFIX/lib/pkgconfig:$PKG_CONFIG_PATH
export LDFLAGS="-L$PREFIX/lib"
export CPPFLAGS="-I$PREFIX/include"
pip wheel pillow --no-deps --wheel-dir .
pip install --find-links . --no-index pyarrow*.whl psutil*.whl grpcio*.whl pillow*.whl

# Phase 6 (optional - check for wheels first)
pip install tokenizers safetensors cryptography pydantic-core orjson 2>/dev/null || {
    pip download tokenizers safetensors cryptography pydantic-core orjson --dest . --no-cache-dir
    for pkg in tokenizers safetensors cryptography pydantic-core orjson; do
        pip wheel $pkg --no-deps --wheel-dir . 2>/dev/null || echo "Skipping $pkg (may have wheel)"
    done
}

# Phase 7
cd ~ && pip install 'droidrun[google,anthropic,openai,deepseek,ollama,openrouter]' --find-links ~/wheels
```

## Prerequisites Summary

**Before building any packages, ensure:**

1. **System dependencies installed:**
   ```bash
   pkg install -y python python-pip autoconf automake libtool make binutils clang cmake ninja rust flang blas-openblas libjpeg-turbo libpng libtiff libwebp freetype libarrow-cpp openssl libc++ zlib protobuf libprotobuf abseil-cpp c-ares libre2 patchelf
   ```

2. **Build environment variables set:**
   ```bash
   export PREFIX=${PREFIX:-/data/data/com.termux/files/usr}
   export NINJAFLAGS="-j2" MAKEFLAGS="-j2" MAX_JOBS=2
   export CMAKE_PREFIX_PATH=$PREFIX
   export CMAKE_INCLUDE_PATH=$PREFIX/include
   export CC=$PREFIX/bin/clang
   export CXX=$PREFIX/bin/clang++
   export TMPDIR=$HOME/tmp
   mkdir -p $TMPDIR ~/wheels
   ```

3. **Package-specific prerequisites:**
   - **numpy**: patchelf (system package)
   - **pandas**: numpy, meson-python
   - **scikit-learn**: numpy, scipy, meson-python, joblib>=1.3.0, threadpoolctl>=3.2.0
   - **jiter**: maturin, rust
   - **pyarrow**: libarrow-cpp (if building from source)
   - **grpcio**: patchelf, abseil-cpp (system packages)
   - **Pillow**: libjpeg-turbo, libpng, libtiff, libwebp, freetype (system packages)
   - **Phase 6 packages** (tokenizers, safetensors, cryptography, pydantic-core, orjson): No special prerequisites, build successfully with standard build environment

## Special Fixes

**patchelf (numpy dependency):** 
- Install system patchelf package: `pkg install -y patchelf`
- Ensure build environment is set up (see "Build Environment Setup" section) - this sets CMAKE environment variables
- This prevents Python patchelf package from trying to build and failing with CMake error: `/include/android/api-level.h: No such file or directory`

**pandas:** 
- Fix `meson.build` line 5: Replace `version: run_command(['generate_version.py', '--print'], check: true).stdout().strip(),` with `version: '2.2.3',`
- **Steps:**
  1. Download pandas tarball: `pip download "pandas<2.3.0" --dest . --no-cache-dir`
  2. Extract: `tar -xzf pandas-2.2.3.tar.gz`
  3. Fix meson.build: `sed -i "s/version: run_command.*/version: '2.2.3',/" pandas-2.2.3/meson.build`
  4. Repackage: `tar -czf pandas-2.2.3.tar.gz pandas-2.2.3/`
  5. Build wheel: `pip wheel pandas-2.2.3.tar.gz --no-deps --wheel-dir .`
- **Reason:** The `generate_version.py` script is not available or fails in Termux build environment, causing meson build to fail during metadata preparation.

**scikit-learn:** 
- **Recommended:** Use pre-fixed tarball from GitHub: `https://raw.githubusercontent.com/RiteshF7/termux-packages/master/tmp_scikit_fixed.tar.gz`
- Build with `--no-build-isolation` flag to skip build dependencies that require `make`
- Install dependencies first: `joblib>=1.3.0` and `threadpoolctl>=3.2.0`
- **Alternative (manual fix):** Add `#!/usr/bin/env python3` to `sklearn/_build_utils/version.py` and fix `meson.build` line 4: use extracted version

**pyarrow:**
- Usually has a pre-built wheel available for common platforms (x86_64, aarch64)
- **If wheel exists:** Install directly: `pip install --find-links . --no-index pyarrow*.whl`
- **If building from source (for different architectures):**
  - Install system dependency: `pkg install -y libarrow-cpp`
  - Set build environment variables:
    ```bash
    export PREFIX=${PREFIX:-/data/data/com.termux/files/usr}
    export CMAKE_PREFIX_PATH=$PREFIX
    export CMAKE_INCLUDE_PATH=$PREFIX/include
    export ARROW_HOME=$PREFIX
    export CC=$PREFIX/bin/clang
    export CXX=$PREFIX/bin/clang++
    ```
  - Build with: `pip wheel pyarrow --no-deps --wheel-dir .`
  - Common build errors:
    - CMake configuration fails: Ensure `libarrow-cpp` is installed and `CMAKE_PREFIX_PATH` is set
    - Missing Arrow libraries: Check that `$PREFIX/lib` contains `libarrow*.so` files
    - Linker errors: Verify `ARROW_HOME` points to correct prefix directory

**grpcio:** 
- **Prerequisites (MUST install first):**
  - `pkg install -y patchelf` - Required for patching the wheel
  - `pkg install -y abseil-cpp` - Required system dependency (should already be installed with system dependencies)
- **CRITICAL:** Must patch the wheel after building to add abseil library dependencies, otherwise runtime import will fail
- Use `--no-build-isolation` + set GRPC_PYTHON_BUILD_SYSTEM_* env vars
- **Required fix sequence:**
  1. Build wheel normally: `pip wheel grpcio --no-deps --no-build-isolation --wheel-dir .`
  2. Extract wheel: `unzip -q grpcio-*.whl -d grpcio_extract`
  3. Find .so file: `find grpcio_extract -name "cygrpc*.so"`
  4. Patch with patchelf:
     - Add abseil libraries to NEEDED: `--add-needed libabsl_flags_internal.so --add-needed libabsl_flags.so --add-needed libabsl_flags_commandlineflag.so --add-needed libabsl_flags_reflection.so`
     - Set RPATH: `--set-rpath $PREFIX/lib`
  5. Repackage wheel using Python zipfile module
  6. Replace original wheel with fixed one
  7. Install fixed wheel: `pip install --find-links . --no-index grpcio*.whl`
  8. Set LD_LIBRARY_PATH: `export LD_LIBRARY_PATH=$PREFIX/lib:$LD_LIBRARY_PATH` (add to ~/.bashrc for permanent)
- **Runtime requirement:** Due to Android's linker namespace restrictions, you must set `LD_LIBRARY_PATH=$PREFIX/lib` when running Python
- **Error if not fixed:** `ImportError: dlopen failed: cannot locate symbol "_ZN4absl12lts_2025081414flags_internal17kStrippedFlagHelpE"` or `library "libabsl_flags.so" not found`
- **Reason:** grpcio build system doesn't automatically link against abseil libraries even with `GRPC_PYTHON_BUILD_SYSTEM_ABSL=1`. The wheel must be patched post-build to add the library dependencies. Android's linker also requires LD_LIBRARY_PATH to be set at runtime.

**Pillow:**
- **Prerequisites (MUST install first):**
  - `pkg install -y libjpeg-turbo libpng libtiff libwebp freetype` - Required image libraries
- **Build environment:** Set `PKG_CONFIG_PATH`, `LDFLAGS`, and `CPPFLAGS` to help Pillow find the libraries
- **Error if prerequisites missing:** `RequiredDependencyException: jpeg` - "The headers or library files could not be found for jpeg"
- **Fix:** Install `libjpeg-turbo` and other image libraries, then set environment variables:
  ```bash
  export PREFIX=${PREFIX:-/data/data/com.termux/files/usr}
  export PKG_CONFIG_PATH=$PREFIX/lib/pkgconfig:$PKG_CONFIG_PATH
  export LDFLAGS="-L$PREFIX/lib"
  export CPPFLAGS="-I$PREFIX/include"
  ```
- **Note:** These libraries should already be installed as part of system dependencies, but if build fails, ensure they are installed.

## Version Constraints

- pandas: `<2.3.0` (required by llama-index-readers-file)
- scipy: `>=1.8.0,<1.17.0` (required by scikit-learn)
- numpy: `>=1.26.0` (required by pandas, scipy, scikit-learn)
- meson-python: `<0.19.0,>=0.16.0`
- maturin: `<2,>=1.9.4`
- jiter: `==0.12.0`

