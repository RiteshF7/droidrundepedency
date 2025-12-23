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


def main() -> int:
    if should_skip_phase(1):
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
        log_info("Installing pillow...")
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
            log_success("pillow installed successfully")
    else:
        log_info("pillow is already installed")
    
    # Install grpcio (requires abseil-cpp, patchelf)
    if not python_pkg_installed("grpcio", "grpcio"):
        log_info("Installing grpcio...")
        clean_env = get_clean_env()
        clean_env.update({
            "GRPC_PYTHON_BUILD_SYSTEM_OPENSSL": "1",
            "GRPC_PYTHON_BUILD_SYSTEM_ZLIB": "1",
            "GRPC_PYTHON_BUILD_SYSTEM_CARES": "1",
            "GRPC_PYTHON_BUILD_SYSTEM_RE2": "1",
            "GRPC_PYTHON_BUILD_SYSTEM_ABSL": "1",
            "GRPC_PYTHON_BUILD_WITH_CYTHON": "1",
        })
        
        # Try simple pip install first
        result = subprocess.run(
            [sys.executable, "-m", "pip", "install", "--no-cache-dir", "grpcio"],
            env=clean_env,
            check=False
        )
        
        if result.returncode != 0 or not python_pkg_installed("grpcio", "grpcio"):
            log_warning("Direct grpcio install failed, but continuing (will be handled in Phase 5 if needed)")
        else:
            log_success("grpcio installed successfully")
    else:
        log_info("grpcio is already installed")
    
    log_success("All Phase 1 packages verified and working")
    mark_phase_complete(1)
    return 0


if __name__ == "__main__":
    sys.exit(main())
