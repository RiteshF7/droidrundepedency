#!/usr/bin/env python3
"""Example usage of the Python droidrun installer."""

import sys
from pathlib import Path

# Add parent directory to path
sys.path.insert(0, str(Path(__file__).parent.parent))

from pythondroidruninstaller.phase1_build_tools import main

if __name__ == "__main__":
    print("Running Phase 1: Build Tools Installation")
    print("=" * 50)
    exit_code = main()
    sys.exit(exit_code)

