# Build Scripts Module

This directory contains modular scripts for building droidrun wheels. The main script `build-all-wheels-automated.sh` orchestrates the build process using these modules.

## Structure

- **config.sh** - Configuration file with all paths, constants, and package definitions
- **common.sh** - Common functions used across all build scripts
- **install-system-deps.sh** - Installs system dependencies using pkg
- **detect-wheels.sh** - Detects available wheels from pip and existing wheel files
- **build-wheels.sh** - Builds wheels from source files
- **export-wheels.sh** - Exports all built wheels to wheels_${ARCH} directory

## Flow

1. **Configuration** - Load all paths, configs, and constants
2. **System Setup** - pkg update, upgrade, install python/pip
3. **System Dependencies** - Install all pkg dependencies in correct sequence
4. **Build Environment** - Setup build environment variables
5. **Architecture Detection** - Auto-detect architecture (aarch64/x86_64)
6. **Wheel Detection** - Check pip for available wheels, install existing wheels
7. **Build from Source** - Build remaining packages from source files
8. **Pip Fallback** - Use pip as fallback for packages that couldn't be built
9. **Export** - Export all wheels to wheels_${ARCH} directory

## Usage

Run the main script:

```bash
./scripts/build-all-wheels-automated.sh
```

## Configuration

All configuration is in `config.sh`. Key variables:

- `SOURCES_DIR` - Directory containing source files (.tar.gz, .zip)
- `WHEELS_DIR` - Directory for built wheels
- `EXPORT_DIR` - Directory to export wheels (wheels_${ARCH})
- `ARCH` - Detected architecture (aarch64 or x86_64)
- `PLATFORM_TAG` - Platform tag for wheels (linux_aarch64 or linux_x86_64)

## Source Directory

The script checks for source files in this order:
1. `/data/data/com.termux/files/home/droidrunBuild/sources/source`
2. `$PROJECT_ROOT/depedencies/source`
3. `$PROJECT_ROOT/sources`

If the source directory doesn't exist, it will be created, but you need to populate it with source files.

## Package Lists

Package definitions are in `config.sh`:

- `SYSTEM_DEPS` - System packages to install via pkg
- `PYTHON_PACKAGES` - Python packages to build/install
- `PKG_SYSTEM_DEPS` - Package-specific system dependencies
- `PYTHON_TRANSITIVE_DEPS` - Python package dependencies

These are based on DEPENDENCIES.md.

