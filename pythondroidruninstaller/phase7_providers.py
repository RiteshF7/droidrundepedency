#!/usr/bin/env python3
"""Phase 7: Main Package + LLM Providers
Installs droidrun and LLM providers
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
        log_info, log_success, log_warning, log_error,
        should_skip_phase, mark_phase_complete, save_env_vars,
        load_env_vars, setup_build_environment, init_logging,
        python_pkg_installed, run_command, HOME
    )
except ImportError:
    from common import (
        log_info, log_success, log_warning, log_error,
        should_skip_phase, mark_phase_complete, save_env_vars,
        load_env_vars, setup_build_environment, init_logging,
        python_pkg_installed, run_command, HOME
    )


def find_providers_script() -> Path:
    """Find install_droidrun_providers.sh script."""
    SCRIPT_DIR = Path(__file__).parent.absolute()
    locations = [
        SCRIPT_DIR.parent / "install_droidrun_providers.sh",
        HOME / "droidrundepedency" / "install_droidrun_providers.sh",
        Path(".") / "install_droidrun_providers.sh",
    ]
    for loc in locations:
        if loc.exists():
            return loc
    return None


def main() -> int:
    """Main function for Phase 7."""
    log_info("=" * 42)
    log_info("Phase 7: Droidrun and Providers Installation")
    log_info("=" * 42)
    
    init_logging()
    
    if should_skip_phase(7):
        log_success("Phase 7 already completed (skipping)")
        log_info("To force rerun, set FORCE_RERUN=1 environment variable")
        return 0
    
    load_env_vars()
    setup_build_environment()
    
    log_info("Phase 7: Installing droidrun and LLM providers...")
    
    # Find providers script
    providers_script = find_providers_script()
    
    if providers_script:
        log_info(f"Using provider installation script: {providers_script}")
        try:
            result = run_command(["bash", str(providers_script)], check=False)
            if result.returncode == 0:
                log_success("Phase 7 complete: droidrun and providers installed")
            else:
                log_error("Failed to install droidrun providers")
                log_error("Provider installation script failed")
                return 1
        except Exception as e:
            log_error(f"Error running providers script: {e}")
            return 1
    else:
        log_warning("install_droidrun_providers.sh not found, falling back to inline installation")
        log_warning("Expected locations:")
        log_warning(f"  {Path(__file__).parent.parent / 'install_droidrun_providers.sh'}")
        log_warning(f"  {HOME / 'droidrundepedency' / 'install_droidrun_providers.sh'}")
        log_warning("  ./install_droidrun_providers.sh")
        
        # Fallback: Install droidrun core only
        if python_pkg_installed("droidrun", "droidrun"):
            log_success("droidrun is already installed")
        else:
            log_info("Installing droidrun core...")
            wheels_dir = Path(os.environ.get("WHEELS_DIR", str(HOME / "wheels")))
            result = run_command(
                [sys.executable, "-m", "pip", "install", "droidrun", 
                 "--find-links", str(wheels_dir)],
                check=False,
                capture_output=True
            )
            if result.returncode == 0:
                log_success("droidrun core installed")
                log_warning("Run install_droidrun_providers.sh separately to install LLM providers")
            else:
                log_error("Failed to install droidrun core")
                return 1
        
        log_success("Phase 7 complete: droidrun core installed")
    
    mark_phase_complete(7)
    save_env_vars()
    
    log_success("Phase 7 completed successfully")
    return 0


if __name__ == "__main__":
    import os
    sys.exit(main())

