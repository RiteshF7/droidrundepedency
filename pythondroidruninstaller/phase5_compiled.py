#!/usr/bin/env python3
"""Phase 5: Other Compiled Packages
Installs pyarrow, psutil, grpcio, pillow
"""

import sys
import os
import zipfile
import shutil
from pathlib import Path

# Add current directory to path for imports
current_dir = Path(__file__).parent.absolute()
if str(current_dir) not in sys.path:
    sys.path.insert(0, str(current_dir))
parent_dir = current_dir.parent
if str(parent_dir) not in sys.path:
    sys.path.insert(0, str(parent_dir))

try:
    from .common import (
        log_info, log_success, log_warning, log_error,
        should_skip_phase, mark_phase_complete, save_env_vars,
        load_env_vars, setup_build_environment, init_logging,
        python_pkg_installed, run_command, HOME, PREFIX
    )
    from .build_utils import build_package
except ImportError:
    from common import (
        log_info, log_success, log_warning, log_error,
        should_skip_phase, mark_phase_complete, save_env_vars,
        load_env_vars, setup_build_environment, init_logging,
        python_pkg_installed, run_command, HOME, PREFIX
    )
    from build_utils import build_package


def fix_grpcio_wheel(wheel_file: Path) -> bool:
    """Fix grpcio wheel by adding abseil libraries."""
    log_info(f"Fixing grpcio wheel: {wheel_file.name}")
    
    extract_dir = wheel_file.parent / "grpcio_extract"
    extract_dir.mkdir(exist_ok=True)
    
    try:
        # Extract wheel
        with zipfile.ZipFile(wheel_file, 'r') as zf:
            zf.extractall(extract_dir)
        
        # Find .so file
        so_files = list(extract_dir.rglob("cygrpc*.so"))
        if not so_files:
            log_error("cygrpc*.so not found in wheel")
            shutil.rmtree(extract_dir, ignore_errors=True)
            return False
        
        so_file = so_files[0]
        
        # Use patchelf to fix (if available)
        if shutil.which("patchelf"):
            run_command(["patchelf", "--add-needed", "libabsl_flags_internal.so", str(so_file)], check=False)
            run_command(["patchelf", "--add-needed", "libabsl_flags.so", str(so_file)], check=False)
            run_command(["patchelf", "--add-needed", "libabsl_flags_commandlineflag.so", str(so_file)], check=False)
            run_command(["patchelf", "--add-needed", "libabsl_flags_reflection.so", str(so_file)], check=False)
            run_command(["patchelf", "--set-rpath", f"{PREFIX}/lib", str(so_file)], check=False)
            log_success("grpcio wheel fixed with patchelf")
        else:
            log_warning("patchelf not found - skipping wheel fix (may cause runtime issues)")
        
        # Repackage
        fixed_wheel = wheel_file.parent / "grpcio-fixed.whl"
        with zipfile.ZipFile(fixed_wheel, 'w', zipfile.ZIP_DEFLATED) as zf:
            for root, dirs, files in os.walk(extract_dir):
                for file in files:
                    filepath = Path(root) / file
                    arcname = filepath.relative_to(extract_dir)
                    zf.write(filepath, arcname)
        
        # Replace original
        wheel_file.unlink()
        fixed_wheel.rename(wheel_file)
        shutil.rmtree(extract_dir, ignore_errors=True)
        return True
        
    except Exception as e:
        log_error(f"Failed to fix grpcio wheel: {e}")
        shutil.rmtree(extract_dir, ignore_errors=True)
        return False


