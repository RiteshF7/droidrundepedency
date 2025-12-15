# Wheel Tracking and Export Script

This script automatically tracks newly installed Python packages and exports their wheel files to a local directory.

## Usage

### 1. Install packages and automatically export wheels

```bash
# Install a single package
./track-and-export-wheels.sh --install "numpy"

# Install multiple packages
./track-and-export-wheels.sh --install "scipy" "pandas" "scikit-learn"

# Install with version constraints
./track-and-export-wheels.sh --install "meson-python<0.19.0,>=0.16.0"
```

### 2. Track and export only new packages

After installing packages manually, use this to find and export wheels for newly installed packages:

```bash
./track-and-export-wheels.sh --track-new
```

This will:
- Compare currently installed packages with previously tracked packages
- Build wheels for any new packages found
- Export all wheels to local directory
- Update the tracking file

### 3. Export existing wheels only

If you just want to export wheels that are already on the device:

```bash
./track-and-export-wheels.sh --export-only
```

## How It Works

1. **Installation**: If `--install` flag is used, packages are installed via pip in Termux
2. **Wheel Building**: For each package, the script builds/downloads the wheel file using `pip wheel`
3. **Export**: All wheel files from `~/wheels-export` on device are copied to local directory
4. **Tracking**: Installed packages are tracked in `installed-packages.txt` to detect new packages later

## Configuration

Edit the script to change:
- `EXPORT_DIR_LOCAL`: Local directory where wheels are exported (default: `E:/Code/LunarLand/MiniLinux/droidrunBuild/newwhlfilesall`)
- `EXPORT_DIR_TERMUX`: Device directory where wheels are stored (default: `/data/user/0/com.termux/wheels-export`)

## Example Workflow

```bash
# 1. Install a new dependency
./track-and-export-wheels.sh --install "Cython"

# 2. Later, install more packages manually in Termux
adb shell "run-as com.termux sh -c 'pip install numpy scipy'"

# 3. Track and export the new packages
./track-and-export-wheels.sh --track-new

# 4. All wheels are now in: droidrunBuild/newwhlfilesall/
```

## Files Created

- `droidrunBuild/newwhlfilesall/*.whl` - All exported wheel files
- `droidrunBuild/newwhlfilesall/installed-packages.txt` - List of tracked packages

## Notes

- The script requires ADB connection and root access (or run-as com.termux)
- Wheel files are stored in `~/wheels-export` on the device
- Duplicate wheels are skipped during export
- The script tracks packages by name only (not versions)



