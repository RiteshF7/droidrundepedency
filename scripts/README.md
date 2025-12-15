# Scripts

This folder contains all scripts organized by category for building and installing `droidrun[google]` in Termux.

## Directory Structure

```
scripts/
├── build/          # Build and installation scripts
│   └── install-droidrun-dependencies.sh  (main script)
├── monitor/        # Progress monitoring scripts
│   ├── show-build-progress.sh  (unified monitor)
│   └── view-install-log.sh  (log viewer)
├── setup/          # Setup and configuration scripts
│   ├── setup-ssh-termux.sh
│   └── setup-and-build-via-adb.sh
├── utils/          # Utility scripts (copy, retry, etc.)
│   ├── build-status.sh
│   ├── check-wheel-availability.py
│   ├── connect-ssh-and-build.sh
│   ├── copy-wheels-from-emulator.sh
│   ├── dependency-parser.py
│   ├── discover-dependencies.py
│   ├── kill-zombie-processes.sh
│   └── retry-failed-packages.sh
├── fix/            # Fix scripts for build issues
│   ├── download-scikit-learn.py
│   ├── fix-meson-build.py
│   └── fix_pandas_meson.py
├── archive/        # Archived/removed scripts (for reference)
└── (root level scripts for discovery, export, sync, upload)
```

## Script Categories

### Build Scripts (`build/`)

Main scripts for building wheels and installing dependencies:

- **`install-droidrun-dependencies.sh`** ⭐ **MAIN SCRIPT**
  - Complete step-by-step installation
  - Handles all dependencies
  - Progress logging
  - Error handling
  - Comprehensive build process for all droidrun[google] dependencies

### Monitor Scripts (`monitor/`)

Scripts to monitor build progress:

- **`show-build-progress.sh`** ⭐ **RECOMMENDED**
  - Continuous progress display
  - Shows installed packages
  - Active build processes
  - System resources
  - Real-time log following
  - Polling mode for reliable ADB connections

- `view-install-log.sh` - Simple log viewer utility

### Setup Scripts (`setup/`)

Initial setup and configuration:

- `setup-ssh-termux.sh` - Setup SSH connection to Termux
- `setup-and-build-via-adb.sh` - Setup and build via ADB

### Utility Scripts (`utils/`)

Helper scripts:

- `copy-wheels-from-emulator.sh` - Copy wheels from emulator to host
- `connect-ssh-and-build.sh` - Connect via SSH and build
- `retry-failed-packages.sh` - Retry failed package builds

### Fix Scripts (`fix/`)

Scripts to fix build issues:

- `fix-meson-build.py` - Fix meson.build files
- `fix_pandas_meson.py` - Fix pandas meson.build
- `download-scikit-learn.py` - Download scikit-learn from GitHub

## Quick Start

### Recommended Workflow

1. **Setup** (one-time):
   ```bash
   cd scripts/setup
   ./setup-and-build-via-adb.sh
   ```

2. **Build** (main installation):
   ```bash
   cd scripts/build
   ./install-droidrun-dependencies.sh
   ```

3. **Monitor** (in another terminal):
   ```bash
   cd scripts/monitor
   ./show-build-progress.sh
   ```

## Script Usage

### Main Installation Script

```bash
cd scripts/build
./install-droidrun-dependencies.sh
```

This script:
- Installs all system dependencies
- Builds wheels in correct order
- Handles version constraints
- Provides detailed logging

### Progress Monitoring

```bash
cd scripts/monitor
./show-build-progress.sh
```

Shows:
- Installed packages
- Active build processes
- Wheel files created
- System resources
- Build progress

### Copy Wheels from Emulator

```bash
cd scripts/utils
./copy-wheels-from-emulator.sh
```

Copies all built wheels from emulator to host machine.

## Root Level Scripts

Additional utility scripts in the root `scripts/` directory:

- `build-all-dependencies.sh` - Build all dependencies from manifest
- `build-system-packages.sh` - Build system packages
- `discover-all-dependencies.sh` - Discover all transitive dependencies
- `export-bootstrap.sh` - Export bootstrap package
- `copy-droidrun-deps.sh` - Copy droidrun dependencies from device
- `copy-sources-reliable.sh` - Copy source files reliably
- `sync-termux-files.sh` - Sync files to/from Termux
- `sync-termux-files-examples.sh` - Example usage for sync script
- `track-and-export-wheels.sh` - Track and export wheel files
- `track-and-export-wheels.bat` - Windows batch version
- `upload_wheels_to_github.py` - Upload wheels to GitHub releases
- `upload_to_github_release.py` - Generic GitHub release upload utility
- `zip_folders.py` - Create ZIP files from folders

## Notes

- All scripts should be run from their respective directories
- Check `../docs/` for detailed documentation
- See `../docs/termux-build-errors-and-solutions.md` for troubleshooting
- Removed/duplicate scripts are archived in `archive/removed-scripts/` for reference
- See `CLEANUP_SUMMARY.md` for details on script consolidation


