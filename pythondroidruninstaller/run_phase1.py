#!/usr/bin/env python3
"""Entry point for Phase 1 - can be run directly from the package directory."""

import sys
from pathlib import Path

# Add current directory to path
current_dir = Path(__file__).parent.absolute()
sys.path.insert(0, str(current_dir))

# Import and run phase1
from phase1_build_tools import main

if __name__ == "__main__":
    sys.exit(main())

