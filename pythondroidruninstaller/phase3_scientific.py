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


def find_script(name: str) -> Path:
    """Find build script."""
    for loc in [Path(__file__).parent.parent / name, HOME / "droidrundepedency" / name]:
        if loc.exists():
            return loc
    return None


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
        if result.returncode != 0 or not python_pkg_installed("scipy", "scipy>=1.8.0,<1.17.0"):
            log_error("Failed to install scipy")
            return 1
        log_success("scipy installed successfully")
    
    # pandas - needs CC/CXX for C extensions
    if not python_pkg_installed("pandas", "pandas<2.3.0"):
        log_info("Installing pandas...")
        # Install deps first (pure Python, no CC/CXX needed)
        clean_env = get_clean_env()
        for dep in ["python-dateutil>=2.8.2", "pytz>=2020.1", "tzdata>=2022.7"]:
            subprocess.run([sys.executable, "-m", "pip", "install", "--no-cache-dir", dep], 
                         env=clean_env, capture_output=True, check=False)
        
        # Try build script first
        build_script = find_script("build_pandas.sh")
        if build_script:
            result = subprocess.run(["bash", str(build_script)], check=False)
            if result.returncode == 0 and python_pkg_installed("pandas", "pandas<2.3.0"):
                log_success("pandas installed via build script")
            else:
                # Fallback to pip install with CC/CXX
                build_env = get_build_env_with_compilers()
                result = subprocess.run(
                    [sys.executable, "-m", "pip", "install", "--no-cache-dir", "pandas<2.3.0"],
                    env=build_env,
                    check=False
                )
                if result.returncode != 0 or not python_pkg_installed("pandas", "pandas<2.3.0"):
                    log_error("Failed to install pandas")
                    return 1
                log_success("pandas installed successfully")
        else:
            # Direct pip install with CC/CXX
            build_env = get_build_env_with_compilers()
            result = subprocess.run(
                [sys.executable, "-m", "pip", "install", "--no-cache-dir", "pandas<2.3.0"],
                env=build_env,
                check=False
            )
            if result.returncode != 0 or not python_pkg_installed("pandas", "pandas<2.3.0"):
                log_error("Failed to install pandas")
                return 1
            log_success("pandas installed successfully")
    
    # scikit-learn - needs CC/CXX for C extensions
    if not python_pkg_installed("scikit-learn", "scikit-learn"):
        log_info("Installing scikit-learn...")
        # Install deps first (pure Python, no CC/CXX needed)
        clean_env = get_clean_env()
        for dep in ["joblib>=1.3.0", "threadpoolctl>=3.2.0"]:
            subprocess.run([sys.executable, "-m", "pip", "install", "--no-cache-dir", dep], 
                         env=clean_env, capture_output=True, check=False)
        
        # Try build script first
        build_script = find_script("build_scikit_learn.sh")
        if build_script:
            result = subprocess.run(["bash", str(build_script)], check=False)
            if result.returncode == 0 and python_pkg_installed("scikit-learn", "scikit-learn"):
                log_success("scikit-learn installed via build script")
            else:
                # Fallback to pip install with CC/CXX
                build_env = get_build_env_with_compilers()
                result = subprocess.run(
                    [sys.executable, "-m", "pip", "install", "--no-cache-dir", "scikit-learn"],
                    env=build_env,
                    check=False
                )
                if result.returncode != 0 or not python_pkg_installed("scikit-learn", "scikit-learn"):
                    log_warning("scikit-learn installation failed, but continuing...")
        else:
            # Direct pip install with CC/CXX
            build_env = get_build_env_with_compilers()
            result = subprocess.run(
                [sys.executable, "-m", "pip", "install", "--no-cache-dir", "scikit-learn"],
                env=build_env,
                check=False
            )
            if result.returncode != 0:
                log_warning("scikit-learn installation failed, but continuing...")
    
    mark_phase_complete(3)
    return 0


if __name__ == "__main__":
    sys.exit(main())
