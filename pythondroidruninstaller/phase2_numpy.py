#!/usr/bin/env python3
"""Phase 2: Foundation (numpy)
Installs numpy
"""

import sys
from pathlib import Path

# Add current directory to path for imports
current_dir = Path(__file__).parent.absolute()
if str(current_dir) not in sys.path:
    sys.path.insert(0, str(current_dir))
parent_dir = current_dir.parent
if str(parent_dir) not in sys.path:
    sys.path.insert(0, str(parent_dir))

try:
    from .common import (
        log_info, log_success, log_error,
        should_skip_phase, mark_phase_complete, save_env_vars,
        load_env_vars, setup_build_environment, init_logging,
    )
    from .build_utils import build_package
except ImportError:
    from common import (
        log_info, log_success, log_error,
        should_skip_phase, mark_phase_complete, save_env_vars,
        load_env_vars, setup_build_environment, init_logging,
    )
    from build_utils import build_package


def main() -> int:
    """Main function for Phase 2."""
    log_info("=" * 42)
    log_info("Phase 2: NumPy Installation")
    log_info("=" * 42)
    
    init_logging()
    
    if should_skip_phase(2):
        log_success("Phase 2 already completed (skipping)")
        log_info("To force rerun, set FORCE_RERUN=1 environment variable")
        return 0
    
    load_env_vars()
    setup_build_environment()
    
    log_info("Phase 2: Building numpy...")
    if not build_package("numpy", "numpy"):
        log_error("Failed to build numpy - this is required")
        return 1
    
    log_success("Phase 2 complete: numpy installed")
    mark_phase_complete(2)
    save_env_vars()
    
    log_success("Phase 2 completed successfully")
    return 0


if __name__ == "__main__":
    sys.exit(main())

