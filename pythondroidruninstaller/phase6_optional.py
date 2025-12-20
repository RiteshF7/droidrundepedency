#!/usr/bin/env python3
"""Phase 6: Install optional packages"""

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
    for pkg in missing:
        wheel = find_wheels(pkg)
        if wheel:
            shutil.copy2(wheel, wheels_dir / wheel.name)
            result = subprocess.run(
                [sys.executable, "-m", "pip", "install", "--find-links", str(wheels_dir), pkg],
                capture_output=True,
                check=False
            )
            if result.returncode == 0:
                missing.remove(pkg)
    
    # Build remaining from source
    for pkg in missing:
        env_vars = {"CXXFLAGS": "-D_GNU_SOURCE"} if pkg == "tokenizers" else None
        build_package(pkg, pkg, env_vars=env_vars)
    
    mark_phase_complete(6)
    return 0


if __name__ == "__main__":
    import subprocess
    sys.exit(main())
