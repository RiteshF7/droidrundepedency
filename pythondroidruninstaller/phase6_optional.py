#!/usr/bin/env python3
"""Phase 6: Install optional packages"""

import sys
import os
import shutil
import subprocess
from pathlib import Path

current_dir = Path(__file__).parent.absolute()
sys.path.insert(0, str(current_dir))

try:
    from .common import should_skip_phase, mark_phase_complete, setup_build_environment, python_pkg_installed, HOME, log_error, log_info, log_success
except ImportError:
    from common import should_skip_phase, mark_phase_complete, setup_build_environment, python_pkg_installed, HOME, log_error, log_info, log_success


def find_wheels(pkg_name: str) -> Path:
    """Find pre-built wheel."""
    for deps_dir in [
        Path(__file__).parent.parent.parent / "depedencies" / "wheels",
        HOME / "droidrundepedency" / "depedencies" / "wheels",
        HOME / "depedencies" / "wheels",
    ]:
        for arch_dir in [deps_dir / "_x86_64_wheels", deps_dir / "arch64_wheels"]:
            if arch_dir.exists():
                wheel = next(arch_dir.glob(f"{pkg_name}*.whl"), None)
                if wheel:
                    return wheel
    return None


def main() -> int:
    if should_skip_phase(6):
        return 0
    
    setup_build_environment()
    
    packages = ["tokenizers", "safetensors", "cryptography", "pydantic-core", "orjson"]
    missing = [pkg for pkg in packages if not python_pkg_installed(pkg, pkg)]
    
    if not missing:
        mark_phase_complete(6)
        return 0
    
    wheels_dir = Path(os.environ.get("WHEELS_DIR", str(HOME / "wheels")))
    
    # Copy pre-built wheels
    installed_from_wheels = []
    for pkg in missing[:]:  # Use slice copy to avoid modification during iteration
        wheel = find_wheels(pkg)
        if wheel:
            wheels_dir.mkdir(parents=True, exist_ok=True)
            shutil.copy2(wheel, wheels_dir / wheel.name)
            result = subprocess.run(
                [sys.executable, "-m", "pip", "install", "--find-links", str(wheels_dir), pkg],
                capture_output=True,
                check=False
            )
            if result.returncode == 0 and python_pkg_installed(pkg, pkg):
                installed_from_wheels.append(pkg)
                missing.remove(pkg)
    
    # Install remaining packages directly from source using pip
    # This is simpler and more reliable than the build_package approach
    for pkg in missing:
        log_info(f"Installing {pkg} from source...")
        
        # Set environment variables if needed
        env = os.environ.copy()
        if pkg == "tokenizers":
            env["CXXFLAGS"] = "-D_GNU_SOURCE"
        
        # Use direct pip install - it will build from source automatically
        result = subprocess.run(
            [sys.executable, "-m", "pip", "install", "--no-cache-dir", pkg],
            env=env,
            check=False
        )
        
        if result.returncode != 0:
            log_error(f"Failed to install {pkg}")
            return 1
        
        # Verify installation
        if not python_pkg_installed(pkg, pkg):
            log_error(f"{pkg} installation completed but package not found")
            return 1
        
        log_success(f"{pkg} installed successfully")
    
    # Verify all packages are installed
    still_missing = [pkg for pkg in packages if not python_pkg_installed(pkg, pkg)]
    if still_missing:
        log_error(f"Phase 6 failed: packages still missing: {still_missing}")
        return 1
    
    mark_phase_complete(6)
    return 0


if __name__ == "__main__":
    sys.exit(main())
