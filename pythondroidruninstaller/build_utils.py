"""Build utilities for package installation."""

import os
import sys
import subprocess
import shutil
import tempfile
import tarfile
import re
from pathlib import Path
from typing import Optional, List, Dict

from .common import (
    log_info, log_success, log_warning, log_error,
    python_pkg_installed, run_command, HOME, ERROR_LOG_FILE
)


def download_and_fix_source(pkg_name: str, version_spec: str, fix_type: str) -> Optional[Path]:
    """Download and fix source for packages that need fixes (pandas, scikit-learn)."""
    log_info(f"=== download_and_fix_source called ===")
    log_info(f"Parameters: pkg_name={pkg_name}, version_spec={version_spec}, fix_type={fix_type}")
    log_info(f"Downloading {pkg_name} source ({version_spec})...")
    
    work_dir = Path(tempfile.mkdtemp())
    log_info(f"Working directory: {work_dir}")
    
    try:
        # Download source using pip
        log_info(f"Running: python3 -m pip download \"{version_spec}\" --dest . --no-cache-dir --no-binary :all:")
        result = run_command(
            [sys.executable, "-m", "pip", "download", version_spec, 
             "--dest", ".", "--no-cache-dir", "--no-binary", ":all:"],
            check=False,
            capture_output=True,
            quiet=False
        )
        
        if result.returncode != 0:
            log_error(f"Failed to download {pkg_name} source (exit code: {result.returncode})")
            log_error("pip download output:")
            for line in result.stderr.split('\n'):
                if line.strip():
                    log_error(f"  {line}")
            return None
        
        log_info("pip download completed successfully")
        
        # Find downloaded file
        log_info(f"Searching for source file: {pkg_name}-*.tar.gz")
        source_files = list(work_dir.glob(f"{pkg_name}-*.tar.gz"))
        if not source_files:
            log_error(f"Downloaded source file not found for {pkg_name}")
            return None
        
        source_file = source_files[0]
        log_success(f"Found source file: {source_file.name}")
        
        # Extract
        log_info(f"Extracting {pkg_name} source...")
        with tarfile.open(source_file, 'r:gz') as tar:
            tar.extractall(work_dir)
        
        # Find extracted directory
        pkg_dirs = [d for d in work_dir.iterdir() if d.is_dir() and d.name.startswith(f"{pkg_name}-")]
        if not pkg_dirs:
            log_error(f"Extracted package directory not found for {pkg_name}")
            return None
        
        pkg_dir = pkg_dirs[0]
        log_success(f"Extracted to directory: {pkg_dir.name}")
        
        # Apply fixes
        if fix_type == "pandas":
            meson_build = pkg_dir / "meson.build"
            if meson_build.exists():
                log_info(f"Checking for meson.build in {pkg_dir.name}...")
                pkg_version = pkg_dir.name.replace(f"{pkg_name}-", "")
                log_info(f"Fixing meson.build: replacing version detection with '{pkg_version}'")
                
                content = meson_build.read_text()
                content = re.sub(r"version: run_command.*", f"version: '{pkg_version}',", content)
                meson_build.write_text(content)
                log_success("meson.build fixed")
            else:
                log_warning("meson.build not found (may not be needed)")
        
        elif fix_type == "scikit-learn":
            version_py = pkg_dir / "sklearn" / "_build_utils" / "version.py"
            if version_py.exists():
                content = version_py.read_text()
                if not content.startswith("#!/"):
                    log_info("Fixing sklearn/_build_utils/version.py: adding shebang")
                    version_py.write_text("#!/usr/bin/env python3\n" + content)
                    log_success("version.py fixed")
            
            meson_build = pkg_dir / "meson.build"
            if meson_build.exists():
                pkg_version = pkg_dir.name.replace(f"{pkg_name}-", "")
                log_info(f"Fixing meson.build: replacing version extraction with '{pkg_version}'")
                content = meson_build.read_text()
                content = re.sub(r"version: run_command.*", f"version: '{pkg_version}',", content)
                if "version: run_command" not in content:
                    content = re.sub(r"version:.*", f"version: '{pkg_version}',", content)
                meson_build.write_text(content)
                log_success("meson.build fixed")
        
        # Repackage
        log_info("Repackaging fixed source...")
        new_source_file = work_dir / source_file.name
        with tarfile.open(new_source_file, 'w:gz') as tar:
            tar.add(pkg_dir, arcname=pkg_dir.name)
        
        if not new_source_file.exists():
            log_error("Repackaged file not created")
            return None
        
        log_success(f"Repackaged source file created: {new_source_file}")
        return new_source_file
        
    except Exception as e:
        log_error(f"Error in download_and_fix_source: {e}")
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
    """Build and install a Python package."""
    if wheel_pattern is None:
        wheel_pattern = f"{pkg_name}*.whl"
    
    # Check if already installed
    if python_pkg_installed(pkg_name, version_spec):
        log_success(f"{pkg_name} is already installed and satisfies version requirement ({version_spec}), skipping build")
        return True
    
    log_info(f"{pkg_name} not installed or version requirement ({version_spec}) not satisfied, will build")
    log_info(f"Building {pkg_name}...")
    
    wheels_dir = Path(os.environ.get("WHEELS_DIR", str(HOME / "wheels")))
    wheels_dir.mkdir(exist_ok=True)
    
    # Set environment variables
    if env_vars:
        for key, value in env_vars.items():
            os.environ[key] = value
    
    # Pre-check for pre-built wheels
    if pre_check:
        log_info(f"Checking for pre-built {pkg_name} wheel...")
        local_wheels = list(wheels_dir.glob(wheel_pattern))
        if local_wheels:
            local_wheel = local_wheels[0]
            log_info(f"Found pre-built wheel: {local_wheel.name}")
            try:
                result = run_command(
                    [sys.executable, "-m", "pip", "install", 
                     "--find-links", str(wheels_dir), "--no-index", str(local_wheel)],
                    check=False,
                    capture_output=True
                )
                if result.returncode == 0:
                    log_success(f"{pkg_name} installed (pre-built wheel)")
                    return True
            except Exception:
                pass
        
        # Try downloading from PyPI
        try:
            run_command(
                [sys.executable, "-m", "pip", "download", version_spec, 
                 "--dest", str(wheels_dir), "--no-cache-dir"],
                check=False,
                capture_output=True
            )
            downloaded_wheels = list(wheels_dir.glob(wheel_pattern))
            if downloaded_wheels:
                downloaded_wheel = downloaded_wheels[0]
                result = run_command(
                    [sys.executable, "-m", "pip", "install",
                     "--find-links", str(wheels_dir), "--no-index", str(downloaded_wheel)],
                    check=False,
                    capture_output=True
                )
                if result.returncode == 0:
                    log_success(f"{pkg_name} installed (pre-built wheel)")
                    return True
        except Exception:
            pass
        
        log_info("No pre-built wheel found, building from source...")
    
    # Download and fix source if needed
    source_arg = version_spec
    temp_dir = None
    if fix_source:
        fixed_source = download_and_fix_source(pkg_name, version_spec, fix_source)
        if fixed_source and fixed_source.exists():
            source_arg = str(fixed_source)
            temp_dir = fixed_source.parent
        else:
            log_error(f"Failed to download and fix {pkg_name} source")
            return False
    
    # Build wheel
    log_info(f"Building {pkg_name} wheel (pip will download source automatically)...")
    build_cmd = [sys.executable, "-m", "pip", "wheel", source_arg, "--no-deps", "--wheel-dir", str(wheels_dir)]
    if no_build_isolation:
        build_cmd.append("--no-build-isolation")
    
    try:
        result = run_command(build_cmd, check=False, capture_output=True)
        
        if result.returncode != 0:
            log_error(f"Failed to build {pkg_name} wheel (exit code: {result.returncode})")
            # Log error details
            with open(ERROR_LOG_FILE, 'a') as f:
                from datetime import datetime
                f.write(f"=== Build Error for {pkg_name} at {datetime.now()} ===\n")
                f.write(f"Exit code: {result.returncode}\n")
                f.write(f"Command: {' '.join(build_cmd)}\n")
                f.write("--- Error lines ---\n")
                error_lines = [l for l in result.stderr.split('\n') if any(x in l.lower() for x in ['error', 'failed', 'exception', 'traceback'])]
                f.write('\n'.join(error_lines[:30]))
                f.write("\n--- Last 20 lines of output ---\n")
                f.write('\n'.join(result.stderr.split('\n')[-20:]))
                f.write("\n=== End of error ===\n\n")
            
            # Show errors
            for line in error_lines[:30]:
                log_error(f"  {line}")
            log_error("Full error details saved to error log")
            if temp_dir:
                shutil.rmtree(temp_dir, ignore_errors=True)
            return False
        
        # Display relevant output
        output_lines = result.stderr.split('\n')
        for line in output_lines[-30:]:
            if line.strip() and 'looking in indexes' not in line.lower() and 'collecting' not in line.lower():
                if not any(x in line.lower() for x in ['error', 'failed', 'exception']):
                    log_info(f"  {line}")
    
    except Exception as e:
        log_error(f"Exception during build: {e}")
        if temp_dir:
            shutil.rmtree(temp_dir, ignore_errors=True)
        return False
    
    # Find wheel file
    wheel_files = list(wheels_dir.glob(wheel_pattern))
    if not wheel_files:
        log_error(f"Wheel file not found after build: {wheel_pattern}")
        log_error(f"Searched in: {wheels_dir}")
        if temp_dir:
            shutil.rmtree(temp_dir, ignore_errors=True)
        return False
    
    wheel_file = wheel_files[0].resolve()
    log_success(f"{pkg_name} wheel built successfully")
    
    # Cleanup temp directory
    if temp_dir:
        shutil.rmtree(temp_dir, ignore_errors=True)
    
    # Install wheel
    log_info(f"Installing {pkg_name} wheel...")
    try:
        result = run_command(
            [sys.executable, "-m", "pip", "install",
             "--find-links", str(wheels_dir), "--no-index", str(wheel_file)],
            check=False,
            capture_output=True
        )
        
        if result.returncode != 0:
            log_error(f"Failed to install {pkg_name} wheel")
            for line in result.stderr.split('\n'):
                if line.strip() and 'looking in indexes' not in line.lower() and 'collecting' not in line.lower():
                    log_error(f"  {line}")
            return False
        
        # Display output
        for line in result.stdout.split('\n') + result.stderr.split('\n'):
            if line.strip() and 'looking in indexes' not in line.lower() and 'collecting' not in line.lower():
                if 'the folder you are executing pip from' not in line.lower():
                    log_info(f"  {line}")
        
        log_success(f"{pkg_name} installed")
        return True
        
    except Exception as e:
        log_error(f"Exception during installation: {e}")
        return False

