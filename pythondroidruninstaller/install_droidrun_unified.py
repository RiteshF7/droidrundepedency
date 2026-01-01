#!/usr/bin/env python3
"""Unified droidrun installer that preserves all wheels including transitive dependencies."""

import sys
import os
import subprocess
import shutil
import zipfile
from pathlib import Path
from typing import Optional, Dict, List

current_dir = Path(__file__).parent.absolute()
sys.path.insert(0, str(current_dir))

try:
    from .common import (
        should_skip_phase, mark_phase_complete, setup_build_environment,
        python_pkg_installed, pkg_installed, command_exists, IS_TERMUX, HOME, PREFIX,
        get_build_env_with_compilers, get_clean_env,
        log_info, log_error, log_success, log_warning
    )
except ImportError:
    from common import (
        should_skip_phase, mark_phase_complete, setup_build_environment,
        python_pkg_installed, pkg_installed, command_exists, IS_TERMUX, HOME, PREFIX,
        get_build_env_with_compilers, get_clean_env,
        log_info, log_error, log_success, log_warning
    )


def install_with_wheel_preservation(
    pkg_spec: str,
    wheels_dir: Path,
    build_env: Optional[Dict[str, str]] = None,
    no_build_isolation: bool = False,
    no_deps: bool = False,
    extra_flags: Optional[List[str]] = None
) -> bool:
    """
    Install a package with wheel preservation.
    
    This function:
    1. Runs 'pip wheel' to download/build package + ALL dependencies
    2. Installs from the wheels directory using --find-links --no-index
    
    Args:
        pkg_spec: Package specification (e.g., "numpy>=1.26.0")
        wheels_dir: Directory to store wheels
        build_env: Environment variables for build (if None, uses clean env)
        no_build_isolation: Pass --no-build-isolation to pip wheel
        no_deps: Pass --no-deps to pip wheel (don't download dependencies)
        extra_flags: Additional flags to pass to pip wheel
    
    Returns:
        True if installation succeeded, False otherwise
    """
    wheels_dir.mkdir(parents=True, exist_ok=True)
    
    # Step 1: Build/download all wheels (including dependencies)
    log_info(f"Building/downloading wheels for {pkg_spec} (including dependencies)...")
    wheel_cmd = [sys.executable, "-m", "pip", "wheel", pkg_spec, "--wheel-dir", str(wheels_dir)]
    
    if no_build_isolation:
        wheel_cmd.append("--no-build-isolation")
    
    if no_deps:
        wheel_cmd.append("--no-deps")
    
    if extra_flags:
        wheel_cmd.extend(extra_flags)
    
    env = build_env if build_env is not None else get_clean_env()
    
    result = subprocess.run(wheel_cmd, env=env, check=False)
    if result.returncode != 0:
        log_error(f"Failed to build/download wheels for {pkg_spec}")
        return False
    
    log_success(f"Wheels for {pkg_spec} and dependencies saved to {wheels_dir}")
    
    # Step 2: Install from wheels directory
    log_info(f"Installing {pkg_spec} from wheels directory...")
    install_cmd = [
        sys.executable, "-m", "pip", "install",
        "--find-links", str(wheels_dir),
        "--no-index",
        pkg_spec
    ]
    
    result = subprocess.run(install_cmd, env=env, check=False)
    if result.returncode != 0:
        log_error(f"Failed to install {pkg_spec} from wheels")
        return False
    
    # Verify installation
    pkg_name = pkg_spec.split(">=")[0].split("==")[0].split("<")[0].strip()
    if python_pkg_installed(pkg_name, pkg_spec):
        log_success(f"{pkg_spec} installed successfully")
        return True
    else:
        log_error(f"{pkg_spec} installation succeeded but package not found")
        return False


