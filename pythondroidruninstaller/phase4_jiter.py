#!/usr/bin/env python3
"""Phase 4: Rust Packages (jiter)
Installs jiter
"""

import sys
import time
import shutil
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
        log_info, log_success, log_warning, log_error,
        should_skip_phase, mark_phase_complete, save_env_vars,
        load_env_vars, setup_build_environment, init_logging,
        python_pkg_installed, run_command, HOME
    )
    from .build_utils import build_package, find_prebuilt_wheel
except ImportError:
    from common import (
        log_info, log_success, log_warning, log_error,
        should_skip_phase, mark_phase_complete, save_env_vars,
        load_env_vars, setup_build_environment, init_logging,
        python_pkg_installed, run_command, HOME
    )
    from build_utils import build_package


def find_prebuilt_wheel(wheel_name: str) -> Path:
    """Find a pre-built wheel in dependencies directories."""
    dependencies_dirs = [
        Path(__file__).parent.parent.parent / "depedencies" / "wheels",
        HOME / "droidrundepedency" / "depedencies" / "wheels",
        HOME / "depedencies" / "wheels",
    ]
    
    for deps_dir in dependencies_dirs:
        if not deps_dir.exists():
            continue
        
        arch_dirs = [
            deps_dir / "_x86_64_wheels",
            deps_dir / "arch64_wheels",
        ]
        
        for arch_dir in arch_dirs:
            if arch_dir.exists():
                wheel_file = next(arch_dir.glob(f"{wheel_name}*.whl"), None)
                if wheel_file and wheel_file.exists():
                    return wheel_file
    
    return None


def main() -> int:
    """Main function for Phase 4."""
    log_info("=" * 42)
    log_info("Phase 4: Jiter Installation")
    log_info("=" * 42)
    
    init_logging()
    
    if should_skip_phase(4):
        log_success("Phase 4 already completed (skipping)")
        log_info("To force rerun, set FORCE_RERUN=1 environment variable")
        return 0
    
    load_env_vars()
    setup_build_environment()
    
    log_info("Phase 4: Installing jiter...")
    jiter_built = False
    
    # Try pre-built wheel first
    log_info("Checking for pre-built jiter wheel...")
    import os
    SCRIPT_DIR = Path(__file__).parent.absolute()
    dependencies_dirs = [
        SCRIPT_DIR.parent.parent / "depedencies" / "wheels",
        HOME / "droidrundepedency" / "depedencies" / "wheels",
        HOME / "depedencies" / "wheels",
    ]
    
    jiter_wheel = None
    for deps_dir in dependencies_dirs:
        if not deps_dir.exists():
            continue
        arch_dirs = [deps_dir / "_x86_64_wheels", deps_dir / "arch64_wheels"]
        for arch_dir in arch_dirs:
            if arch_dir.exists():
                wheel_file = next(arch_dir.glob("jiter*.whl"), None)
                if wheel_file and wheel_file.exists():
                    jiter_wheel = wheel_file
                    break
        if jiter_wheel:
            break
    
    if jiter_wheel:
        log_info(f"Found pre-built jiter wheel: {jiter_wheel.name}")
        wheels_dir = Path(os.environ.get("WHEELS_DIR", str(HOME / "wheels")))
        try:
            shutil.copy2(jiter_wheel, wheels_dir / jiter_wheel.name)
        except Exception:
            pass
        
        log_info("Installing jiter from pre-built wheel...")
        try:
            result = run_command(
                [sys.executable, "-m", "pip", "install",
                 "--find-links", str(wheels_dir), "--no-index", str(jiter_wheel)],
                check=False,
                capture_output=True
            )
            if result.returncode == 0 and python_pkg_installed("jiter", "jiter==0.12.0"):
                jiter_built = True
                log_success("jiter installed from pre-built wheel")
        except Exception:
            log_warning("Failed to install jiter from pre-built wheel, will try building from source")
    
    # Build from source if needed
    if not jiter_built:
        if not python_pkg_installed("maturin", "maturin"):
            log_error("maturin is not installed - cannot build jiter from source")
            log_error("jiter requires maturin to build. Please ensure maturin is installed first.")
            log_error("Try running Phase 1 again or install maturin manually: pip install maturin<2,>=1.9.4")
        else:
            log_info("Building jiter from source (maturin is available)...")
            for attempt in [1, 2]:
                if attempt > 1:
                    log_info(f"Retrying jiter build (attempt {attempt})...")
                    time.sleep(5)
                
                if build_package("jiter", "jiter==0.12.0"):
                    if python_pkg_installed("jiter", "jiter==0.12.0"):
                        jiter_built = True
                        break
                else:
                    log_warning(f"jiter build failed (attempt {attempt})")
    
    if not jiter_built:
        log_warning("=" * 78)
        log_warning("jiter installation failed - continuing without it")
        log_warning("This may be due to maturin build failure or Rust compilation issues")
        log_warning("Some droidrun features may not work without jiter")
        log_warning("Solution: Ensure pre-built jiter wheel is available in dependencies folder")
        log_warning("=" * 78)
    else:
        log_success("jiter installed successfully")
    
    log_success("Phase 4 complete: jiter processed")
    mark_phase_complete(4)
    save_env_vars()
    
    log_success("Phase 4 completed successfully")
    return 0


if __name__ == "__main__":
    import os
    sys.exit(main())

