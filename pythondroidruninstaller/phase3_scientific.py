#!/usr/bin/env python3
"""Phase 3: Install scipy, pandas, scikit-learn"""

import sys
import subprocess
from pathlib import Path

current_dir = Path(__file__).parent.absolute()
sys.path.insert(0, str(current_dir))

try:
    from .common import should_skip_phase, mark_phase_complete, setup_build_environment, python_pkg_installed, HOME, get_build_env_with_compilers, get_clean_env, log_info, log_success, log_error, log_warning
except ImportError:
    from common import should_skip_phase, mark_phase_complete, setup_build_environment, python_pkg_installed, HOME, get_build_env_with_compilers, get_clean_env, log_info, log_success, log_error, log_warning


def main() -> int:
    if should_skip_phase(3):
        return 0
    
    setup_build_environment()
    
    # scipy - needs CC/CXX for C/Fortran extensions
    if not python_pkg_installed("scipy", "scipy>=1.8.0,<1.17.0"):
        log_info("Installing scipy...")
        build_env = get_build_env_with_compilers()
        result = subprocess.run(
            [sys.executable, "-m", "pip", "install", "--no-cache-dir", "scipy>=1.8.0,<1.17.0"],
            env=build_env,
            check=False
        )
        if result.returncode != 0:
            log_error(f"scipy installation failed with exit code {result.returncode}")
            log_error("Check the output above for detailed error messages")
            return 1
        if not python_pkg_installed("scipy", "scipy>=1.8.0,<1.17.0"):
            log_error("scipy installation succeeded but package not found")
            return 1
        log_success("scipy installed successfully")
    
    # pandas - needs CC/CXX for C extensions
    if not python_pkg_installed("pandas", "pandas<2.3.0"):
        log_info("Installing pandas...")
        # Install deps first (pure Python, no CC/CXX needed)
        clean_env = get_clean_env()
        for dep in ["python-dateutil>=2.8.2", "pytz>=2020.1", "tzdata>=2022.7"]:
            result = subprocess.run([sys.executable, "-m", "pip", "install", "--no-cache-dir", dep], 
                         env=clean_env, check=False)
            if result.returncode != 0:
                log_warning(f"Failed to install {dep}, but continuing...")
        
        # Direct pip install with CC/CXX
        build_env = get_build_env_with_compilers()
        result = subprocess.run(
            [sys.executable, "-m", "pip", "install", "--no-cache-dir", "pandas<2.3.0"],
            env=build_env,
            check=False
        )
        if result.returncode != 0:
            log_error(f"pandas installation failed with exit code {result.returncode}")
            log_error("Check the output above for detailed error messages")
            return 1
        if not python_pkg_installed("pandas", "pandas<2.3.0"):
            log_error("pandas installation succeeded but package not found")
            return 1
        log_success("pandas installed successfully")
    
    # scikit-learn - needs CC/CXX for C extensions
    if not python_pkg_installed("scikit-learn", "scikit-learn"):
        log_info("Installing scikit-learn...")
        # Install deps first (pure Python, no CC/CXX needed)
        clean_env = get_clean_env()
        for dep in ["joblib>=1.3.0", "threadpoolctl>=3.2.0"]:
            result = subprocess.run([sys.executable, "-m", "pip", "install", "--no-cache-dir", dep], 
                         env=clean_env, check=False)
            if result.returncode != 0:
                log_warning(f"Failed to install {dep}, but continuing...")
        
        # Direct pip install with CC/CXX
        build_env = get_build_env_with_compilers()
        result = subprocess.run(
            [sys.executable, "-m", "pip", "install", "--no-cache-dir", "scikit-learn"],
            env=build_env,
            check=False
        )
        if result.returncode != 0:
            log_error(f"scikit-learn installation failed with exit code {result.returncode}")
            log_error("Check the output above for detailed error messages")
            return 1
        if not python_pkg_installed("scikit-learn", "scikit-learn"):
            log_error("scikit-learn installation succeeded but package not found")
            return 1
        log_success("scikit-learn installed successfully")
    
    # Verify all required packages are installed before marking complete
    required_packages = [
        ("scipy", "scipy>=1.8.0,<1.17.0"),
        ("pandas", "pandas<2.3.0"),
        ("scikit-learn", "scikit-learn>=1.0.0"),
    ]
    
    missing = []
    for pkg_name, version_spec in required_packages:
        if not python_pkg_installed(pkg_name, version_spec):
            missing.append(pkg_name)
    
    if missing:
        log_error(f"Phase 3 incomplete: missing packages: {', '.join(missing)}")
        return 1
    
    # Verify packages can be imported
    try:
        import scipy
        import pandas
        import sklearn
        log_success("All Phase 3 packages verified and working")
    except ImportError as e:
        log_error(f"Phase 3 verification failed: {e}")
        return 1
    
    mark_phase_complete(3)
    return 0


if __name__ == "__main__":
    sys.exit(main())
