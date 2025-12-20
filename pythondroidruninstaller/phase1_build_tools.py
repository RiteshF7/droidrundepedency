#!/usr/bin/env python3
"""Phase 1: Install build tools"""

import sys
import os
import shutil
from pathlib import Path

current_dir = Path(__file__).parent.absolute()
sys.path.insert(0, str(current_dir))

try:
    from .common import (
        should_skip_phase, mark_phase_complete, setup_build_environment,
        python_pkg_installed, pkg_installed, command_exists, IS_TERMUX, HOME
    )
except ImportError:
    from common import (
        should_skip_phase, mark_phase_complete, setup_build_environment,
        python_pkg_installed, pkg_installed, command_exists, IS_TERMUX, HOME
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
    
    # Install Rust via rustup instead of pkg (more reliable for maturin)
    # Check if rustup is installed, if not install it
    if not command_exists("rustup"):
        # Download and install rustup to home directory (more reliable than /tmp)
        rustup_script = Path.home() / "rustup-init.sh"
        result = subprocess.run(
            ["curl", "--proto", "=https", "--tlsv1.2", "-sSf", "https://sh.rustup.rs", "-o", str(rustup_script)],
            capture_output=True,
            check=False
        )
        if result.returncode == 0 and rustup_script.exists():
            subprocess.run(["sh", str(rustup_script), "-y", "--default-toolchain", "stable"], check=False)
            rustup_script.unlink(missing_ok=True)
    
    # Ensure rustup default toolchain is set (needed for rustc to work)
    cargo_bin = Path.home() / ".cargo" / "bin"
    if cargo_bin.exists() and (cargo_bin / "rustup").exists():
        os.environ["PATH"] = f"{cargo_bin}:{os.environ.get('PATH', '')}"
        # Set default toolchain if rustup exists
        subprocess.run([str(cargo_bin / "rustup"), "default", "stable"], capture_output=True, check=False)
    
    # Add rustup cargo to PATH (takes precedence over pkg rust)
    cargo_bin = Path.home() / ".cargo" / "bin"
    if cargo_bin.exists():
        os.environ["PATH"] = f"{cargo_bin}:{os.environ.get('PATH', '')}"
        # Also source the env file if it exists
        cargo_env = Path.home() / ".cargo" / "env"
        if cargo_env.exists():
            # Read and apply environment variables from cargo env
            try:
                with open(cargo_env, 'r') as f:
                    for line in f:
                        if line.startswith('export PATH='):
                            # Extract PATH value
                            path_val = line.split('export PATH=')[1].strip().strip('"').strip("'")
                            os.environ["PATH"] = f"{path_val}:{os.environ.get('PATH', '')}"
            except Exception:
                pass
    
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
    
    # maturin (optional) - ensure rustup PATH is set before installing
    cargo_bin = Path.home() / ".cargo" / "bin"
    if cargo_bin.exists():
        os.environ["PATH"] = f"{cargo_bin}:{os.environ.get('PATH', '')}"
        # Ensure default toolchain is set
        if (cargo_bin / "rustup").exists():
            subprocess.run([str(cargo_bin / "rustup"), "default", "stable"], capture_output=True, check=False)
    
    if not python_pkg_installed("maturin", "maturin<2,>=1.9.4"):
        maturin_wheel = find_wheel("maturin")
        if maturin_wheel:
            wheels_dir = Path(os.environ.get("WHEELS_DIR", str(HOME / "wheels")))
            shutil.copy2(maturin_wheel, wheels_dir / maturin_wheel.name)
            subprocess.run(
                [sys.executable, "-m", "pip", "install", "--find-links", str(wheels_dir), 
                 "--no-index", str(maturin_wheel)],
                check=False,
                env=os.environ.copy()
            )
        else:
            subprocess.run(
                [sys.executable, "-m", "pip", "install", "maturin<2,>=1.9.4"],
                check=False,
                env=os.environ.copy()
            )
    
    # Verify required tools
    for name, spec in essential:
        if not python_pkg_installed(name, spec):
            return 1
    
    mark_phase_complete(1)
    return 0


if __name__ == "__main__":
    import subprocess
    sys.exit(main())