def fix_grpcio_wheel(wheel_file: Path) -> bool:
    """Fix grpcio wheel by adding abseil library dependencies."""
    extract_dir = wheel_file.parent / "grpcio_extract"
    extract_dir.mkdir(exist_ok=True)
    
    try:
        with zipfile.ZipFile(wheel_file, 'r') as zf:
            zf.extractall(extract_dir)
        
        so_files = list(extract_dir.rglob("cygrpc*.so"))
        if not so_files:
            return False
        
        # Fix with patchelf if available
        if shutil.which("patchelf"):
            so_file = so_files[0]
            for lib in ["libabsl_flags_internal.so", "libabsl_flags.so", 
                       "libabsl_flags_commandlineflag.so", "libabsl_flags_reflection.so"]:
                subprocess.run(["patchelf", "--add-needed", lib, str(so_file)], check=False)
            subprocess.run(["patchelf", "--set-rpath", f"{PREFIX}/lib", str(so_file)], check=False)
        
        # Repackage
        fixed_wheel = wheel_file.parent / "grpcio-fixed.whl"
        with zipfile.ZipFile(fixed_wheel, 'w', zipfile.ZIP_DEFLATED) as zf:
            for root, dirs, files in os.walk(extract_dir):
                for file in files:
                    zf.write(Path(root) / file, Path(root).relative_to(extract_dir) / file)
        
        wheel_file.unlink()
        fixed_wheel.rename(wheel_file)
        shutil.rmtree(extract_dir, ignore_errors=True)
        return True
    except Exception:
        shutil.rmtree(extract_dir, ignore_errors=True)
        return False


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


