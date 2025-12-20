# Quick Start Guide

## Running Phase 1 from Termux

You're already in the right directory! Just run:

```bash
python3 phase1_build_tools.py
```

That's it! The script will automatically find and import the `common.py` module.

## Alternative Methods

### Method 1: Direct execution (Easiest)
```bash
cd ~/droidrundepedency/pythondroidruninstaller
python3 phase1_build_tools.py
```

### Method 2: Using entry point
```bash
cd ~/droidrundepedency/pythondroidruninstaller
python3 run_phase1.py
```

### Method 3: Install as package (for advanced use)
```bash
cd ~/droidrundepedency/pythondroidruninstaller
pip install -e .
python3 -m pythondroidruninstaller.phase1_build_tools
```

## Troubleshooting

### "ModuleNotFoundError: No module named 'pythondroidruninstaller'"

**Solution:** Run the script directly from within the package directory:
```bash
cd ~/droidrundepedency/pythondroidruninstaller
python3 phase1_build_tools.py
```

### "ModuleNotFoundError: No module named 'common'"

**Solution:** Make sure you're in the `pythondroidruninstaller` directory:
```bash
pwd  # Should show: .../pythondroidruninstaller
ls   # Should show: common.py, phase1_build_tools.py, etc.
python3 phase1_build_tools.py
```

## Current Directory Check

If you're in `~/droidrundepedency/pythondroidruninstaller`, you should see:
```
common.py
phase1_build_tools.py
run_phase1.py
requirements.txt
README.md
__init__.py
```

Then simply run:
```bash
python3 phase1_build_tools.py
```

