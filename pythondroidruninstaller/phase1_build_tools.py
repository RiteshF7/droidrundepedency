#!/usr/bin/env python3
"""Phase 1: Install build tools"""

import sys
import os
import subprocess
import shutil
from pathlib import Path

current_dir = Path(__file__).parent.absolute()
sys.path.insert(0, str(current_dir))

try:
    from .common import (
        should_skip_phase, mark_phase_complete, setup_build_environment,
        python_pkg_installed, pkg_installed, command_exists, IS_TERMUX, HOME,
        log_info, log_error, log_success, log_warning
    )
except ImportError:
    from common import (
        should_skip_phase, mark_phase_complete, setup_build_environment,
        python_pkg_installed, pkg_installed, command_exists, IS_TERMUX, HOME,
        log_info, log_error, log_success, log_warning
    )


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
    if should_skip_phase(1):
        return 0
    
    setup_build_environment()
    
    # Install system packages if needed
    if IS_TERMUX and command_exists("pkg"):
        if not pkg_installed("python-pip"):
            subprocess.run(["pkg", "install", "-y", "python-pip"], check=False)
    
    # Install Rust and maturin first (required for Phase 4)
    log_info("Installing Rust and maturin...")
    rust_maturin_script = Path(__file__).parent / "install_rust_maturin.py"
    if rust_maturin_script.exists():
        result = subprocess.run([sys.executable, str(rust_maturin_script)], check=False)
        if result.returncode != 0:
            log_error("Failed to install Rust and maturin")
            return 1
    else:
        log_error(f"install_rust_maturin.py not found at {rust_maturin_script}")
        return 1
    
    # Essential tools
    essential = [
        ("wheel", "wheel"),
        ("setuptools", "setuptools"),
        ("Cython", "Cython"),
        ("meson-python", "meson-python<0.19.0,>=0.16.0"),
    ]
    
    for name, spec in essential:
        if not python_pkg_installed(name, spec):
            subprocess.run([sys.executable, "-m", "pip", "install", spec], capture_output=True, check=False)
    
    # maturin (optional - needed for Phase 4 jiter, but not critical for Phase 1)
    # Try pre-built wheel first, then pip install (may fail if rust has issues, that's OK)
    if not python_pkg_installed("maturin", "maturin<2,>=1.9.4"):
        maturin_wheel = find_wheel("maturin")
        if maturin_wheel:
            wheels_dir = Path(os.environ.get("WHEELS_DIR", str(HOME / "wheels")))
            shutil.copy2(maturin_wheel, wheels_dir / maturin_wheel.name)
            subprocess.run(
                [sys.executable, "-m", "pip", "install", "--find-links", str(wheels_dir), 
                 "--no-index", str(maturin_wheel)],
                check=False
            )
        else:
            # Try pip install - may fail if rust has linking issues, that's acceptable
            subprocess.run([sys.executable, "-m", "pip", "install", "maturin<2,>=1.9.4"], check=False)
    
    # Verify required tools are installed and can be imported
    missing = []
    for name, spec in essential:
        if not python_pkg_installed(name, spec):
            missing.append(name)
    
    if missing:
        log_error(f"Phase 1 incomplete: missing packages: {', '.join(missing)}")
        return 1
    
    # Verify packages can be imported (some build tools may not be importable)
    # meson-python is a PEP 517 build backend, not a runtime library - just verify it's installed
    import_errors = []
    for name, spec in essential:
        import_name = name.replace('-', '_')
        # meson-python is a build backend, not importable - just check it's installed (already verified above)
        if name == "meson-python":
            # Already verified it's installed above, skip import check
            log_info(f"{name} is a build backend (PEP 517), installation verified")
        else:
            try:
                __import__(import_name)
            except ImportError as e:
                import_errors.append(f"{name}: {e}")
    
    if import_errors:
        log_error(f"Phase 1 verification failed - import errors: {import_errors}")
        return 1
    
    # Verify maturin is installed (required for Phase 4)
    if not python_pkg_installed("maturin", "maturin<2,>=1.9.4"):
        log_warning("maturin not installed - Phase 4 (jiter) will fail")
        # Don't fail Phase 1, but warn
    
    # Verify Rust is available (required for Phase 4)
    if not command_exists("rustc"):
        log_warning("rustc not found - Phase 4 (jiter) will fail")
        # Don't fail Phase 1, but warn
    
    log_success("All Phase 1 packages verified and working")
    mark_phase_complete(1)
    return 0


if __name__ == "__main__":
    sys.exit(main())