def run_phase1_build_tools(wheels_dir: Path) -> int:
    """Phase 1: Install build tools and system dependencies."""
    if should_skip_phase(1):
        log_info("Phase 1 is already complete. Set FORCE_RERUN=1 to rerun.")
        return 0
    
    setup_build_environment()
    
    # Install system packages if needed
    if IS_TERMUX and command_exists("pkg"):
        if not pkg_installed("python-pip"):
            subprocess.run(["pkg", "install", "-y", "python-pip"], check=False)
        else:
            log_info("python-pip is already installed")
        
        if not pkg_installed("flang"):
            log_info("Installing flang...")
            result = subprocess.run(["pkg", "install", "-y", "flang"], check=False)
            if result.returncode != 0:
                log_warning("Failed to install flang - scikit-learn build may fail")
            else:
                log_success("flang installed successfully")
        else:
            log_info("flang is already installed")
        
        # Install autotools (required for building patchelf and other packages)
        for pkg_name in ["autoconf", "automake", "libtool"]:
            if not pkg_installed(pkg_name):
                log_info(f"Installing {pkg_name}...")
                result = subprocess.run(["pkg", "install", "-y", pkg_name], check=False)
                if result.returncode != 0:
                    log_warning(f"Failed to install {pkg_name} - some builds may fail")
                else:
                    log_success(f"{pkg_name} installed successfully")
            else:
                log_info(f"{pkg_name} is already installed")
        
        # Install patchelf (required for fixing ELF binaries)
        if not pkg_installed("patchelf"):
            log_info("Installing patchelf...")
            result = subprocess.run(["pkg", "install", "-y", "patchelf"], check=False)
            if result.returncode != 0:
                log_warning("Failed to install patchelf - some wheel fixes may fail")
            else:
                log_success("patchelf installed successfully")
        else:
            log_info("patchelf is already installed")
        
        # Install libraries for pyarrow, Pillow, and grpcio
        for pkg_name in ["libarrow-cpp", "libjpeg-turbo", "libpng", "libtiff", "libwebp", "freetype", "abseil-cpp"]:
            if not pkg_installed(pkg_name):
                log_info(f"Installing {pkg_name}...")
                result = subprocess.run(["pkg", "install", "-y", pkg_name], check=False)
                if result.returncode != 0:
                    log_warning(f"Failed to install {pkg_name} - some builds may fail")
                else:
                    log_success(f"{pkg_name} installed successfully")
            else:
                log_info(f"{pkg_name} is already installed")
        
        # Install Python packages via pkg (more stable for droidrun install)
        python_packages = ["python-pillow", "python-scipy", "python-numpy"]
        for pkg_name in python_packages:
            if not pkg_installed(pkg_name):
                log_info(f"Installing {pkg_name} via pkg (required for droidrun)...")
                result = subprocess.run(["pkg", "install", "-y", pkg_name], check=False)
                if result.returncode != 0:
                    log_warning(f"Failed to install {pkg_name} - some droidrun features may not work")
                else:
                    log_success(f"{pkg_name} installed successfully via pkg")
            else:
                log_info(f"{pkg_name} is already installed")
    
    # Install Rust and maturin first (required for Phase 4)
    log_info("Installing Rust and maturin...")
    
    # Try installing Rust via pkg first (more stable)
    rust_installed = False
    if IS_TERMUX and command_exists("pkg"):
        if not pkg_installed("rust"):
            log_info("Installing rust via pkg (more stable)...")
            result = subprocess.run(["pkg", "install", "-y", "rust"], check=False)
            if result.returncode == 0:
                log_success("rust installed successfully via pkg")
                rust_installed = True
            else:
                log_warning("Failed to install rust via pkg, falling back to install script")
        else:
            log_info("rust is already installed via pkg")
            rust_installed = True
    
    # Fallback to install script if pkg install failed or not in Termux
    if not rust_installed:
        rust_maturin_script = Path(__file__).parent / "install_rust_maturin.py"
        if rust_maturin_script.exists():
            result = subprocess.run([sys.executable, str(rust_maturin_script)], check=False)
            if result.returncode != 0:
                log_error("Failed to install Rust and maturin")
                return 1
        else:
            log_error(f"install_rust_maturin.py not found at {rust_maturin_script}")
            return 1
    
    # Essential tools - install with wheel preservation
    essential = [
        ("wheel", "wheel"),
        ("setuptools", "setuptools"),
        ("Cython", "Cython"),
        ("meson-python", "meson-python<0.19.0,>=0.16.0"),
    ]
    
    clean_env = get_clean_env()
    for name, spec in essential:
        if not python_pkg_installed(name, spec):
            log_info(f"Installing {name} with wheel preservation...")
            if not install_with_wheel_preservation(spec, wheels_dir, build_env=clean_env):
                log_error(f"Failed to install {name}")
                return 1
        else:
            log_info(f"{name} is already installed")
    
    # maturin (optional - needed for Phase 4 jiter, but not critical for Phase 1)
    if not python_pkg_installed("maturin", "maturin<2,>=1.9.4"):
        log_info("Installing maturin with wheel preservation...")
        # Try with wheel preservation, but don't fail if it fails
        install_with_wheel_preservation("maturin<2,>=1.9.4", wheels_dir, build_env=clean_env)
    else:
        log_info("maturin is already installed")
    
    # Verify required tools are installed
    missing = []
    for name, spec in essential:
        if not python_pkg_installed(name, spec):
            missing.append(name)
    
    if missing:
        log_error(f"Phase 1 incomplete: missing packages: {', '.join(missing)}")
        return 1
    
    # Install pillow and grpcio after dependencies are installed
    log_info("Checking pillow and grpcio (after dependencies)...")
    
    # Install pillow (requires libjpeg-turbo, libpng, libtiff, libwebp, freetype)
    if not python_pkg_installed("pillow", "pillow"):
        pillow_installed = False
        
        # Try installing via pkg first (more stable)
        if IS_TERMUX and command_exists("pkg"):
            if not pkg_installed("python-pillow"):
                log_info("Installing python-pillow via pkg (more stable)...")
                result = subprocess.run(["pkg", "install", "-y", "python-pillow"], check=False)
                if result.returncode == 0:
                    if python_pkg_installed("pillow", "pillow"):
                        log_success("python-pillow installed successfully via pkg")
                        pillow_installed = True
                    else:
                        log_warning("python-pillow installed via pkg but not found as Python package, falling back to pip")
                else:
                    log_warning("Failed to install python-pillow via pkg, falling back to pip")
            else:
                log_info("python-pillow is already installed via pkg")
                if python_pkg_installed("pillow", "pillow"):
                    pillow_installed = True
        
        # Fallback to pip install with wheel preservation
        if not pillow_installed:
            log_info("Installing pillow via pip with wheel preservation...")
            build_env = get_build_env_with_compilers()
            build_env.update({
                "PKG_CONFIG_PATH": f"{PREFIX}/lib/pkgconfig",
                "LDFLAGS": f"-L{PREFIX}/lib",
                "CPPFLAGS": f"-I{PREFIX}/include",
            })
            if not install_with_wheel_preservation("pillow", wheels_dir, build_env=build_env):
                log_warning("pillow installation failed (optional, continuing...)")
    else:
        log_info("pillow is already installed")
    
    # Install grpcio (requires abseil-cpp, patchelf, Cython, typing-extensions)
    if not python_pkg_installed("grpcio", "grpcio"):
        grpcio_installed = False
        
        # Try installing via pkg first (more stable)
        if IS_TERMUX and command_exists("pkg"):
            if not pkg_installed("python-grpcio"):
                log_info("Installing python-grpcio via pkg (more stable)...")
                result = subprocess.run(["pkg", "install", "-y", "python-grpcio"], check=False)
                if result.returncode == 0:
                    if python_pkg_installed("grpcio", "grpcio"):
                        log_success("python-grpcio installed successfully via pkg")
                        grpcio_installed = True
                    else:
                        log_warning("python-grpcio installed via pkg but not found as Python package, falling back to pip")
                else:
                    log_warning("Failed to install python-grpcio via pkg, falling back to pip")
            else:
                log_info("python-grpcio is already installed via pkg")
                if python_pkg_installed("grpcio", "grpcio"):
                    grpcio_installed = True
        
        # Fallback to pip/wheel build method with wheel preservation
        if not grpcio_installed:
            log_info("Installing grpcio via pip with wheel preservation...")
            clean_env = get_clean_env()
            clean_env.update({
                "GRPC_PYTHON_BUILD_SYSTEM_OPENSSL": "1",
                "GRPC_PYTHON_BUILD_SYSTEM_ZLIB": "1",
                "GRPC_PYTHON_BUILD_SYSTEM_CARES": "1",
                "GRPC_PYTHON_BUILD_SYSTEM_RE2": "1",
                "GRPC_PYTHON_BUILD_SYSTEM_ABSL": "1",
                "GRPC_PYTHON_BUILD_WITH_CYTHON": "1",
            })
            
            # Build wheel first (with dependencies - no --no-deps to capture all deps)
            wheels_dir.mkdir(parents=True, exist_ok=True)
            log_info("Building/downloading grpcio and dependencies to wheels directory...")
            result = subprocess.run(
                [sys.executable, "-m", "pip", "wheel", "grpcio", "--no-build-isolation", 
                 "--wheel-dir", str(wheels_dir)],
                env=clean_env,
                check=False
            )
            
            if result.returncode == 0:
                grpcio_wheels = list(wheels_dir.glob("grpcio*.whl"))
                if grpcio_wheels:
                    log_info("Fixing grpcio wheel with patchelf...")
                    fix_grpcio_wheel(grpcio_wheels[0])
                    log_success("grpcio and dependency wheels saved to wheels directory")
                    
                    # Install from wheels directory (pip will find dependencies there too)
                    log_info("Installing grpcio from wheels directory...")
                    install_result = subprocess.run(
                        [sys.executable, "-m", "pip", "install", "--find-links", str(wheels_dir),
                         "--no-index", "grpcio"],
                        env=clean_env,
                        check=False
                    )
                    if install_result.returncode == 0 and python_pkg_installed("grpcio", "grpcio"):
                        log_success("grpcio installed successfully from wheels")
                    else:
                        log_warning("grpcio wheel installation had issues (continuing...)")
                else:
                    log_warning("grpcio wheel build succeeded but wheel not found")
            else:
                log_warning("grpcio wheel build failed (continuing...)")
    else:
        log_info("grpcio is already installed")
    
    log_success("All Phase 1 packages verified and working")
    mark_phase_complete(1)
    return 0


