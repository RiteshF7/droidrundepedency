#!/usr/bin/env python3
"""Phase 4: Install jiter"""

import sys
import os
import shutil
from pathlib import Path

current_dir = Path(__file__).parent.absolute()
sys.path.insert(0, str(current_dir))

try:
    from .common import should_skip_phase, mark_phase_complete, setup_build_environment, python_pkg_installed, HOME, get_clean_env, log_info, log_success, log_error, log_warning
except ImportError:
    from common import should_skip_phase, mark_phase_complete, setup_build_environment, python_pkg_installed, HOME, get_clean_env, log_info, log_success, log_error, log_warning


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
        # Verify jiter can be imported
        try:
            import jiter
            log_success("jiter is already installed and verified")
            mark_phase_complete(4)
            return 0
        except ImportError:
            log_warning("jiter marked as installed but import failed, reinstalling...")
            # Unmark phase as complete if import fails
            try:
                from .common import PROGRESS_FILE
            except ImportError:
                from common import PROGRESS_FILE
            if PROGRESS_FILE.exists():
                content = PROGRESS_FILE.read_text()
                content = content.replace("PHASE_4_COMPLETE\n", "")
                PROGRESS_FILE.write_text(content)
    
    # Try pre-built wheel
    jiter_wheel = find_wheel("jiter")
    if jiter_wheel:
        wheels_dir = Path(os.environ.get("WHEELS_DIR", str(HOME / "wheels")))
        shutil.copy2(jiter_wheel, wheels_dir / jiter_wheel.name)
        result = subprocess.run(
            [sys.executable, "-m", "pip", "install", "--find-links", str(wheels_dir), 
             "--no-index", str(jiter_wheel)],
            check=False
        )
        if result.returncode == 0 and python_pkg_installed("jiter", "jiter==0.12.0"):
            try:
                import jiter
                log_success("jiter installed from wheel and verified")
                mark_phase_complete(4)
                return 0
            except ImportError:
                log_warning("jiter wheel installed but import failed, trying source build...")
    
    # Build from source - jiter is Rust-based, doesn't need CC/CXX
    if not python_pkg_installed("maturin", "maturin"):
        log_error("maturin is required but not installed")
        return 1
    
    log_info("Installing jiter from source...")
    clean_env = get_clean_env()
    result = subprocess.run(
        [sys.executable, "-m", "pip", "install", "--no-cache-dir", "jiter==0.12.0"],
        env=clean_env,
        check=False
    )
    
    if result.returncode != 0:
        log_error(f"jiter installation failed with exit code {result.returncode}")
        log_error("Check the output above for detailed error messages")
        return 1
    
    if not python_pkg_installed("jiter", "jiter==0.12.0"):
        log_error("jiter installation succeeded but package not found")
        return 1
    
    # Verify jiter can be imported
    try:
        import jiter
        log_success("jiter installed and verified successfully")
        mark_phase_complete(4)
        return 0
    except ImportError as e:
        log_error(f"jiter installed but import failed: {e}")
        return 1


if __name__ == "__main__":
    import subprocess
    sys.exit(main())
