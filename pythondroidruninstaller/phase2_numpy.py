#!/usr/bin/env python3
"""Phase 2: Install numpy"""

import sys
from pathlib import Path

current_dir = Path(__file__).parent.absolute()
sys.path.insert(0, str(current_dir))

try:
    from .common import should_skip_phase, mark_phase_complete, setup_build_environment
    from .build_utils import build_package
except ImportError:
    from common import should_skip_phase, mark_phase_complete, setup_build_environment
    from build_utils import build_package


def main() -> int:
    if should_skip_phase(2):
        return 0
    
    setup_build_environment()
    
    if not build_package("numpy", "numpy"):
        return 1
    
    mark_phase_complete(2)
    return 0


if __name__ == "__main__":
    sys.exit(main())
