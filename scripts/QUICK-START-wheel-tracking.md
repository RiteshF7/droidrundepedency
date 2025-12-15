# Quick Start: Wheel Tracking Script

## 🚀 Quick Usage

### Install a new package and export its wheel:
```bash
cd droidrunBuild/scripts
./track-and-export-wheels.sh --install "package-name"
```

### After manually installing packages, track and export:
```bash
./track-and-export-wheels.sh --track-new
```

### Just export existing wheels:
```bash
./track-and-export-wheels.sh --export-only
```

## 📋 Common Workflow

1. **Install a dependency:**
   ```bash
   ./track-and-export-wheels.sh --install "numpy"
   ```

2. **Or install manually in Termux, then track:**
   ```bash
   # In Termux or via ADB
   pip install scipy pandas
   
   # Then run tracking script
   ./track-and-export-wheels.sh --track-new
   ```

3. **All wheels are exported to:**
   ```
   droidrunBuild/newwhlfilesall/
   ```

## 📁 Files

- **Script:** `droidrunBuild/scripts/track-and-export-wheels.sh`
- **Windows wrapper:** `droidrunBuild/scripts/track-and-export-wheels.bat`
- **Export directory:** `droidrunBuild/newwhlfilesall/`
- **Tracking file:** `droidrunBuild/newwhlfilesall/installed-packages.txt`

## ✅ What It Does

1. ✅ Installs packages (if `--install` used)
2. ✅ Builds/downloads wheel files
3. ✅ Exports wheels from device to local folder
4. ✅ Tracks installed packages to detect new ones
5. ✅ Skips duplicates automatically

## 🔧 Requirements

- ADB connected device/emulator
- Root access or `run-as com.termux` capability
- Git Bash (for Windows) or bash shell



