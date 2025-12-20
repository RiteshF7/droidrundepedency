#!/usr/bin/env python3
"""Phase 2: Install numpy"""

import sys
import os
import subprocess
from pathlib import Path

current_dir = Path(__file__).parent.absolute()
sys.path.insert(0, str(current_dir))

try:
    from .common import should_skip_phase, mark_phase_complete, setup_build_environment, python_pkg_installed, get_build_env_with_compilers, log_info, log_success, log_error, log_warning, pkg_installed, IS_TERMUX, command_exists
except ImportError:
    from common import should_skip_phase, mark_phase_complete, setup_build_environment, python_pkg_installed, get_build_env_with_compilers, log_info, log_success, log_error, log_warning, pkg_installed, IS_TERMUX, command_exists


def verify_numpy() -> bool:
    """Verify numpy is installed and can be imported."""
    if not python_pkg_installed("numpy", "numpy>=1.26.0"):
        return False
    
    # Try to actually import and use numpy
    try:
        import numpy as np
        # Test basic functionality
        arr = np.array([1, 2, 3])
        if len(arr) != 3:
            return False
        log_success("numpy verified and working")
        return True
    except Exception as e:
        log_error(f"numpy import/verification failed: {e}")
        return False


def main() -> int:
    if should_skip_phase(2):
        # Still verify even if phase is marked complete
        if verify_numpy():
            return 0
        else:
            log_warning("Phase 2 marked complete but numpy verification failed")
            # Don't return 0 - force reinstall
    
    setup_build_environment()
    
    # Check if numpy is already installed and working
    if verify_numpy():
        log_success("numpy is already installed and verified")
        mark_phase_complete(2)
        return 0
    
    # Install patchelf system package (required to avoid building Python patchelf)
    if not pkg_installed("patchelf"):
        log_info("Installing patchelf system package (required for numpy builds)...")
        if IS_TERMUX and command_exists("pkg"):
            result = subprocess.run(["pkg", "install", "-y", "patchelf"], check=False)
            if result.returncode != 0:
                log_warning("Failed to install patchelf system package - numpy build may fail")
            else:
                log_success("patchelf system package installed")
        else:
            log_warning("Cannot install patchelf - pkg command not available")
    
    log_info("Installing numpy...")
    # numpy needs CC/CXX overrides for C/Fortran extensions
    build_env = get_build_env_with_compilers()
    
    # Try simple pip install first
    result = subprocess.run(
        [sys.executable, "-m", "pip", "install", "--no-cache-dir", "numpy>=1.26.0"],
        env=build_env,
        check=False
    )
    
    # Check installation result
    if result.returncode != 0:
        log_error(f"numpy installation failed with exit code {result.returncode}")
        log_error("Check the output above for detailed error messages")
        return 1
    
    # Verify installation worked
    if verify_numpy():
        log_success("numpy installed and verified successfully")
        mark_phase_complete(2)
        return 0
    
    log_error("numpy installation reported success but verification failed")
    return 1


if __name__ == "__main__":
    sys.exit(main())
