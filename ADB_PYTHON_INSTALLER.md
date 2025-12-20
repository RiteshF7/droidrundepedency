# Running Python Installer via ADB

## Quick Command

```bash
adb shell "run-as com.termux sh -c 'cd /data/data/com.termux/files/home/droidrundepedency/pythondroidruninstaller && export PATH=/data/data/com.termux/files/usr/bin:\$PATH && export HOME=/data/data/com.termux/files/home && python3 phase1_build_tools.py'"
```

## With Force Rerun

```bash
adb shell "run-as com.termux sh -c 'cd /data/data/com.termux/files/home/droidrundepedency/pythondroidruninstaller && export PATH=/data/data/com.termux/files/usr/bin:\$PATH && export HOME=/data/data/com.termux/files/home && export FORCE_RERUN=1 && python3 phase1_build_tools.py'"
```

## Using Helper Script

```bash
# Normal run
bash run_python_phase1_via_adb.sh

# Force rerun
FORCE_RERUN=1 bash run_python_phase1_via_adb.sh
```

## What It Does

1. **Fixes imports** - Ensures `common.py` has correct `List` import
2. **Sets environment** - Configures PATH and HOME for Termux
3. **Runs Phase 1** - Executes the Python installer script
4. **Shows output** - Displays colored logs and progress

## Requirements

- ADB connected to Android device
- Termux installed on device
- Python 3.x in Termux
- `packaging` package installed: `pip install packaging`

## Troubleshooting

### Import Error
The script automatically fixes the `List` import. If you see other import errors, check that you're in the correct directory.

### Permission Denied
Make sure ADB has proper permissions and device is authorized:
```bash
adb devices
```

### Module Not Found
Ensure you're running from the correct directory:
```bash
adb shell "run-as com.termux sh -c 'ls /data/data/com.termux/files/home/droidrundepedency/pythondroidruninstaller'"
```

## Success Output

You should see:
```
[INFO] Phase 1: Build Tools Installation
[INFO] Setting up build environment...
[✓] Build environment configured
[✓] All essential build tools are already installed
[✓] Phase 1 completed successfully
```

