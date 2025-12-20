# Manual Command to Run Phase 3

## Single Command (Copy and Paste)

```bash
adb shell "run-as com.termux sh -c 'export PATH=/data/data/com.termux/files/usr/bin:\$PATH && export HOME=/data/data/com.termux/files/home && cd /data/data/com.termux/files/home/droidrundepedency/pythondroidruninstaller && python3 phase3_scientific.py'"
```

## With Force Rerun

```bash
adb shell "run-as com.termux sh -c 'export PATH=/data/data/com.termux/files/usr/bin:\$PATH && export HOME=/data/data/com.termux/files/home && export FORCE_RERUN=1 && cd /data/data/com.termux/files/home/droidrundepedency/pythondroidruninstaller && python3 phase3_scientific.py'"
```

## Alternative Path (if above doesn't work)

```bash
adb shell "run-as com.termux sh -c 'export PATH=/data/data/com.termux/files/usr/bin:\$PATH && export HOME=/data/data/com.termux/files/home && cd ~/droidrundepedency/pythondroidruninstaller && python3 phase3_scientific.py'"
```

## Step by Step (if you prefer)

```bash
# 1. Check ADB connection
adb devices

# 2. Run Phase 3
adb shell "run-as com.termux sh -c 'export PATH=/data/data/com.termux/files/usr/bin:\$PATH && export HOME=/data/data/com.termux/files/home && cd /data/data/com.termux/files/home/droidrundepedency/pythondroidruninstaller && python3 phase3_scientific.py'"
```

## What It Does

- Sets up Termux environment (PATH, HOME)
- Changes to the Python installer directory
- Runs Phase 3 (scipy, pandas, scikit-learn)
- Shows colored output with progress
- Saves progress automatically

