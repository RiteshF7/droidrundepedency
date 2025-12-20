"""Build utilities for package installation."""

import os
import sys
import subprocess
import shutil
import tempfile
import tarfile
import re
from pathlib import Path
from typing import Optional, Dict

try:
    from .common import python_pkg_installed, HOME, ERROR_LOG_FILE, log_info, log_success, log_error
except ImportError:
    from common import python_pkg_installed, HOME, ERROR_LOG_FILE, log_info, log_success, log_error


def download_and_fix_source(pkg_name: str, version_spec: str, fix_type: str) -> Optional[Path]:
    """Download and fix source for packages that need fixes."""
    work_dir = Path(tempfile.mkdtemp())
    
    try:
        # Download source
        result = subprocess.run(
            [sys.executable, "-m", "pip", "download", version_spec, 
             "--dest", ".", "--no-cache-dir", "--no-binary", ":all:"],
            cwd=work_dir,
            capture_output=True,
            check=False
        )
        if result.returncode != 0:
            return None
        
        # Find and extract
        source_files = list(work_dir.glob(f"{pkg_name}-*.tar.gz"))
        if not source_files:
            return None
        
        source_file = source_files[0]
        with tarfile.open(source_file, 'r:gz') as tar:
            tar.extractall(work_dir)
        
        pkg_dirs = [d for d in work_dir.iterdir() if d.is_dir() and d.name.startswith(f"{pkg_name}-")]
        if not pkg_dirs:
            return None
        
        pkg_dir = pkg_dirs[0]
        
        # Apply fixes
        if fix_type == "pandas":
            meson_build = pkg_dir / "meson.build"
            if meson_build.exists():
                pkg_version = pkg_dir.name.replace(f"{pkg_name}-", "")
                content = meson_build.read_text()
                content = re.sub(r"version: run_command.*", f"version: '{pkg_version}',", content)
                meson_build.write_text(content)
        
        elif fix_type == "scikit-learn":
            version_py = pkg_dir / "sklearn" / "_build_utils" / "version.py"
            if version_py.exists() and not version_py.read_text().startswith("#!/"):
                version_py.write_text("#!/usr/bin/env python3\n" + version_py.read_text())
            
            meson_build = pkg_dir / "meson.build"
            if meson_build.exists():
                pkg_version = pkg_dir.name.replace(f"{pkg_name}-", "")
                content = meson_build.read_text()
                content = re.sub(r"version: run_command.*", f"version: '{pkg_version}',", content)
                if "version: run_command" not in content:
                    content = re.sub(r"version:.*", f"version: '{pkg_version}',", content)
                meson_build.write_text(content)
        
        # Repackage
        new_source_file = work_dir / source_file.name
        with tarfile.open(new_source_file, 'w:gz') as tar:
            tar.add(pkg_dir, arcname=pkg_dir.name)
        
        return new_source_file if new_source_file.exists() else None
        
    except Exception:
        return None


def build_package(
    pkg_name: str,
    version_spec: str,
    no_build_isolation: bool = False,
    fix_source: Optional[str] = None,
    pre_check: bool = False,
    env_vars: Optional[Dict[str, str]] = None,
    wheel_pattern: Optional[str] = None
) -> bool:
    """Build and install a Python package."""
    if python_pkg_installed(pkg_name, version_spec):
        return True
    
    wheels_dir = Path(os.environ.get("WHEELS_DIR", str(HOME / "wheels")))
    wheels_dir.mkdir(exist_ok=True)
    
    if env_vars:
        os.environ.update(env_vars)
    
    # Pre-check for wheels
    if pre_check:
        local_wheels = list(wheels_dir.glob(wheel_pattern or f"{pkg_name}*.whl"))
        if local_wheels:
            result = subprocess.run(
                [sys.executable, "-m", "pip", "install", "--find-links", str(wheels_dir), 
                 "--no-index", str(local_wheels[0])],
                capture_output=True,
                check=False
            )
            if result.returncode == 0:
                return True
    
    # Download and fix source if needed
    source_arg = version_spec
    temp_dir = None
    if fix_source:
        fixed_source = download_and_fix_source(pkg_name, version_spec, fix_source)
        if fixed_source and fixed_source.exists():
            source_arg = str(fixed_source)
            temp_dir = fixed_source.parent
    
    # Build wheel
    build_cmd = [sys.executable, "-m", "pip", "wheel", source_arg, "--no-deps", "--wheel-dir", str(wheels_dir)]
    if no_build_isolation:
        build_cmd.append("--no-build-isolation")
    
    result = subprocess.run(build_cmd, capture_output=True, check=False)
    if result.returncode != 0:
        if temp_dir:
            shutil.rmtree(temp_dir, ignore_errors=True)
        return False
    
    # Find and install wheel
    wheel_files = list(wheels_dir.glob(wheel_pattern or f"{pkg_name}*.whl"))
    if not wheel_files:
        if temp_dir:
            shutil.rmtree(temp_dir, ignore_errors=True)
        return False
    
    result = subprocess.run(
        [sys.executable, "-m", "pip", "install", "--find-links", str(wheels_dir), 
         "--no-index", str(wheel_files[0])],
        capture_output=True,
        check=False
    )
    
    if temp_dir:
        shutil.rmtree(temp_dir, ignore_errors=True)
    
    return result.returncode == 0
