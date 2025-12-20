#!/usr/bin/env python3
"""Phase 4: Install jiter"""

import sys
import os
import shutil
from pathlib import Path

current_dir = Path(__file__).parent.absolute()
sys.path.insert(0, str(current_dir))

try:
    from .common import should_skip_phase, mark_phase_complete, setup_build_environment, python_pkg_installed, HOME
    from .build_utils import build_package
except ImportError:
    from common import should_skip_phase, mark_phase_complete, setup_build_environment, python_pkg_installed, HOME
    from build_utils import build_package


def find_wheel(name: str) -> Path:
    """Find pre-built wheel."""
    for deps_dir in [
        Path(__file__).parent.parent.parent / "depedencies" / "wheels",
        HOME / "droidrundepedency" / "depedencies" / "wheels",
        HOME / "depedencies" / "wheels",
    ]:
        for arch_dir in [deps_dir / "_x86_64_wheels", deps_dir / "arch64_wheels"]:
            if arch_dir.exists():
                wheel = next(arch_dir.glob(f"{name}*.whl"), None)
                if wheel:
                    return wheel
    return None


def main() -> int:
    if should_skip_phase(4):
        return 0
    
    setup_build_environment()
    
    if python_pkg_installed("jiter", "jiter==0.12.0"):
        mark_phase_complete(4)
        return 0
    
    # Try pre-built wheel
    jiter_wheel = find_wheel("jiter")
    if jiter_wheel:
        wheels_dir = Path(os.environ.get("WHEELS_DIR", str(HOME / "wheels")))
        shutil.copy2(jiter_wheel, wheels_dir / jiter_wheel.name)
        result = subprocess.run(
            [sys.executable, "-m", "pip", "install", "--find-links", str(wheels_dir), 
             "--no-index", str(jiter_wheel)],
            capture_output=True,
            check=False
        )
        if result.returncode == 0 and python_pkg_installed("jiter", "jiter==0.12.0"):
            mark_phase_complete(4)
            return 0
    
    # Build from source
    if not python_pkg_installed("maturin", "maturin"):
        return 1
    
    if build_package("jiter", "jiter==0.12.0"):
        mark_phase_complete(4)
        return 0
    
    return 1


if __name__ == "__main__":
    import subprocess
    sys.exit(main())
