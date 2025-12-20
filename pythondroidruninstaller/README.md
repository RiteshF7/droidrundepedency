# Python Droidrun Installer

A clean, modular Python implementation of the droidrun installation system.

## Structure

```
pythondroidruninstaller/
├── __init__.py              # Package initialization
├── common.py                 # Shared utilities and functions
├── phase1_build_tools.py    # Phase 1: Build tools installation
├── requirements.txt         # Python dependencies
└── README.md                # This file
```

## Installation

1. Install Python dependencies:
```bash
pip install -r requirements.txt
```

## Usage

### Run Phase 1 (Build Tools)

```bash
python3 -m pythondroidruninstaller.phase1_build_tools
```

Or directly:
```bash
python3 pythondroidruninstaller/phase1_build_tools.py
```

### Force Rerun

To force rerun even if phase is already complete:
```bash
FORCE_RERUN=1 python3 -m pythondroidruninstaller.phase1_build_tools
```

## Features

- **Clean Code**: Modular design with separation of concerns
- **Type Hints**: Full type annotations for better IDE support
- **Error Handling**: Comprehensive error handling and logging
- **Progress Tracking**: Saves progress after each phase
- **Resumable**: Can resume from last completed phase
- **Cross-platform**: Works on Termux and other environments

## Dependencies

### Python Packages
- `packaging>=21.0` - For version comparison and requirement parsing

### System Tools (same as bash version)
- `python3` and `pip`
- `pkg` (Termux package manager)
- `rust` / `cargo` (for maturin)

## Differences from Bash Version

1. **Better Error Handling**: Python exceptions provide better error context
2. **Type Safety**: Type hints help catch errors early
3. **Modularity**: Clean separation between utilities and phase logic
4. **Cross-platform**: Easier to test on different platforms
5. **Maintainability**: Python is easier to maintain and extend

## Logging

Logs are written to:
- `~/.droidrun_install.log` - Full installation log
- `~/.droidrun_install_errors.log` - Error log only
- `~/.droidrun_install_progress` - Progress tracking
- `~/.droidrun_install_env` - Environment variables

## Development

To add new phases, follow the pattern in `phase1_build_tools.py`:
1. Import common utilities from `common.py`
2. Implement phase logic in a `main()` function
3. Use logging functions for output
4. Mark phase as complete when done

