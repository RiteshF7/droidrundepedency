#!/usr/bin/env python3
"""Phase 2: Install numpy"""

import sys
import os
import subprocess
from pathlib import Path

current_dir = Path(__file__).parent.absolute()
sys.path.insert(0, str(current_dir))

try:
    from .common import should_skip_phase, mark_phase_complete, setup_build_environment, python_pkg_installed, get_build_env_with_compilers, log_info, log_success, log_error
except ImportError:
    from common import should_skip_phase, mark_phase_complete, setup_build_environment, python_pkg_installed, get_build_env_with_compilers, log_info, log_success, log_error


def main() -> int:
    if should_skip_phase(2):
        return 0
    
    setup_build_environment()
    
    if python_pkg_installed("numpy", "numpy"):
        log_success("numpy is already installed")
        mark_phase_complete(2)
        return 0
    
    log_info("Installing numpy...")
    # numpy needs CC/CXX overrides for C/Fortran extensions
    build_env = get_build_env_with_compilers()
    
    # Try simple pip install first
    result = subprocess.run(
        [sys.executable, "-m", "pip", "install", "--no-cache-dir", "numpy"],
        env=build_env,
        check=False
    )
    
    if result.returncode == 0 and python_pkg_installed("numpy", "numpy"):
        log_success("numpy installed successfully")
        mark_phase_complete(2)
        return 0
    
    log_error("Failed to install numpy")
    return 1


if __name__ == "__main__":
    sys.exit(main())
