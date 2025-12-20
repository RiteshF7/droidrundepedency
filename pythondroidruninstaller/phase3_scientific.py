#!/usr/bin/env python3
"""Phase 3: Install scipy, pandas, scikit-learn"""

import sys
import subprocess
from pathlib import Path

current_dir = Path(__file__).parent.absolute()
sys.path.insert(0, str(current_dir))

try:
    from .common import should_skip_phase, mark_phase_complete, setup_build_environment, python_pkg_installed, HOME
    from .build_utils import build_package
except ImportError:
    from common import should_skip_phase, mark_phase_complete, setup_build_environment, python_pkg_installed, HOME
    from build_utils import build_package


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
    
    # scipy
    if not build_package("scipy", "scipy>=1.8.0,<1.17.0"):
        return 1
    
    # pandas
    if not python_pkg_installed("pandas", "pandas<2.3.0"):
        # Install deps
        for dep in ["python-dateutil>=2.8.2", "pytz>=2020.1", "tzdata>=2022.7"]:
            subprocess.run([sys.executable, "-m", "pip", "install", dep], capture_output=True)
        
        # Try build script, fallback to build_package
        build_script = find_script("build_pandas.sh")
        if build_script:
            result = subprocess.run(["bash", str(build_script)], check=False)
            if result.returncode != 0:
                if not build_package("pandas", "pandas<2.3.0", fix_source="pandas"):
                    return 1
        else:
            if not build_package("pandas", "pandas<2.3.0", fix_source="pandas"):
                return 1
    
    # scikit-learn
    if not python_pkg_installed("scikit-learn", "scikit-learn"):
        # Install deps
        for dep in ["joblib>=1.3.0", "threadpoolctl>=3.2.0"]:
            subprocess.run([sys.executable, "-m", "pip", "install", dep], capture_output=True)
        
        # Try build script, fallback to build_package
        build_script = find_script("build_scikit_learn.sh")
        if build_script:
            result = subprocess.run(["bash", str(build_script)], check=False)
            if result.returncode != 0:
                build_package("scikit-learn", "scikit-learn", fix_source="scikit-learn", 
                            no_build_isolation=True, wheel_pattern="scikit_learn*.whl")
        else:
            build_package("scikit-learn", "scikit-learn", fix_source="scikit-learn",
                        no_build_isolation=True, wheel_pattern="scikit_learn*.whl")
    
    mark_phase_complete(3)
    return 0


if __name__ == "__main__":
    sys.exit(main())