def main() -> int:
    """Main function for Phase 5."""
    log_info("=" * 42)
    log_info("Phase 5: Compiled Packages Installation")
    log_info("=" * 42)
    
    init_logging()
    
    if should_skip_phase(5):
        log_success("Phase 5 already completed (skipping)")
        log_info("To force rerun, set FORCE_RERUN=1 environment variable")
        return 0
    
    load_env_vars()
    setup_build_environment()
    
    log_info("Phase 5: Building other compiled packages...")
    
    # Build pyarrow (optional)
    if not build_package("pyarrow", "pyarrow", pre_check=True, 
                        env_vars={"ARROW_HOME": PREFIX}):
        log_warning("pyarrow build failed - continuing without it")
        log_warning("Some droidrun features may not work without pyarrow")
    
    # Build psutil (optional)
    if not build_package("psutil", "psutil"):
        log_warning("psutil build failed - continuing without it")
        log_warning("Some droidrun features may not work without psutil")
    
    # Build grpcio (with special handling)
    if python_pkg_installed("grpcio", "grpcio"):
        log_success("grpcio is already installed, skipping build")
    else:
        log_info("Building grpcio (this may take a while)...")
        
        # Set GRPC build flags
        os.environ["GRPC_PYTHON_BUILD_SYSTEM_OPENSSL"] = "1"
        os.environ["GRPC_PYTHON_BUILD_SYSTEM_ZLIB"] = "1"
        os.environ["GRPC_PYTHON_BUILD_SYSTEM_CARES"] = "1"
        os.environ["GRPC_PYTHON_BUILD_SYSTEM_RE2"] = "1"
        os.environ["GRPC_PYTHON_BUILD_SYSTEM_ABSL"] = "1"
        os.environ["GRPC_PYTHON_BUILD_WITH_CYTHON"] = "1"
        
        wheels_dir = Path(os.environ.get("WHEELS_DIR", str(HOME / "wheels")))
        
        # Build wheel
        log_info("Building grpcio wheel...")
        result = run_command(
            [sys.executable, "-m", "pip", "wheel", "grpcio", 
             "--no-deps", "--no-build-isolation", "--wheel-dir", str(wheels_dir)],
            check=False,
            capture_output=True
        )
        
        if result.returncode != 0:
            log_error("Failed to build grpcio wheel")
            for line in result.stderr.split('\n'):
                if line.strip() and 'looking in indexes' not in line.lower():
                    log_error(f"  {line}")
            return 1
        
        # Find wheel
        grpcio_wheels = list(wheels_dir.glob("grpcio*.whl"))
        if not grpcio_wheels:
            log_error("grpcio wheel file not found after build")
            return 1
        
        grpcio_wheel = grpcio_wheels[0]
        log_success("grpcio wheel built successfully")
        
        # Fix wheel
        if not fix_grpcio_wheel(grpcio_wheel):
            log_error("Failed to fix grpcio wheel")
            return 1
        
        # Install typing-extensions first
        if not python_pkg_installed("typing-extensions", "typing-extensions>=4.12"):
            log_info("Installing typing-extensions (required by grpcio)...")
            result = run_command(
                [sys.executable, "-m", "pip", "install", "typing-extensions>=4.12"],
                check=False,
                capture_output=True
            )
            if result.returncode != 0:
                log_error("Failed to install typing-extensions")
                return 1
            # Verify import
            try:
                __import__("typing_extensions")
                log_success("typing-extensions installed and verified")
            except ImportError:
                log_error("typing-extensions installation succeeded but package is not importable")
                return 1
        
        # Install grpcio wheel
        log_info("Installing grpcio wheel...")
        result = run_command(
            [sys.executable, "-m", "pip", "install", "--no-deps", str(grpcio_wheel)],
            check=False,
            capture_output=True
        )
        
        if result.returncode != 0:
            log_error("Failed to install grpcio wheel")
            for line in result.stderr.split('\n'):
                if line.strip() and 'looking in indexes' not in line.lower():
                    log_error(f"  {line}")
            return 1
        
        log_success("grpcio installed (wheel fixed)")
        
        # Set LD_LIBRARY_PATH
        os.environ["LD_LIBRARY_PATH"] = f"{PREFIX}/lib:{os.environ.get('LD_LIBRARY_PATH', '')}"
        bashrc = HOME / ".bashrc"
        if bashrc.exists():
            content = bashrc.read_text()
            if "LD_LIBRARY_PATH.*PREFIX/lib" not in content:
                with open(bashrc, 'a') as f:
                    f.write(f"export LD_LIBRARY_PATH=$PREFIX/lib:$LD_LIBRARY_PATH\n")
    
    # Build Pillow (optional)
    pillow_env = {
        "PKG_CONFIG_PATH": f"{PREFIX}/lib/pkgconfig:{os.environ.get('PKG_CONFIG_PATH', '')}",
        "LDFLAGS": f"-L{PREFIX}/lib",
        "CPPFLAGS": f"-I{PREFIX}/include",
    }
    if not build_package("pillow", "pillow", env_vars=pillow_env):
        log_warning("pillow build failed - continuing without it")
        log_warning("Some droidrun features may not work without pillow")
    
    log_success("Phase 5 complete: Other compiled packages processed")
    mark_phase_complete(5)
    save_env_vars()
    
    log_success("Phase 5 completed successfully")
    return 0


if __name__ == "__main__":
    sys.exit(main())

