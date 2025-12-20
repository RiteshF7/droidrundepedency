#!/usr/bin/env python3
"""Phase 7: Install droidrun and providers"""

import sys
import subprocess
from pathlib import Path

current_dir = Path(__file__).parent.absolute()
sys.path.insert(0, str(current_dir))

try:
    from .common import should_skip_phase, mark_phase_complete, setup_build_environment, python_pkg_installed, HOME
except ImportError:
    from common import should_skip_phase, mark_phase_complete, setup_build_environment, python_pkg_installed, HOME


def find_providers_script() -> Path:
    """Find install_droidrun_providers.sh."""
    for loc in [
        Path(__file__).parent.parent / "install_droidrun_providers.sh",
        HOME / "droidrundepedency" / "install_droidrun_providers.sh",
    ]:
        if loc.exists():
            return loc
    return None


def main() -> int:
    if should_skip_phase(7):
        return 0
    
    setup_build_environment()
    
    providers_script = find_providers_script()
    if providers_script:
        result = subprocess.run(["bash", str(providers_script)], check=False)
        if result.returncode != 0:
            return 1
    else:
        # Fallback: install droidrun core only
        if not python_pkg_installed("droidrun", "droidrun"):
            wheels_dir = Path(os.environ.get("WHEELS_DIR", str(HOME / "wheels")))
            result = subprocess.run(
                [sys.executable, "-m", "pip", "install", "droidrun", "--find-links", str(wheels_dir)],
                check=False
            )
            if result.returncode != 0:
                return 1
    
    mark_phase_complete(7)
    return 0


if __name__ == "__main__":
    import os
    sys.exit(main())
