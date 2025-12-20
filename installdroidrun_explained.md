# installdroidrun.sh - Overview

## What It Does
Installs droidrun and all its dependencies on Android/Termux. Builds Python packages from source when pre-built wheels aren't available.

## Main Flow

### 1. Setup & Environment
- Checks if running in Termux
- Sets up build environment (compilers, paths, parallelization)
- Creates logging and progress tracking files
- Installs system dependencies (clang, cmake, rust, etc.)

### 2. Installation Phases (7 Total)

**Phase 1: Build Tools**
- Installs: wheel, setuptools, Cython, meson-python, maturin
- These are needed to build other packages

**Phase 2: Foundation**
- Builds numpy (core numerical library)

**Phase 3: Scientific Stack**
- Builds: scipy, pandas, scikit-learn
- Uses special build scripts for pandas and scikit-learn

**Phase 4: Rust Packages**
- Builds jiter (Rust-based package using maturin)
- Tries pre-built wheels first

**Phase 5: Compiled Packages**
- Builds: pyarrow, psutil, grpcio, Pillow
- Fixes grpcio wheel after building (adds missing library links)

**Phase 6: Optional Packages**
- Builds: tokenizers, safetensors, cryptography, pydantic-core, orjson
- Continues even if some fail

**Phase 7: Main Package**
- Installs droidrun core and LLM providers
- Uses separate provider installation script if available

### 3. Key Features

**Progress Tracking**
- Saves progress after each phase
- Can resume from last completed phase if interrupted

**Smart Installation**
- Checks if packages are already installed before building
- Prefers pre-built wheels when available
- Falls back to building from source

**Error Handling**
- Logs errors to separate file
- Continues with optional packages even if some fail
- Shows clear warnings for expected failures (e.g., tokenizers on Android)

**Build System**
- Uses `build_package()` function for consistent building
- Handles source fixes for problematic packages (pandas, scikit-learn)
- Sets proper environment variables for each build

## Output
- Installation log: `~/.droidrun_install.log`
- Error log: `~/.droidrun_install_errors.log`
- Progress file: `~/.droidrun_install_progress`
- Built wheels saved to: `~/wheels/`

