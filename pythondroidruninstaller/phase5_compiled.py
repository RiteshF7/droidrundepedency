#!/usr/bin/env python3
"""Phase 5: Install pyarrow, psutil, grpcio, pillow"""

import sys
import os
import zipfile
import shutil
from pathlib import Path

current_dir = Path(__file__).parent.absolute()
sys.path.insert(0, str(current_dir))

try:
    from .common import should_skip_phase, mark_phase_complete, setup_build_environment, python_pkg_installed, HOME, PREFIX
    from .build_utils import build_package
except ImportError:
    from common import should_skip_phase, mark_phase_complete, setup_build_environment, python_pkg_installed, HOME, PREFIX
    from build_utils import build_package


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
    
    # pyarrow (optional)
    build_package("pyarrow", "pyarrow", pre_check=True, env_vars={"ARROW_HOME": PREFIX})
    
    # psutil (optional)
    build_package("psutil", "psutil")
    
    # grpcio
    if not python_pkg_installed("grpcio", "grpcio"):
        os.environ.update({
            "GRPC_PYTHON_BUILD_SYSTEM_OPENSSL": "1",
            "GRPC_PYTHON_BUILD_SYSTEM_ZLIB": "1",
            "GRPC_PYTHON_BUILD_SYSTEM_CARES": "1",
            "GRPC_PYTHON_BUILD_SYSTEM_RE2": "1",
            "GRPC_PYTHON_BUILD_SYSTEM_ABSL": "1",
            "GRPC_PYTHON_BUILD_WITH_CYTHON": "1",
        })
        
        wheels_dir = Path(os.environ.get("WHEELS_DIR", str(HOME / "wheels")))
        result = subprocess.run(
            [sys.executable, "-m", "pip", "wheel", "grpcio", "--no-deps", 
             "--no-build-isolation", "--wheel-dir", str(wheels_dir)],
            capture_output=True,
            check=False
        )
        
        if result.returncode == 0:
            grpcio_wheels = list(wheels_dir.glob("grpcio*.whl"))
            if grpcio_wheels:
                fix_grpcio_wheel(grpcio_wheels[0])
                
                # Install typing-extensions first
                if not python_pkg_installed("typing-extensions", "typing-extensions>=4.12"):
                    subprocess.run([sys.executable, "-m", "pip", "install", "typing-extensions>=4.12"], check=False)
                
                # Install grpcio
                subprocess.run([sys.executable, "-m", "pip", "install", "--no-deps", str(grpcio_wheels[0])], check=False)
        
        # Set LD_LIBRARY_PATH
        os.environ["LD_LIBRARY_PATH"] = f"{PREFIX}/lib:{os.environ.get('LD_LIBRARY_PATH', '')}"
        bashrc = HOME / ".bashrc"
        if bashrc.exists() and "LD_LIBRARY_PATH.*PREFIX/lib" not in bashrc.read_text():
            with open(bashrc, 'a') as f:
                f.write("export LD_LIBRARY_PATH=$PREFIX/lib:$LD_LIBRARY_PATH\n")
    
    # pillow (optional)
    build_package("pillow", "pillow", env_vars={
        "PKG_CONFIG_PATH": f"{PREFIX}/lib/pkgconfig",
        "LDFLAGS": f"-L{PREFIX}/lib",
        "CPPFLAGS": f"-I{PREFIX}/include",
    })
    
    mark_phase_complete(5)
    return 0


if __name__ == "__main__":
    import subprocess
    sys.exit(main())
