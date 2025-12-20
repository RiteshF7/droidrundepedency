#!/usr/bin/env python3
"""Phase 1: Build Tools Installation
Installs wheel, setuptools, Cython, meson-python, maturin
"""

import sys
import os
from pathlib import Path
from typing import Optional

# Add current directory to path for imports (works when running from within the package)
current_dir = Path(__file__).parent.absolute()
if str(current_dir) not in sys.path:
    sys.path.insert(0, str(current_dir))
# Also add parent directory (works when running as module)
parent_dir = current_dir.parent
if str(parent_dir) not in sys.path:
    sys.path.insert(0, str(parent_dir))

# Try relative import first, then absolute
try:
    from .common import (
        log_info, log_success, log_warning, log_error,
        command_exists, pkg_installed, python_pkg_installed,
        should_skip_phase, mark_phase_complete, save_env_vars,
        load_env_vars, setup_build_environment, init_logging,
        run_command, IS_TERMUX, HOME
    )
except ImportError:
    # Fallback to direct import when running as script
    from common import (
        log_info, log_success, log_warning, log_error,
        command_exists, pkg_installed, python_pkg_installed,
        should_skip_phase, mark_phase_complete, save_env_vars,
        load_env_vars, setup_build_environment, init_logging,
        run_command, IS_TERMUX, HOME
    )

# Get script directory (parent of this file)
SCRIPT_DIR = Path(__file__).parent.absolute()


def install_system_package(pkg_name: str) -> bool:
    """Install a system package using pkg (Termux)."""
    if not IS_TERMUX:
        log_warning(f"{pkg_name} check skipped (non-Termux environment)")
        return False
    
    if not command_exists("pkg"):
        log_error("pkg command not found - cannot install packages")
        return False
    
    try:
        log_info(f"Installing {pkg_name} using pkg...")
        run_command(["pkg", "install", "-y", pkg_name], quiet=False)
        log_success(f"{pkg_name} installed")
        return True
    except Exception as e:
        log_error(f"Failed to install {pkg_name}: {e}")
        return False


def install_python_package(pkg_spec: str, quiet: bool = True) -> bool:
    """Install a Python package using pip."""
    try:
        cmd = [sys.executable, "-m", "pip", "install"]
        if quiet:
            cmd.append("--quiet")
        cmd.append(pkg_spec)
        
        result = run_command(cmd, check=False, capture_output=True, quiet=quiet)
        return result.returncode == 0
    except Exception as e:
        log_error(f"Failed to install {pkg_spec}: {e}")
        return False


def find_prebuilt_wheel(wheel_name: str) -> Optional[Path]:
    """Find a pre-built wheel in dependencies directories."""
    # SCRIPT_DIR here is the phase1 script directory, go up to project root
    project_root = SCRIPT_DIR.parent.parent
    dependencies_dirs = [
        project_root / "depedencies" / "wheels",
        HOME / "droidrundepedency" / "depedencies" / "wheels",
        HOME / "depedencies" / "wheels",
    ]
    
    for deps_dir in dependencies_dirs:
        if not deps_dir.exists():
            continue
        
        # Check architecture-specific directories
        arch_dirs = [
            deps_dir / "_x86_64_wheels",
            deps_dir / "arch64_wheels",
        ]
        
        for arch_dir in arch_dirs:
            if arch_dir.exists():
                wheel_file = next(arch_dir.glob(f"{wheel_name}*.whl"), None)
                if wheel_file and wheel_file.exists():
                    return wheel_file
    
    return None


def install_maturin() -> bool:
    """Install maturin (optional tool, required for Phase 4)."""
    log_info("Attempting to install maturin (optional for Phase 1, required for Phase 4: jiter)...")
    
    # Check for pre-built wheel
    maturin_wheel = find_prebuilt_wheel("maturin")
    
    if maturin_wheel:
        log_info(f"Found pre-built maturin wheel: {maturin_wheel.name}")
        
        # Copy to wheels directory
        wheels_dir = Path(os.environ.get("WHEELS_DIR", str(HOME / "wheels")))
        try:
            import shutil
            shutil.copy2(maturin_wheel, wheels_dir / maturin_wheel.name)
        except Exception as e:
            log_warning(f"Failed to copy wheel: {e}")
        
        # Try installing from wheel
        try:
            wheels_dir_str = str(wheels_dir)
            result = run_command(
                [sys.executable, "-m", "pip", "install", 
                 "--find-links", wheels_dir_str, "--no-index", str(maturin_wheel)],
                check=False,
                capture_output=True
            )
            
            if result.returncode == 0:
                if python_pkg_installed("maturin", "maturin<2,>=1.9.4"):
                    log_success("maturin installed from pre-built wheel")
                    return True
        except Exception:
            pass
    
    # Try PyPI
    log_info("No pre-built maturin wheel found, installing from PyPI...")
    if install_python_package("maturin<2,>=1.9.4", quiet=False):
        if python_pkg_installed("maturin", "maturin<2,>=1.9.4"):
            log_success("maturin installed from PyPI")
            return True
        else:
            log_warning("maturin installation from PyPI completed but verification failed")
    else:
        log_warning("maturin installation from PyPI failed (optional for Phase 1, required for Phase 4: jiter)")
        log_warning("Note: This may cause jiter build to fail in Phase 4 if no pre-built wheel is available")
    
    return False