def run_phase2_numpy(wheels_dir: Path) -> int:
    """Phase 2: Install numpy."""
    if should_skip_phase(2):
        log_info("Phase 2 is already complete. Set FORCE_RERUN=1 to rerun.")
        # Still verify
        if python_pkg_installed("numpy", "numpy>=1.26.0"):
            try:
                import numpy as np
                arr = np.array([1, 2, 3])
                if len(arr) == 3:
                    return 0
            except Exception:
                pass
        log_warning("Phase 2 marked complete but numpy verification failed")
    
    setup_build_environment()
    
    # Check if numpy is already installed and working
    if python_pkg_installed("numpy", "numpy>=1.26.0"):
        try:
            import numpy as np
            arr = np.array([1, 2, 3])
            if len(arr) == 3:
                log_success("numpy is already installed and verified")
                mark_phase_complete(2)
                return 0
        except Exception:
            pass
    
    # Install patchelf system package (required to avoid building Python patchelf)
    if not pkg_installed("patchelf"):
        log_info("Installing patchelf system package (required for numpy builds)...")
        if IS_TERMUX and command_exists("pkg"):
            result = subprocess.run(["pkg", "install", "-y", "patchelf"], check=False)
            if result.returncode != 0:
                log_warning("Failed to install patchelf system package - numpy build may fail")
            else:
                log_success("patchelf system package installed")
        else:
            log_warning("Cannot install patchelf - pkg command not available")
    
    log_info("Installing numpy with wheel preservation...")
    # numpy needs CC/CXX overrides for C/Fortran extensions
    build_env = get_build_env_with_compilers()
    
    if not install_with_wheel_preservation("numpy>=1.26.0", wheels_dir, build_env=build_env):
        log_error("numpy installation failed")
        return 1
    
    # Verify installation
    try:
        import numpy as np
        arr = np.array([1, 2, 3])
        if len(arr) != 3:
            log_error("numpy verification failed")
            return 1
        log_success("numpy verified and working")
    except Exception as e:
        log_error(f"numpy import/verification failed: {e}")
        return 1
    
    mark_phase_complete(2)
    return 0


