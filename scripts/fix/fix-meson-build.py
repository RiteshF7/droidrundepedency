#!/usr/bin/env python3
"""Fix meson.build to use python explicitly for version.py"""
import os
import sys

meson_file = os.path.expanduser("~/wheels/scikit-learn/meson.build")
python_path = "/data/data/com.termux/files/usr/bin/python3"

if not os.path.exists(meson_file):
    print(f"Error: {meson_file} not found")
    sys.exit(1)

# Read the file
with open(meson_file, 'r') as f:
    lines = f.readlines()

# Find and replace line 4
if len(lines) >= 4:
    # Line 4 should be the version line
    old_line = lines[3]  # 0-indexed, so line 4 is index 3
    new_line = f"  version: run_command(['{python_path}', 'sklearn/_build_utils/version.py'], check: true).stdout().strip(),\n"
    lines[3] = new_line
    
    # Write back
    with open(meson_file, 'w') as f:
        f.writelines(lines)
    
    print(f"✅ Fixed meson.build")
    print(f"Old: {old_line.strip()}")
    print(f"New: {new_line.strip()}")
else:
    print(f"Error: meson.build doesn't have enough lines")
    sys.exit(1)

