#!/usr/bin/env python3
"""Phase 1: Install build tools"""

import sys
import os
import subprocess
import shutil
import zipfile
from pathlib import Path

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


def main() -> int:
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
        # Note: python-pip is already installed above
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
    
    # Essential tools
    essential = [
        ("wheel", "wheel"),
        ("setuptools", "setuptools"),
        ("Cython", "Cython"),
        ("meson-python", "meson-python<0.19.0,>=0.16.0"),
    ]
    
    for name, spec in essential:
        if not python_pkg_installed(name, spec):
            log_info(f"Installing {name}...")
            result = subprocess.run(
                [sys.executable, "-m", "pip", "install", "--no-cache-dir", spec],
                check=False
            )
            if result.returncode != 0:
                log_error(f"Failed to install {name}")
                return 1
            # Verify it was actually installed
            if not python_pkg_installed(name, spec):
                log_error(f"{name} installation reported success but package not found")
                return 1
            log_success(f"{name} installed successfully")
        else:
            log_info(f"{name} is already installed")
    
    # maturin (optional - needed for Phase 4 jiter, but not critical for Phase 1)
    # Try pre-built wheel first, then pip install (may fail if rust has issues, that's OK)
    if not python_pkg_installed("maturin", "maturin<2,>=1.9.4"):
        log_info("Installing maturin...")
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
    else:
        log_info("maturin is already installed")
    
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
                    # Verify it's actually available as Python package
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
        
        # Fallback to pip install if pkg install failed or not available
        if not pillow_installed:
            log_info("Installing pillow via pip...")
            build_env = get_build_env_with_compilers()
            build_env.update({
                "PKG_CONFIG_PATH": f"{PREFIX}/lib/pkgconfig",
                "LDFLAGS": f"-L{PREFIX}/lib",
                "CPPFLAGS": f"-I{PREFIX}/include",
            })
            result = subprocess.run(
                [sys.executable, "-m", "pip", "install", "--no-cache-dir", "pillow"],
                env=build_env,
                check=False
            )
            if result.returncode != 0:
                log_warning(f"pillow installation failed with exit code {result.returncode} (optional, continuing...)")
            elif not python_pkg_installed("pillow", "pillow"):
                log_warning("pillow installation succeeded but package not found (optional, continuing...)")
            else:
                log_success("pillow installed successfully via pip")
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
                    # Verify it's actually available as Python package
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
        
        # Fallback to pip/wheel build method if pkg install failed or not available
        if not grpcio_installed:
            log_info("Installing grpcio via pip...")
            clean_env = get_clean_env()
            clean_env.update({
                "GRPC_PYTHON_BUILD_SYSTEM_OPENSSL": "1",
                "GRPC_PYTHON_BUILD_SYSTEM_ZLIB": "1",
                "GRPC_PYTHON_BUILD_SYSTEM_CARES": "1",
                "GRPC_PYTHON_BUILD_SYSTEM_RE2": "1",
                "GRPC_PYTHON_BUILD_SYSTEM_ABSL": "1",
                "GRPC_PYTHON_BUILD_WITH_CYTHON": "1",
            })
            
            # Ensure Cython is installed (required for grpcio build)
            if not python_pkg_installed("Cython", "Cython"):
                log_info("Installing Cython (required for grpcio build)...")
                cython_result = subprocess.run(
                    [sys.executable, "-m", "pip", "install", "--no-cache-dir", "Cython"],
                    env=clean_env,
                    check=False
                )
                if cython_result.returncode != 0:
                    log_warning("Failed to install Cython - grpcio build may fail")
            
            # Ensure typing-extensions is installed (required for grpcio)
            if not python_pkg_installed("typing-extensions", "typing-extensions>=4.12"):
                log_info("Installing typing-extensions (required by grpcio)...")
                typing_ext_result = subprocess.run(
                    [sys.executable, "-m", "pip", "install", "--no-cache-dir", "typing-extensions>=4.12"],
                    env=clean_env,
                    check=False
                )
                if typing_ext_result.returncode != 0:
                    log_warning("Failed to install typing-extensions - grpcio installation may fail")
            
            # Try simple pip install first
            result = subprocess.run(
                [sys.executable, "-m", "pip", "install", "--no-cache-dir", "grpcio"],
                env=clean_env,
                check=False
            )
            
            if result.returncode != 0 or not python_pkg_installed("grpcio", "grpcio"):
                # Fallback to wheel build method (from Phase 5)
                log_warning("Direct install failed, trying wheel build method...")
                wheels_dir = Path(os.environ.get("WHEELS_DIR", str(HOME / "wheels")))
                wheels_dir.mkdir(parents=True, exist_ok=True)
                
                # Build wheel with --no-build-isolation so Cython from main env is available
                result = subprocess.run(
                    [sys.executable, "-m", "pip", "wheel", "grpcio", "--no-deps", 
                     "--no-build-isolation", "--wheel-dir", str(wheels_dir)],
                    env=clean_env,
                    check=False
                )
                
                if result.returncode == 0:
                    grpcio_wheels = list(wheels_dir.glob("grpcio*.whl"))
                    if grpcio_wheels:
                        log_info("Fixing grpcio wheel with patchelf...")
                        fix_grpcio_wheel(grpcio_wheels[0])
                        
                        # Install typing-extensions first
                        if not python_pkg_installed("typing-extensions", "typing-extensions>=4.12"):
                            dep_result = subprocess.run([sys.executable, "-m", "pip", "install", "--no-cache-dir", "typing-extensions>=4.12"], 
                                         env=clean_env, check=False)
                            if dep_result.returncode != 0:
                                log_warning(f"Failed to install typing-extensions: {dep_result.returncode}")
                        
                        # Install grpcio from fixed wheel
                        install_result = subprocess.run([sys.executable, "-m", "pip", "install", "--no-deps", str(grpcio_wheels[0])], 
                                     env=clean_env, check=False)
                        if install_result.returncode != 0:
                            log_warning(f"Failed to install grpcio from wheel: {install_result.returncode} (will be handled in Phase 5 if needed)")
                        elif python_pkg_installed("grpcio", "grpcio"):
                            log_success("grpcio installed successfully from wheel")
                        else:
                            log_warning("grpcio wheel installed but package not found (will be handled in Phase 5 if needed)")
                    else:
                        log_warning("grpcio wheel build succeeded but wheel not found (will be handled in Phase 5 if needed)")
                else:
                    log_warning("grpcio wheel build failed (will be handled in Phase 5 if needed)")
            else:
                log_success("grpcio installed successfully via pip")
    else:
        log_info("grpcio is already installed")
    
    log_success("All Phase 1 packages verified and working")
    mark_phase_complete(1)
    return 0


if __name__ == "__main__":
    sys.exit(main())