def run_phase3_scikit_learn(wheels_dir: Path) -> int:
    """Phase 3: Install scipy and scikit-learn."""
    if should_skip_phase(3):
        log_info("Phase 3 is already complete. Set FORCE_RERUN=1 to rerun.")
        return 0
    
    setup_build_environment()
    
    # Check prerequisites
    if not python_pkg_installed("numpy", "numpy>=1.26.0"):
        log_error("numpy must be installed first (Phase 2)")
        return 1
    
    # Install scipy and scikit-learn using the standalone script
    if not python_pkg_installed("scikit-learn", "scikit-learn"):
        log_info("Installing scikit-learn using install_scikit_learn_standalone.py...")
        
        # Import and run the standalone script
        standalone_script = Path(__file__).parent / "install_scikit_learn_standalone.py"
        if not standalone_script.exists():
            log_error(f"install_scikit_learn_standalone.py not found at {standalone_script}")
            return 1
        
        # Run the standalone script
        result = subprocess.run([sys.executable, str(standalone_script)], check=False)
        if result.returncode != 0:
            log_error("scikit-learn installation failed (standalone script returned error)")
            return 1
        
        # Verify installation
        if not python_pkg_installed("scikit-learn", "scikit-learn"):
            log_error("scikit-learn installation succeeded but package not found")
            return 1
        
        # Copy any wheels built by the standalone script to our wheels directory
        # The standalone script uses HOME / "wheels", so copy from there
        standalone_wheels_dir = HOME / "wheels"
        if standalone_wheels_dir.exists():
            log_info(f"Copying wheels from {standalone_wheels_dir} to {wheels_dir}...")
            wheels_dir.mkdir(parents=True, exist_ok=True)
            for wheel_file in standalone_wheels_dir.glob("*.whl"):
                try:
                    shutil.copy2(wheel_file, wheels_dir / wheel_file.name)
                    log_info(f"Copied wheel: {wheel_file.name}")
                except Exception as e:
                    log_warning(f"Failed to copy wheel {wheel_file.name}: {e}")
        
        log_success("scikit-learn installed successfully")
    else:
        log_info("scikit-learn is already installed")
    
    # Verify all required packages are installed
    required_packages = [
        ("scipy", "scipy>=1.8.0,<1.17.0"),
        ("scikit-learn", "scikit-learn>=1.0.0"),
    ]
    
    missing = []
    for pkg_name, version_spec in required_packages:
        if not python_pkg_installed(pkg_name, version_spec):
            missing.append(pkg_name)
    
    if missing:
        log_error(f"Phase 3 incomplete: missing packages: {', '.join(missing)}")
        return 1
    
    # Verify packages can be imported
    try:
        import scipy
        import sklearn
        log_success("All Phase 3 packages verified and working")
    except ImportError as e:
        log_error(f"Phase 3 verification failed: {e}")
        return 1
    
    mark_phase_complete(3)
    return 0