def main() -> int:
    """Main function for Phase 1."""
    log_info("=" * 42)
    log_info("Phase 1: Build Tools Installation")
    log_info("=" * 42)
    
    # Initialize logging
    init_logging()
    
    # Check if phase should be skipped
    if should_skip_phase(1):
        log_success("Phase 1 already completed (skipping)")
        log_info("To force rerun, set FORCE_RERUN=1 environment variable")
        return 0
    
    # Load environment if available
    load_env_vars()
    
    # Setup build environment
    setup_build_environment()
    
    # Check and install python-pip
    if not pkg_installed("python-pip"):
        if IS_TERMUX:
            install_system_package("python-pip")
        else:
            log_warning("python-pip check skipped (non-Termux environment)")
            log_info("Ensure pip is available: python3 -m ensurepip --upgrade")
    else:
        log_success("python-pip is already installed")
    
    # Check and install Rust (required for maturin)
    if not pkg_installed("rust"):
        if IS_TERMUX:
            install_system_package("rust")
        else:
            log_warning("Rust check skipped (non-Termux environment)")
            log_info("Ensure Rust is available for maturin installation")
    else:
        log_success("Rust is already installed")
    
    # Define essential and optional tools
    essential_tools = [
        ("wheel", "wheel"),
        ("setuptools", "setuptools"),
        ("Cython", "Cython"),
        ("meson-python", "meson-python<0.19.0,>=0.16.0"),
    ]
    
    # Check if essential tools are needed
    essential_tools_needed = any(
        not python_pkg_installed(name, spec)
        for name, spec in essential_tools
    )
    
    # Install essential build tools
    if essential_tools_needed:
        log_info("Installing essential build tools...")
        
        # Install wheel and setuptools together
        if (not python_pkg_installed("wheel", "wheel") or 
            not python_pkg_installed("setuptools", "setuptools")):
            log_info("Installing wheel and setuptools...")
            if not install_python_package("wheel setuptools --upgrade"):
                log_error("Failed to install wheel and setuptools")
                return 1
            log_success("wheel and setuptools installed")
        
        # Install Cython
        if not python_pkg_installed("Cython", "Cython"):
            log_info("Installing Cython...")
            if not install_python_package("Cython"):
                log_error("Failed to install Cython")
                return 1
            log_success("Cython installed")
        
        # Install meson-python
        if not python_pkg_installed("meson-python", "meson-python<0.19.0,>=0.16.0"):
            log_info("Installing meson-python...")
            if not install_python_package("meson-python<0.19.0,>=0.16.0"):
                log_error("Failed to install meson-python")
                return 1
            log_success("meson-python installed")
        
        log_success("All essential build tools installed")
    else:
        log_success("All essential build tools are already installed")
    
    # Install optional tools (maturin)
    log_info("Checking optional build tools...")
    if not python_pkg_installed("maturin", "maturin<2,>=1.9.4"):
        install_maturin()
    else:
        log_success("maturin is already installed")
    
    # Verify required build tools are actually installed
    required_tools = ["wheel", "setuptools", "Cython", "meson-python"]
    missing_required = [
        tool for tool in required_tools
        if not python_pkg_installed(tool, tool)
    ]
    
    if missing_required:
        log_error("=" * 78)
        log_error(f"Phase 1 FAILED: Required build tools are not installed: {', '.join(missing_required)}")
        log_error("Phase will not be marked as complete")
        log_error("Please fix the installation errors and rerun Phase 1")
        log_error("=" * 78)
        return 1
    
    log_success("Phase 1 complete: All required build tools installed")
    mark_phase_complete(1)
    save_env_vars()
    
    log_success("Phase 1 completed successfully")
    return 0


if __name__ == "__main__":
    sys.exit(main())

