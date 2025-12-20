#!/usr/bin/env python3
"""Phase 5: Install pyarrow, psutil, grpcio, pillow"""

import sys
import os
import subprocess
import zipfile
import shutil
from pathlib import Path

current_dir = Path(__file__).parent.absolute()
sys.path.insert(0, str(current_dir))

try:
    from .common import should_skip_phase, mark_phase_complete, setup_build_environment, python_pkg_installed, HOME, PREFIX, get_build_env_with_compilers, get_clean_env, log_info, log_success, log_error, log_warning
except ImportError:
    from common import should_skip_phase, mark_phase_complete, setup_build_environment, python_pkg_installed, HOME, PREFIX, get_build_env_with_compilers, get_clean_env, log_info, log_success, log_error, log_warning


def fix_grpcio_wheel(wheel_file: Path) -> bool:
    """Fix grpcio wheel."""
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
    if should_skip_phase(5):
        return 0
    
    setup_build_environment()
    
    # pyarrow (optional) - needs CC/CXX for C++ extensions
    if not python_pkg_installed("pyarrow", "pyarrow"):
        log_info("Installing pyarrow...")
        build_env = get_build_env_with_compilers()
        build_env["ARROW_HOME"] = PREFIX
        result = subprocess.run(
            [sys.executable, "-m", "pip", "install", "--no-cache-dir", "pyarrow"],
            env=build_env,
            check=False
        )
        if result.returncode == 0 and python_pkg_installed("pyarrow", "pyarrow"):
            log_success("pyarrow installed successfully")
        else:
            log_warning("pyarrow installation failed, but continuing...")
    
    # psutil (optional) - can work without CC/CXX
    if not python_pkg_installed("psutil", "psutil"):
        log_info("Installing psutil...")
        clean_env = get_clean_env()
        result = subprocess.run(
            [sys.executable, "-m", "pip", "install", "--no-cache-dir", "psutil"],
            env=clean_env,
            check=False
        )
        if result.returncode == 0 and python_pkg_installed("psutil", "psutil"):
            log_success("psutil installed successfully")
        else:
            log_warning("psutil installation failed, but continuing...")
    
    # grpcio - can try without CC/CXX first, but may need special handling
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
            # Fallback to wheel build method
            log_warning("Direct install failed, trying wheel build method...")
            wheels_dir = Path(os.environ.get("WHEELS_DIR", str(HOME / "wheels")))
            result = subprocess.run(
                [sys.executable, "-m", "pip", "wheel", "grpcio", "--no-deps", 
                 "--no-build-isolation", "--wheel-dir", str(wheels_dir)],
                env=clean_env,
                capture_output=True,
                check=False
            )
            
            if result.returncode == 0:
                grpcio_wheels = list(wheels_dir.glob("grpcio*.whl"))
                if grpcio_wheels:
                    fix_grpcio_wheel(grpcio_wheels[0])
                    
                    # Install typing-extensions first
                    if not python_pkg_installed("typing-extensions", "typing-extensions>=4.12"):
                        subprocess.run([sys.executable, "-m", "pip", "install", "--no-cache-dir", "typing-extensions>=4.12"], 
                                     env=clean_env, check=False)
                    
                    # Install grpcio
                    subprocess.run([sys.executable, "-m", "pip", "install", "--no-deps", str(grpcio_wheels[0])], 
                                 env=clean_env, check=False)
        
        if python_pkg_installed("grpcio", "grpcio"):
            log_success("grpcio installed successfully")
        else:
            log_warning("grpcio installation failed, but continuing...")
        
        # Set LD_LIBRARY_PATH
        os.environ["LD_LIBRARY_PATH"] = f"{PREFIX}/lib:{os.environ.get('LD_LIBRARY_PATH', '')}"
        bashrc = HOME / ".bashrc"
        if bashrc.exists() and "LD_LIBRARY_PATH.*PREFIX/lib" not in bashrc.read_text():
            with open(bashrc, 'a') as f:
                f.write("export LD_LIBRARY_PATH=$PREFIX/lib:$LD_LIBRARY_PATH\n")
    
    # pillow (optional) - needs CC/CXX for C extensions
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
        if result.returncode == 0 and python_pkg_installed("pillow", "pillow"):
            log_success("pillow installed successfully")
        else:
            log_warning("pillow installation failed, but continuing...")
    
    mark_phase_complete(5)
    return 0


if __name__ == "__main__":
    import subprocess
    sys.exit(main())
