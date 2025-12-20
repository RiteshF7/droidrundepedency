#!/usr/bin/env python3
"""Phase 3: Scientific Stack
Installs scipy, pandas, scikit-learn
"""

import sys
import subprocess
from pathlib import Path
from typing import Optional

# Add current directory to path for imports
current_dir = Path(__file__).parent.absolute()
if str(current_dir) not in sys.path:
    sys.path.insert(0, str(current_dir))
parent_dir = current_dir.parent
if str(parent_dir) not in sys.path:
    sys.path.insert(0, str(parent_dir))

try:
    from .common import (
        log_info, log_success, log_warning, log_error,
        should_skip_phase, mark_phase_complete, save_env_vars,
        load_env_vars, setup_build_environment, init_logging,
        python_pkg_installed, run_command, HOME, SCRIPT_DIR
    )
    from .build_utils import build_package
except ImportError:
    from common import (
        log_info, log_success, log_warning, log_error,
        should_skip_phase, mark_phase_complete, save_env_vars,
        load_env_vars, setup_build_environment, init_logging,
        python_pkg_installed, run_command, HOME
    )
    from build_utils import build_package
    SCRIPT_DIR = Path(__file__).parent.absolute()


def find_build_script(script_name: str) -> Optional[Path]:
    """Find a build script in common locations."""
    locations = [
        SCRIPT_DIR.parent / script_name,
        HOME / "droidrundepedency" / script_name,
        Path(".") / script_name,
    ]
    for loc in locations:
        if loc.exists():
            return loc
    return None


def main() -> int:
    """Main function for Phase 3."""
    log_info("=" * 42)
    log_info("Phase 3: Scientific Stack Installation")
    log_info("=" * 42)
    
    init_logging()
    
    if should_skip_phase(3):
        log_success("Phase 3 already completed (skipping)")
        log_info("To force rerun, set FORCE_RERUN=1 environment variable")
        return 0
    
    load_env_vars()
    setup_build_environment()
    
    log_info("Phase 3: Building scientific stack...")
    
    # Build scipy
    if not build_package("scipy", "scipy>=1.8.0,<1.17.0"):
        log_error("Failed to build scipy - this is required, exiting")
        return 1
    
    # Build pandas
    if python_pkg_installed("pandas", "pandas<2.3.0"):
        log_success("pandas is already installed and satisfies version requirement (pandas<2.3.0), skipping build")
    else:
        log_info("pandas not installed or version requirement (pandas<2.3.0) not satisfied, will build")
        
        # Pre-install dependencies
        log_info("Pre-installing pandas runtime dependencies...")
        pandas_deps = [
            "python-dateutil>=2.8.2",
            "pytz>=2020.1",
            "tzdata>=2022.7",
        ]
        
        for dep in pandas_deps:
            dep_name = dep.split('>=')[0].split('<')[0].split('==')[0]
            if not python_pkg_installed(dep_name, dep):
                log_info(f"Installing {dep}...")
                try:
                    run_command([sys.executable, "-m", "pip", "install", dep], check=False)
                    log_success(f"{dep} installed")
                except Exception as e:
                    log_warning(f"Failed to install {dep}: {e}")
        
        # Try build script first
        build_script = find_build_script("build_pandas.sh")
        if build_script:
            log_info(f"Using build script: {build_script}")
            try:
                result = run_command(["bash", str(build_script)], check=False)
                if result.returncode == 0:
                    log_success("pandas built and installed successfully using build_pandas.sh")
                else:
                    log_error("Failed to build pandas using build_pandas.sh - falling back to build_package")
                    if not build_package("pandas", "pandas<2.3.0", fix_source="pandas"):
                        log_error("Failed to build pandas - this is required, exiting")
                        return 1
            except Exception as e:
                log_warning(f"Build script failed: {e}, falling back to build_package")
                if not build_package("pandas", "pandas<2.3.0", fix_source="pandas"):
                    log_error("Failed to build pandas - this is required, exiting")
                    return 1
        else:
            log_warning("build_pandas.sh not found, using build_package method")
            if not build_package("pandas", "pandas<2.3.0", fix_source="pandas"):
                log_error("Failed to build pandas - this is required, exiting")
                return 1
    
    # Build scikit-learn
    if python_pkg_installed("scikit-learn", "scikit-learn"):
        log_success("scikit-learn is already installed, skipping build")
    else:
        log_info("scikit-learn not installed, will build")
        
        # Pre-install dependencies
        log_info("Pre-installing scikit-learn runtime dependencies...")
        sklearn_deps = [
            "joblib>=1.3.0",
            "threadpoolctl>=3.2.0",
        ]
        
        for dep in sklearn_deps:
            dep_name = dep.split('>=')[0].split('<')[0].split('==')[0]
            if not python_pkg_installed(dep_name, dep):
                log_info(f"Installing {dep}...")
                try:
                    run_command([sys.executable, "-m", "pip", "install", dep], check=False)
                except Exception:
                    pass
        
        # Try build script first
        build_script = find_build_script("build_scikit_learn.sh")
        if build_script:
            log_info(f"Using build script: {build_script}")
            try:
                result = run_command(["bash", str(build_script)], check=False)
                if result.returncode == 0:
                    log_success("scikit-learn built and installed successfully using build_scikit_learn.sh")
                else:
                    log_warning("Failed to build scikit-learn using build script - falling back")
                    if not build_package("scikit-learn", "scikit-learn", 
                                        fix_source="scikit-learn", 
                                        no_build_isolation=True,
                                        wheel_pattern="scikit_learn*.whl"):
                        log_warning("Failed to build scikit-learn - continuing without it")
            except Exception:
                if not build_package("scikit-learn", "scikit-learn",
                                    fix_source="scikit-learn",
                                    no_build_isolation=True,
                                    wheel_pattern="scikit_learn*.whl"):
                    log_warning("Failed to build scikit-learn - continuing without it")
        else:
            log_warning("build_scikit_learn.sh not found, using build_package method")
            if not build_package("scikit-learn", "scikit-learn",
                                fix_source="scikit-learn",
                                no_build_isolation=True,
                                wheel_pattern="scikit_learn*.whl"):
                log_warning("Failed to build scikit-learn - continuing without it")
    
    log_success("Phase 3 complete: Scientific stack installed")
    mark_phase_complete(3)
    save_env_vars()
    
    log_success("Phase 3 completed successfully")
    return 0


if __name__ == "__main__":
    sys.exit(main())

