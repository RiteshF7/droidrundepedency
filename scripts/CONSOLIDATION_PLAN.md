# Script Consolidation Plan

## Analysis Summary
- **Total scripts analyzed:** 48 files (39 .sh, 9 .py)
- **Build scripts:** 15 files (many duplicates)
- **Monitor scripts:** 7 files (overlapping functionality)
- **Copy scripts:** 4 files (similar purposes)

## Consolidation Strategy

### Build Scripts (build/)
**KEEP:**
- `install-droidrun-dependencies.sh` - Main comprehensive installation script (691 lines, most complete)

**REMOVE (duplicates/obsolete):**
- `build-all.sh` - Duplicate functionality
- `complete-setup-and-build.sh` - Can be split into setup + install
- `build-droidrun-wheels.sh` - Covered by install script
- `build-wheels-in-termux.sh` - Covered by install script
- `build-with-progress.sh` - Older version
- `build-with-progress-v2.sh` - Features should be in main script
- `automated-build-in-termux.sh` - Duplicate
- `execute-build-in-termux.sh` - Duplicate
- `final-build-script.sh` - Obsolete (superseded by install script)
- `build_and_install_whl.sh` - Utility, move to utils if needed
- `build_and_install_whl_termux.sh` - Duplicate
- `copy-and-run-install.sh` - Obsolete
- `run-install-dependencies.sh` - Duplicate
- `test-build-direct.sh` - Test script, can remove

### Monitor Scripts (monitor/)
**KEEP & MERGE:**
- `show-build-progress.sh` - Best features from all monitors
- `view-install-log.sh` - Simple log viewer (keep as utility)

**REMOVE (duplicates):**
- `monitor-build.sh` - Duplicate of show-build-progress.sh
- `continuous-progress.sh` - Duplicate functionality
- `monitor-and-continue-build.sh` - Can merge features if needed
- `follow-install-log.sh` - Merge into show-build-progress.sh
- `follow-install-log-poll.sh` - Merge into show-build-progress.sh

### Copy Scripts
**KEEP:**
- `utils/copy-wheels-from-emulator.sh` - Most complete emulator copy script

**REMOVE:**
- `copy_wheels_from_device.sh` - Duplicate (less complete)
- `copy-droidrun-deps.sh` - Specific use case, keep if needed
- `copy-sources-reliable.sh` - Keep if actively used

### Upload Scripts
**KEEP:**
- `upload_wheels_to_github.py` - Main upload script
- `upload_to_github_release.py` - Generic utility (used by upload_wheels)

### Other Scripts
**KEEP:**
- `discover-all-dependencies.sh` - Dependency discovery
- `build-all-dependencies.sh` - Build all deps
- `build-system-packages.sh` - System packages
- `export-bootstrap.sh` - Bootstrap export
- `track-and-export-wheels.sh` - Wheel tracking
- `sync-termux-files.sh` - File sync
- All fix/ scripts - Build fixes
- All utils/ scripts - Utilities

**REVIEW:**
- `sync-termux-files-examples.sh` - Examples, maybe move to docs
- `track-and-export-wheels.bat` - Windows batch, keep if needed

## Final Structure
```
scripts/
├── build/
│   └── install-droidrun-dependencies.sh  (main script)
├── monitor/
│   ├── show-build-progress.sh  (unified monitor)
│   └── view-install-log.sh  (simple log viewer)
├── setup/
│   ├── setup-ssh-termux.sh
│   └── setup-and-build-via-adb.sh
├── utils/
│   └── (all utility scripts)
├── fix/
│   └── (all fix scripts)
└── (root level scripts)
```