def run_phase4_droidrun(wheels_dir: Path) -> int:
    """Phase 4: Install droidrun."""
    if python_pkg_installed("droidrun", "droidrun"):
        log_success("droidrun is already installed")
        return 0
    
    setup_build_environment()
    
    log_info("Installing droidrun...")
    clean_env = get_clean_env()
    
    # Packages already installed via pkg that droidrun depends on
    # pip wheel will try to rebuild these, but they're already installed
    pkg_installed_deps = ["grpcio", "pillow", "scipy", "numpy", "scikit-learn"]
    already_installed = []
    for dep in pkg_installed_deps:
        if python_pkg_installed(dep, dep):
            already_installed.append(dep)
    
    wheels_dir.mkdir(parents=True, exist_ok=True)
    
    if already_installed:
        log_info(f"Packages already installed via pkg: {', '.join(already_installed)}")
        log_info("Using pip install (respects already-installed packages, avoids rebuilding)")
        
        # Use pip install directly - it won't rebuild already-installed packages
        install_cmd = [
            sys.executable, "-m", "pip", "install",
            "--no-cache-dir",
            "droidrun"
        ]
        
        result = subprocess.run(install_cmd, env=clean_env, check=False)
        if result.returncode != 0:
            log_error("droidrun installation failed")
            return 1
        
        # Download wheels for droidrun and new dependencies (not already-installed ones)
        log_info("Downloading wheels for droidrun and new dependencies...")
        # Use pip download to get wheels without installing
        download_cmd = [
            sys.executable, "-m", "pip", "download",
            "--dest", str(wheels_dir),
            "--no-cache-dir",
            "droidrun"
        ]
        subprocess.run(download_cmd, env=clean_env, check=False)
        
        log_info("Wheels downloaded (already-installed packages skipped)")
    else:
        # No pkg-installed deps, use normal wheel preservation
        log_info("Installing droidrun with wheel preservation...")
        if not install_with_wheel_preservation("droidrun", wheels_dir, build_env=clean_env):
            log_error("droidrun installation failed")
            return 1
    
    if not python_pkg_installed("droidrun", "droidrun"):
        log_error("droidrun installation succeeded but package not found")
        return 1
    
    log_success("droidrun installed successfully")
    return 0


def main() -> int:
    """Main installation function."""
    log_info("=" * 70)
    log_info("Unified Droidrun Installation Script")
    log_info("=" * 70)
    log_info("This script will install droidrun and preserve ALL wheels")
    log_info("(including transitive dependencies) for easy export to another device.")
    log_info("=" * 70)
    
    # Setup wheels directory
    wheels_dir = Path(os.environ.get("WHEELS_DIR", str(HOME / "wheels")))
    wheels_dir.mkdir(parents=True, exist_ok=True)
    log_info(f"Wheels will be preserved in: {wheels_dir}")
    
    # Phase 1: Build tools
    log_info("\n" + "=" * 70)
    log_info("Phase 1: Installing build tools...")
    log_info("=" * 70)
    result = run_phase1_build_tools(wheels_dir)
    if result != 0:
        log_error("Phase 1 failed")
        return result
    
    # Phase 2: numpy
    log_info("\n" + "=" * 70)
    log_info("Phase 2: Installing numpy...")
    log_info("=" * 70)
    result = run_phase2_numpy(wheels_dir)
    if result != 0:
        log_error("Phase 2 failed")
        return result
    
    # Phase 3: scipy + scikit-learn
    log_info("\n" + "=" * 70)
    log_info("Phase 3: Installing scipy and scikit-learn...")
    log_info("=" * 70)
    result = run_phase3_scikit_learn(wheels_dir)
    if result != 0:
        log_error("Phase 3 failed")
        return result
    
    # Phase 4: droidrun
    log_info("\n" + "=" * 70)
    log_info("Phase 4: Installing droidrun...")
    log_info("=" * 70)
    result = run_phase4_droidrun(wheels_dir)
    if result != 0:
        log_error("Phase 4 failed")
        return result
    
    # Final summary
    log_info("\n" + "=" * 70)
    log_success("All phases completed successfully!")
    log_info("=" * 70)
    wheel_count = len(list(wheels_dir.glob("*.whl")))
    log_info(f"Total wheels preserved: {wheel_count}")
    log_info(f"Wheels directory: {wheels_dir}")
    log_info("=" * 70)
    log_info("You can now copy the wheels directory to another device and install from it:")
    log_info(f"  pip install --find-links {wheels_dir} --no-index droidrun")
    log_info("=" * 70)
    
    return 0


if __name__ == "__main__":
    sys.exit(main())

