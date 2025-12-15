# Complete Pre-build System for droidrun[google]

This directory contains scripts for building ALL dependencies for droidrun[google] and creating a zero-compilation bootstrap package.

## Quick Start

### 1. Discover Dependencies
```bash
./discover-all-dependencies.sh "droidrun[google]" 3.12
```

### 2. Build on Android Device
```bash
# Transfer manifest and scripts to device, then:
./build-all-dependencies.sh ~/dependency-manifest.json
```

### 3. Export Bootstrap
```bash
./export-bootstrap.sh ~/dependency-manifest.json
```

### 4. Install from Bootstrap
```bash
# On target device:
tar -xzf droidrun-bootstrap-*.tar.gz
cd droidrun-bootstrap
./scripts/install.sh
```

## Scripts Overview

### Main Scripts

- **`discover-all-dependencies.sh`** - Discovers all transitive dependencies and checks wheel availability
- **`build-all-dependencies.sh`** - Builds all dependencies on Android device with all fixes applied
- **`build-system-packages.sh`** - Checks and builds system packages if needed
- **`export-bootstrap.sh`** - Packages all wheels into a single bootstrap archive

### Utility Scripts (`utils/`)

- **`check-wheel-availability.py`** - Checks PyPI for wheel availability per architecture
- **`dependency-parser.py`** - Parses dependency trees from downloaded packages
- **`discover-dependencies.py`** - Main Python script for dependency discovery
- **`build-status.sh`** - Tracks build progress and supports resumable builds

## Workflow

```
Discovery → Build → Export → Install
    ↓         ↓        ↓        ↓
 Manifest  Wheels   Archive  Zero-compile
```

## Documentation

See `../docs/bootstrap-creation-guide.md` for complete documentation.

## Key Features

- ✅ Discovers ALL transitive dependencies
- ✅ Checks wheel availability for aarch64 and x86_64
- ✅ Builds in correct dependency order
- ✅ Applies all fixes automatically
- ✅ Tracks build progress (resumable)
- ✅ Packages everything into single archive
- ✅ Zero-compilation installation

## Requirements

- Python 3.12+
- Termux on Android
- Build tools (clang, ninja, rust, flang, etc.)
- ADB for file transfer (optional)

## File Structure

```
scripts/
├── discover-all-dependencies.sh    # Phase 1: Discovery
├── build-all-dependencies.sh       # Phase 2: Build
├── build-system-packages.sh        # Phase 2: System packages
├── export-bootstrap.sh             # Phase 3: Export
└── utils/
    ├── check-wheel-availability.py
    ├── dependency-parser.py
    ├── discover-dependencies.py
    └── build-status.sh
```

## Notes

- Build process takes 2-4 hours on Android device
- All fixes from `termux-build-errors-and-solutions.md` are applied automatically
- Build is resumable - can restart from last successful package
- Supports both aarch64 and x86_64 architectures



