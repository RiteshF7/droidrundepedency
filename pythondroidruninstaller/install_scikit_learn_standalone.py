#!/usr/bin/env python3
"""Standalone script to install scikit-learn with proper error handling"""

import sys
import os
import subprocess
import shutil
from pathlib import Path

current_dir = Path(__file__).parent.absolute()
sys.path.insert(0, str(current_dir))

try:
    from .common import (
        setup_build_environment, python_pkg_installed, HOME, PREFIX,
        get_build_env_with_compilers, get_clean_env,
        log_info, log_success, log_error, log_warning, IS_TERMUX
    )
except ImportError:
    from common import (
        setup_build_environment, python_pkg_installed, HOME, PREFIX,
        get_build_env_with_compilers, get_clean_env,
        log_info, log_success, log_error, log_warning, IS_TERMUX
    )


def ensure_gfortran_symlink() -> bool:
    """Ensure gfortran symlink exists (required for scipy)."""
    gfortran_path = Path(f"{PREFIX}/bin/gfortran")
    flang_path = Path(f"{PREFIX}/bin/flang")
    
    if gfortran_path.exists():
        log_info("gfortran symlink already exists")
        return True
    
    if not flang_path.exists():
        log_error("flang not found. Please install it: pkg install -y flang")
        return False
    
    try:
        # Create symlink
        gfortran_path.symlink_to(flang_path)
        log_success("Created gfortran symlink")
        return True
    except Exception as e:
        log_error(f"Failed to create gfortran symlink: {e}")
        return False


def install_scipy() -> bool:
    """Install scipy if not already installed."""
    if python_pkg_installed("scipy", "scipy>=1.8.0,<1.17.0"):
        log_success("scipy is already installed")
        return True
    
    log_info("Installing scipy (required for scikit-learn)...")
    
    # Ensure gfortran symlink exists
    if not ensure_gfortran_symlink():
        return False
    
    # Set up build environment
    setup_build_environment()
    
    # Install scipy with Fortran compiler
    build_env = get_build_env_with_compilers()
    # Add Fortran compiler to environment
    build_env["FC"] = f"{PREFIX}/bin/flang"
    build_env["F77"] = f"{PREFIX}/bin/flang"
    build_env["F90"] = f"{PREFIX}/bin/flang"
    
    result = subprocess.run(
        [sys.executable, "-m", "pip", "install", "--no-cache-dir", "scipy>=1.8.0,<1.17.0"],
        env=build_env,
        check=False
    )
    
    if result.returncode != 0:
        log_error(f"scipy installation failed with exit code {result.returncode}")
        return False
    
    if not python_pkg_installed("scipy", "scipy>=1.8.0,<1.17.0"):
        log_error("scipy installation succeeded but package not found")
        return False
    
    log_success("scipy installed successfully")
    return True


