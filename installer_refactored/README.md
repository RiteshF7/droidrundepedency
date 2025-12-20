# Droidrun Installation Scripts (Refactored)

This directory contains a modular installation system for droidrun, split into separate phase scripts for better maintainability and resumability.

## Structure

- `common.sh` - Shared functions and utilities used by all phase scripts
- `install_droidrun.sh` - Main orchestrator script that runs all phases sequentially
- `phase1_build_tools.sh` - Installs build tools (wheel, setuptools, Cython, meson-python, maturin)
- `phase2_numpy.sh` - Installs numpy
- `phase3_scientific.sh` - Installs scipy, pandas, scikit-learn
- `phase4_jiter.sh` - Installs jiter (Rust package)
- `phase5_compiled.sh` - Installs pyarrow, psutil, grpcio, pillow
- `phase6_optional.sh` - Installs optional packages (tokenizers, safetensors, etc.)
- `phase7_providers.sh` - Installs droidrun core and LLM providers

## Usage

### Full Installation

Run the main orchestrator script to install everything:

```bash
bash installer_refactored/install_droidrun.sh
```

The script will:
1. Check system dependencies and install missing packages
2. Run each phase sequentially
3. Skip phases that are already completed (based on progress file)
4. Save progress after each phase for resumability

### Running Individual Phases

You can run individual phase scripts directly:

```bash
bash installer_refactored/phase1_build_tools.sh
bash installer_refactored/phase2_numpy.sh
# etc.
```

Each phase script:
- Checks if it's already completed (skips if so)
- Can be run independently
- Saves progress after completion
- Uses shared logging and environment variables

### Resuming Installation

If installation is interrupted, simply run the main script again:

```bash
bash installer_refactored/install_droidrun.sh
```

Completed phases will be automatically skipped based on the progress file (`~/.droidrun_install_progress`).

## Progress Tracking

The installation system uses several files for tracking:

- `~/.droidrun_install_progress` - Tracks which phases are complete
- `~/.droidrun_install_env` - Saves environment variables between runs
- `~/.droidrun_install.log` - Full installation log
- `~/.droidrun_install_errors.log` - Error log for troubleshooting

## Features

1. **Modular Design**: Each phase is a separate script, making it easy to maintain and debug
2. **Resumable**: Installation can be resumed from the last completed phase
3. **Progress Tracking**: Progress is saved after each phase completion
4. **Shared Utilities**: Common functions are in `common.sh` to avoid duplication
5. **Comprehensive Logging**: All phases write to the same log files
6. **Error Handling**: Failed phases can be skipped to continue with remaining phases

## Requirements

- Termux environment
- System packages (installed automatically by the main script)
- Python 3.x
- pip

## Notes

- The scripts use the same progress and log files as the original monolithic script
- Environment variables are saved and loaded automatically
- Each phase can be run independently for testing/debugging
- The main script handles system dependency checks and environment setup

