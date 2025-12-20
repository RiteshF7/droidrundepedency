#!/usr/bin/env python3
"""Phase 6: Additional Compiled (optional)
Installs tokenizers, safetensors, cryptography, pydantic-core, orjson
"""

import sys
import os
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
    from .build_utils import build_package
except ImportError:
    from common import (
        log_info, log_success, log_warning, log_error,
        should_skip_phase, mark_phase_complete, save_env_vars,
        load_env_vars, setup_build_environment, init_logging,
        python_pkg_installed, run_command, HOME
    )
    from build_utils import build_package


def main() -> int:
    """Main function for Phase 6."""
    log_info("=" * 42)
    log_info("Phase 6: Optional Packages Installation")
    log_info("=" * 42)
    
    init_logging()
    
    if should_skip_phase(6):
        log_success("Phase 6 already completed (skipping)")
        log_info("To force rerun, set FORCE_RERUN=1 environment variable")
        return 0
    
    load_env_vars()
    setup_build_environment()
    
    log_info("Phase 6: Checking optional compiled packages...")
    
    optional_packages = ["tokenizers", "safetensors", "cryptography", "pydantic-core", "orjson"]
    missing_packages = [pkg for pkg in optional_packages if not python_pkg_installed(pkg, pkg)]
    
    if not missing_packages:
        log_success("Phase 6 complete: All optional packages already installed")
        mark_phase_complete(6)
        save_env_vars()
        return 0
    
    log_info(f"Installing missing optional packages: {', '.join(missing_packages)}")
    
    # Try to find pre-built wheels
    SCRIPT_DIR = Path(__file__).parent.absolute()
    dependencies_dirs = [
        SCRIPT_DIR.parent.parent / "depedencies" / "wheels",
        HOME / "droidrundepedency" / "depedencies" / "wheels",
        HOME / "depedencies" / "wheels",
    ]
    
    wheels_dir = Path(os.environ.get("WHEELS_DIR", str(HOME / "wheels")))
    
    for deps_dir in dependencies_dirs:
        if not deps_dir.exists():
            continue
        
        arch_dirs = [deps_dir / "_x86_64_wheels", deps_dir / "arch64_wheels"]
        for arch_dir in arch_dirs:
            if arch_dir.exists():
                log_info(f"Checking for pre-built wheels in {arch_dir}...")
                for pkg in missing_packages:
                    wheel_files = list(arch_dir.glob(f"{pkg}*.whl"))
                    if wheel_files:
                        log_info(f"Found pre-built wheel for {pkg}: {wheel_files[0].name}")
                        try:
                            shutil.copy2(wheel_files[0], wheels_dir / wheel_files[0].name)
                        except Exception:
                            pass
                break
    
    # Filter out already installed
    packages_to_install = [pkg for pkg in missing_packages if not python_pkg_installed(pkg, pkg)]
    
    if not packages_to_install:
        log_success("Phase 6 complete: All optional packages already installed")
        mark_phase_complete(6)
        save_env_vars()
        return 0
    
    # Try installing from wheels first
    installed_count = 0
    failed_packages = []
    
    for pkg in packages_to_install:
        log_info(f"Attempting to install {pkg}...")
        try:
            result = run_command(
                [sys.executable, "-m", "pip", "install", "--find-links", str(wheels_dir), pkg],
                check=False,
                capture_output=True
            )
            if result.returncode == 0 and python_pkg_installed(pkg, pkg):
                log_success(f"{pkg} installed successfully")
                installed_count += 1
                continue
        except Exception:
            pass
        
        failed_packages.append(pkg)
    
    # Build remaining packages from source
    if failed_packages:
        log_info(f"Some packages need building from source: {', '.join(failed_packages)}")
        for pkg in failed_packages:
            log_info(f"Processing package: {pkg}")
            
            # Special handling for tokenizers
            if pkg == "tokenizers":
                log_warning("NOTE: tokenizers build will likely fail on Android due to missing pthread_cond_clockwait")
                log_warning("This is expected - use pre-built wheel from dependencies folder instead")
                env_vars = {"CXXFLAGS": "-D_GNU_SOURCE"}
            else:
                env_vars = None
            
            if build_package(pkg, pkg, env_vars=env_vars):
                log_success(f"{pkg} built and installed")
            else:
                log_warning(f"Skipping {pkg} (build failed)")
                if pkg == "tokenizers":
                    log_warning("This is EXPECTED behavior on Android/Termux")
                    log_warning("Solution: Use pre-built wheel from depedencies/wheels/_x86_64_wheels/tokenizers*.whl")
    
    log_success("Phase 6 complete: Optional packages processed")
    mark_phase_complete(6)
    save_env_vars()
    
    log_success("Phase 6 completed successfully")
    return 0


if __name__ == "__main__":
    import os
    sys.exit(main())