def install_scikit_learn() -> bool:
    """Install scikit-learn with proper fixes."""
    if python_pkg_installed("scikit-learn", "scikit-learn"):
        log_success("scikit-learn is already installed")
        return True
    
    # Check prerequisites
    if not python_pkg_installed("numpy"):
        log_error("numpy must be installed first")
        return False
    
    if not python_pkg_installed("scipy", "scipy>=1.8.0"):
        log_error("scipy must be installed first")
        return False
    
    log_info("Installing scikit-learn...")
    
    # Set up build environment
    setup_build_environment()
    
    # Install dependencies first (pure Python, no CC/CXX needed)
    clean_env = get_clean_env()
    for dep in ["joblib>=1.3.0", "threadpoolctl>=3.2.0"]:
        if not python_pkg_installed(dep.split(">=")[0].split("==")[0]):
            log_info(f"Installing {dep}...")
            result = subprocess.run(
                [sys.executable, "-m", "pip", "install", "--no-cache-dir", dep],
                env=clean_env,
                check=False
            )
            if result.returncode != 0:
                log_warning(f"Failed to install {dep}, but continuing...")
    
    # Try installing scikit-learn with --no-build-isolation to avoid building scipy
    build_env = get_build_env_with_compilers()
    
    # Method 1: Try direct pip install with --no-build-isolation
    log_info("Attempting direct pip install with --no-build-isolation...")
    result = subprocess.run(
        [
            sys.executable, "-m", "pip", "install", "--no-cache-dir",
            "--no-build-isolation", "scikit-learn"
        ],
        env=build_env,
        check=False
    )
    
    if result.returncode == 0:
        if python_pkg_installed("scikit-learn", "scikit-learn"):
            log_success("scikit-learn installed successfully")
            return True
    
    # Method 2: Build from source with fixes (using build_scikit_learn.sh approach)
    log_info("Direct install failed, trying build from source with fixes...")
    
    wheels_dir = HOME / "wheels"
    wheels_dir.mkdir(exist_ok=True)
    
    # Download source
    log_info("Downloading scikit-learn source...")
    result = subprocess.run(
        [
            sys.executable, "-m", "pip", "download", "scikit-learn",
            "--dest", str(wheels_dir), "--no-cache-dir", "--no-binary", ":all:"
        ],
        env=clean_env,
        check=False
    )
    
    if result.returncode != 0:
        log_error("Failed to download scikit-learn source")
        return False
    
    # Find downloaded tarball
    source_files = list(wheels_dir.glob("scikit-learn-*.tar.gz"))
    if not source_files:
        log_error("Downloaded source file not found")
        return False
    
    source_file = source_files[0]
    log_info(f"Found source: {source_file.name}")
    
    # Extract and fix
    import tempfile
    with tempfile.TemporaryDirectory() as tmpdir:
        extract_dir = Path(tmpdir)
        
        # Extract
        log_info("Extracting source...")
        result = subprocess.run(
            ["tar", "-xzf", str(source_file), "-C", str(extract_dir)],
            check=False
        )
        if result.returncode != 0:
            log_error("Failed to extract source")
            return False
        
        # Find package directory
        pkg_dirs = list(extract_dir.glob("scikit-learn-*"))
        if not pkg_dirs:
            log_error("Extracted package directory not found")
            return False
        
        pkg_dir = pkg_dirs[0]
        pkg_version = pkg_dir.name.replace("scikit-learn-", "")
        log_info(f"Package version: {pkg_version}")
        
        # Fix version.py (add shebang if missing)
        version_py = pkg_dir / "sklearn" / "_build_utils" / "version.py"
        if version_py.exists():
            content = version_py.read_text()
            if not content.startswith("#!/usr/bin/env python3"):
                log_info("Fixing version.py: adding shebang...")
                version_py.write_text("#!/usr/bin/env python3\n" + content)
        
        # Fix meson.build
        meson_build = pkg_dir / "meson.build"
        if meson_build.exists():
            content = meson_build.read_text()
            # Replace version detection with hardcoded version
            import re
            pattern = r"version:\s*run_command\([^)]+\)\.stdout\(\)\.strip\(\)"
            replacement = f"version: '{pkg_version}'"
            if re.search(pattern, content):
                log_info("Fixing meson.build: replacing version detection...")
                content = re.sub(pattern, replacement, content)
                meson_build.write_text(content)
        
        # Repackage
        log_info("Repackaging fixed source...")
        fixed_source = wheels_dir / f"scikit-learn-{pkg_version}-fixed.tar.gz"
        result = subprocess.run(
            [
                "tar", "-czf", str(fixed_source),
                "-C", str(extract_dir), pkg_dir.name
            ],
            check=False
        )
        if result.returncode != 0:
            log_error("Failed to repackage source")
            return False
        
        # Build wheel
        log_info("Building wheel from fixed source...")
        result = subprocess.run(
            [
                sys.executable, "-m", "pip", "wheel",
                "--no-deps", "--no-build-isolation",
                "--wheel-dir", str(wheels_dir),
                str(fixed_source)
            ],
            env=build_env,
            check=False
        )
        
        if result.returncode != 0:
            log_error("Failed to build wheel")
            return False
        
        # Install wheel
        wheel_files = list(wheels_dir.glob("scikit_learn-*.whl"))
        if not wheel_files:
            log_error("Built wheel not found")
            return False
        
        log_info("Installing wheel...")
        result = subprocess.run(
            [
                sys.executable, "-m", "pip", "install",
                "--find-links", str(wheels_dir), "--no-index",
                str(wheel_files[0])
            ],
            check=False
        )
        
        if result.returncode != 0:
            log_error("Failed to install wheel")
            return False
    
    # Verify installation
    if python_pkg_installed("scikit-learn", "scikit-learn"):
        log_success("scikit-learn installed successfully")
        return True
    else:
        log_error("scikit-learn installation succeeded but package not found")
        return False


def main() -> int:
    """Main installation function."""
    log_info("=" * 50)
    log_info("Scikit-learn Installation Script")
    log_info("=" * 50)
    
    # Step 1: Ensure gfortran symlink exists
    if not ensure_gfortran_symlink():
        log_error("Cannot proceed without gfortran symlink")
        return 1
    
    # Step 2: Install scipy if needed
    if not install_scipy():
        log_error("Failed to install scipy (required for scikit-learn)")
        return 1
    
    # Step 3: Install scikit-learn
    if not install_scikit_learn():
        log_error("Failed to install scikit-learn")
        return 1
    
    # Final verification
    try:
        import sklearn
        log_success(f"scikit-learn {sklearn.__version__} verified and working")
    except ImportError as e:
        log_error(f"scikit-learn verification failed: {e}")
        return 1
    
    log_success("=" * 50)
    log_success("Scikit-learn installation completed successfully!")
    log_success("=" * 50)
    return 0


if __name__ == "__main__":
    sys.exit(main())

