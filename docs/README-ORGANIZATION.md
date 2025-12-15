# Project Organization

This project has been organized into a clean structure for building and installing `droidrun[google]` in Termux on Android emulator.

## Directory Structure

```
MiniLinux/
├── docs/                    # All documentation
│   ├── README.md           # Documentation index
│   ├── droidrun_dep_install_seq.md      # Installation sequence guide
│   ├── droidrun-google-dependencies.md  # Dependency tree
│   ├── termux-build-errors-and-solutions.md  # Error solutions
│   ├── emulator-requirements.md         # Emulator config
│   └── *.txt              # Reference files
│
├── scripts/                # All scripts organized by category
│   ├── README.md          # Scripts index
│   ├── build/             # Build and installation scripts
│   │   ├── install-droidrun-dependencies.sh  ⭐ MAIN SCRIPT
│   │   ├── build-all.sh   # Master build script
│   │   └── ...            # Other build scripts
│   ├── monitor/           # Progress monitoring scripts
│   │   ├── monitor-build.sh  ⭐ RECOMMENDED
│   │   └── ...            # Other monitor scripts
│   ├── setup/             # Setup scripts
│   ├── utils/             # Utility scripts
│   └── fix/               # Fix scripts for build issues
│
├── bat-scripts/           # Windows batch scripts
│   └── launch_pixel4a.bat
│
└── ...                    # Other project files
```

## Quick Start

### 1. Read Documentation

Start with the documentation:

```bash
cd docs
cat README.md
```

Key documents:
- **`droidrun_dep_install_seq.md`** - Step-by-step installation guide
- **`emulator-requirements.md`** - Configure your emulator first
- **`termux-build-errors-and-solutions.md`** - Troubleshooting

### 2. Configure Emulator

Read `docs/emulator-requirements.md` and configure your emulator:
- RAM: 6 GB recommended
- Storage: 30 GB recommended
- Graphics: Software - GLES 2.0

### 3. Run Installation

Use the main installation script:

```bash
cd scripts/build
./install-droidrun-dependencies.sh
```

Or use the master build script:

```bash
cd scripts/build
./build-all.sh
```

### 4. Monitor Progress

In another terminal, monitor the build:

```bash
cd scripts/monitor
./monitor-build.sh
```

## Main Scripts

### Installation

- **`scripts/build/install-droidrun-dependencies.sh`** ⭐
  - Complete step-by-step installation
  - Handles all dependencies automatically
  - Progress logging and error handling

### Monitoring

- **`scripts/monitor/monitor-build.sh`** ⭐
  - Unified progress monitor
  - Shows installed packages, active processes, system resources

### Utilities

- `scripts/utils/copy-wheels-from-emulator.sh` - Copy wheels to host
- `scripts/utils/retry-failed-packages.sh` - Retry failed builds

## Documentation

All documentation is in the `docs/` folder:

- **Installation Guide**: `docs/droidrun_dep_install_seq.md`
- **Dependencies**: `docs/droidrun-google-dependencies.md`
- **Troubleshooting**: `docs/termux-build-errors-and-solutions.md`
- **Emulator Setup**: `docs/emulator-requirements.md`

## Script Categories

### Build Scripts (`scripts/build/`)

Scripts for building wheels and installing dependencies.

**Main Script**: `install-droidrun-dependencies.sh`

### Monitor Scripts (`scripts/monitor/`)

Scripts to monitor build progress in real-time.

**Recommended**: `monitor-build.sh`

### Setup Scripts (`scripts/setup/`)

Initial setup and configuration scripts.

### Utility Scripts (`scripts/utils/`)

Helper scripts for copying files, retrying builds, etc.

### Fix Scripts (`scripts/fix/`)

Scripts to fix common build issues (meson.build, etc.)

## Workflow

1. **Setup** (one-time):
   - Configure emulator (see `docs/emulator-requirements.md`)
   - Install system dependencies

2. **Build**:
   - Run `scripts/build/install-droidrun-dependencies.sh`
   - Or follow `docs/droidrun_dep_install_seq.md` manually

3. **Monitor**:
   - Run `scripts/monitor/monitor-build.sh` in another terminal

4. **Troubleshoot**:
   - Check `docs/termux-build-errors-and-solutions.md` for errors

## Notes

- All scripts are organized by function
- Documentation is centralized in `docs/`
- Main scripts are marked with ⭐
- See individual README files in each folder for details

## Migration Notes

If you have old scripts or references:

- Old scripts in root → moved to `scripts/` subfolders
- Old `.md` files in root → moved to `docs/`
- Old `.txt` files → moved to `docs/`
- Batch scripts → remain in `bat-scripts/`

Update any paths in your workflow to use the new structure.

