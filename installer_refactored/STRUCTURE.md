# Installation Script Structure

## Overview

The installation process has been refactored from a single monolithic script (`installdroidrun.sh`) into a modular system with separate phase scripts. This improves maintainability, allows for easier debugging, and enables resumable installations.

## File Structure

```
installer_refactored/
├── common.sh                    # Shared functions and utilities
├── install_droidrun.sh          # Main orchestrator script
├── scripts/                     # Phase scripts directory
│   ├── phase1_build_tools.sh    # Phase 1: Build tools
│   ├── phase2_numpy.sh          # Phase 2: NumPy
│   ├── phase3_scientific.sh     # Phase 3: Scientific stack
│   ├── phase4_jiter.sh          # Phase 4: Jiter (Rust)
│   ├── phase5_compiled.sh       # Phase 5: Compiled packages
│   ├── phase6_optional.sh       # Phase 6: Optional packages
│   ├── phase7_providers.sh      # Phase 7: Droidrun + providers
│   └── install_droidrun_providers.sh  # Provider installation script
├── README.md                     # Usage documentation
└── STRUCTURE.md                  # This file
```

## Phase Breakdown

### Phase 1: Build Tools
- Installs: wheel, setuptools, Cython, meson-python, maturin
- Purpose: Essential build tools needed for compiling Python packages
- Dependencies: None (pure Python packages)

### Phase 2: NumPy
- Installs: numpy
- Purpose: Foundation for scientific computing
- Dependencies: Phase 1

### Phase 3: Scientific Stack
- Installs: scipy, pandas, scikit-learn
- Purpose: Core scientific computing libraries
- Dependencies: Phase 2 (numpy)

### Phase 4: Jiter
- Installs: jiter (Rust package)
- Purpose: Required for droidrun
- Dependencies: Phase 1 (maturin)

### Phase 5: Compiled Packages
- Installs: pyarrow, psutil, grpcio, pillow
- Purpose: Additional compiled dependencies
- Dependencies: Phases 1-2

### Phase 6: Optional Packages
- Installs: tokenizers, safetensors, cryptography, pydantic-core, orjson
- Purpose: Optional but recommended packages
- Dependencies: Various

### Phase 7: Droidrun and Providers
- Installs: droidrun core + LLM providers
- Purpose: Main package and provider plugins
- Dependencies: All previous phases

## Progress Tracking

### Progress File
- Location: `~/.droidrun_install_progress`
- Format: `PHASE_<N>_COMPLETE=<timestamp>`
- Purpose: Tracks which phases have completed successfully

### Environment File
- Location: `~/.droidrun_install_env`
- Purpose: Saves environment variables between runs
- Contents: PREFIX, WHEELS_DIR, compiler flags, etc.

### Log Files
- Main log: `~/.droidrun_install.log`
- Error log: `~/.droidrun_install_errors.log`
- Purpose: Comprehensive logging for troubleshooting

## How It Works

1. **Main Script (`install_droidrun.sh`)**:
   - Checks system dependencies
   - Sets up build environment
   - Runs each phase script sequentially
   - Handles errors and allows continuation

2. **Phase Scripts**:
   - Check if already completed (skip if so)
   - Load environment variables
   - Run their specific installation tasks
   - Mark phase as complete on success
   - Save environment variables

3. **Common Functions (`common.sh`)**:
   - Shared logging functions
   - Package checking utilities
   - Build functions
   - Progress tracking functions
   - Environment management

## Benefits of This Structure

1. **Modularity**: Each phase is independent and can be run separately
2. **Resumability**: Installation can resume from last completed phase
3. **Maintainability**: Easier to update individual phases
4. **Debugging**: Can test individual phases in isolation
5. **Progress Tracking**: Clear visibility into installation progress
6. **Error Isolation**: Failures in one phase don't prevent others from running

## Usage Examples

### Full Installation
```bash
bash installer_refactored/install_droidrun.sh
```

### Run Specific Phase
```bash
bash installer_refactored/scripts/phase3_scientific.sh
```

### Resume After Interruption
```bash
# Just run the main script again - it will skip completed phases
bash installer_refactored/install_droidrun.sh
```

### Check Progress
```bash
cat ~/.droidrun_install_progress
```

### View Logs
```bash
tail -f ~/.droidrun_install.log
cat ~/.droidrun_install_errors.log
```

## Migration from Original Script

The refactored scripts:
- Use the same progress/log files as the original
- Maintain the same installation order
- Preserve all functionality
- Are fully compatible with existing installations

If you've already run the original `installdroidrun.sh`, the new scripts will detect completed phases and skip them automatically.

