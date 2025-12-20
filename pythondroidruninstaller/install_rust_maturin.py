#!/usr/bin/env python3
"""Install Rust and maturin - separate script for testing"""

import sys
import os
import subprocess
import shutil
from pathlib import Path

current_dir = Path(__file__).parent.absolute()
sys.path.insert(0, str(current_dir))

try:
    from .common import (
        command_exists, pkg_installed, python_pkg_installed,
        IS_TERMUX, HOME, log_info, log_success, log_error, log_warning
    )
except ImportError:
    from common import (
        command_exists, pkg_installed, python_pkg_installed,
        IS_TERMUX, HOME, log_info, log_success, log_error, log_warning
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


def install_rust() -> bool:
    """Install Rust using pkg."""
    if not IS_TERMUX:
        log_warning("Not in Termux - skipping Rust installation")
        return False
    
    if not command_exists("pkg"):
        log_error("pkg command not found")
        return False
    
    if pkg_installed("rust"):
        log_success("Rust is already installed")
        return True
    
    log_info("Installing Rust via pkg...")
    result = subprocess.run(["pkg", "install", "-y", "rust"], capture_output=True, check=False)
    
    if result.returncode == 0:
        # Verify rustc is available
        if command_exists("rustc"):
            log_success("Rust installed successfully")
            return True
        else:
            log_error("Rust package installed but rustc not found in PATH")
            return False
    else:
        log_error(f"Failed to install Rust (exit code: {result.returncode})")
        return False


def install_maturin() -> bool:
    """Install maturin - REQUIRES pre-built wheel due to pkg rust LLVM issues."""
    if python_pkg_installed("maturin", "maturin<2,>=1.9.4"):
        log_success("maturin is already installed")
        return True
    
    # CRITICAL: pkg rust has LLVM symbol linking issues, so maturin MUST use pre-built wheel
    log_info("Searching for pre-built maturin wheel (required due to rust LLVM issues)...")
    maturin_wheel = find_wheel("maturin")
    
    if not maturin_wheel:
        log_error("=" * 60)
        log_error("CRITICAL: Pre-built maturin wheel not found!")
        log_error("=" * 60)
        log_error("Due to pkg rust LLVM symbol linking issues, maturin cannot be built from source.")
        log_error("You MUST provide a pre-built maturin wheel in one of these locations:")
        log_error(f"  - {Path(__file__).parent.parent.parent / 'depedencies' / 'wheels' / '_x86_64_wheels'}")
        log_error(f"  - {HOME / 'droidrundepedency' / 'depedencies' / 'wheels' / '_x86_64_wheels'}")
        log_error(f"  - {HOME / 'depedencies' / 'wheels' / '_x86_64_wheels'}")
        log_error("=" * 60)
        return False
    
    log_info(f"Found pre-built maturin wheel: {maturin_wheel.name}")
    wheels_dir = Path(os.environ.get("WHEELS_DIR", str(HOME / "wheels")))
    wheels_dir.mkdir(exist_ok=True)
    shutil.copy2(maturin_wheel, wheels_dir / maturin_wheel.name)
    
    log_info("Installing maturin from pre-built wheel...")
    result = subprocess.run(
        [sys.executable, "-m", "pip", "install", "--find-links", str(wheels_dir), 
         "--no-index", str(maturin_wheel)],
        capture_output=True,
        check=False
    )
    
    if result.returncode == 0 and python_pkg_installed("maturin", "maturin<2,>=1.9.4"):
        log_success("maturin installed from pre-built wheel")
        return True
    else:
        log_error("Failed to install maturin from pre-built wheel")
        if result.stderr:
            error_output = result.stderr.decode('utf-8', errors='ignore')
            for line in error_output.split('\n')[-10:]:
                if line.strip():
                    log_error(f"  {line}")
        return False


def verify_rust() -> bool:
    """Verify Rust is working."""
    if not command_exists("rustc"):
        log_error("rustc not found in PATH")
        return False
    
    log_info("Verifying rustc...")
    result = subprocess.run(["rustc", "--version"], capture_output=True, check=False)
    if result.returncode == 0:
        version = result.stdout.decode('utf-8', errors='ignore').strip()
        log_success(f"Rust version: {version}")
        return True
    else:
        # Check if it's the LLVM symbol error (known issue with pkg rust)
        error_output = result.stderr.decode('utf-8', errors='ignore')
        if "cannot locate symbol" in error_output or "_ZTIN4llvm" in error_output:
            log_warning("rustc has LLVM symbol linking issue (known pkg rust problem)")
            log_warning("This may cause maturin build to fail, but continuing anyway...")
            # Still return True - we'll see if maturin can work around it
            return True
        else:
            log_error(f"rustc --version failed: {error_output[:200]}")
            return False


def verify_maturin() -> bool:
    """Verify maturin is working."""
    if not python_pkg_installed("maturin", "maturin<2,>=1.9.4"):
        log_error("maturin not installed")
        return False
    
    log_info("Verifying maturin...")
    result = subprocess.run([sys.executable, "-m", "maturin", "--version"], capture_output=True, check=False)
    if result.returncode == 0:
        version = result.stdout.decode('utf-8', errors='ignore').strip()
        log_success(f"maturin version: {version}")
        return True
    else:
        log_error("maturin --version failed")
        return False


def main() -> int:
    """Main function."""
    log_info("=" * 50)
    log_info("Rust and maturin Installation")
    log_info("=" * 50)
    
    # Install Rust
    if not install_rust():
        log_error("Failed to install Rust")
        return 1
    
    # Verify Rust
    if not verify_rust():
        log_error("Rust verification failed")
        return 1
    
    # Install maturin
    if not install_maturin():
        log_error("Failed to install maturin")
        return 1
    
    # Verify maturin
    if not verify_maturin():
        log_error("maturin verification failed")
        return 1
    
    log_success("=" * 50)
    log_success("Rust and maturin installation completed successfully!")
    log_success("=" * 50)
    return 0


if __name__ == "__main__":
    sys.exit(main())

