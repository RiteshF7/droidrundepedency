#!/usr/bin/env python3
"""Phase 7: Install droidrun and providers"""

import sys
import os
import subprocess
import shutil
from pathlib import Path

current_dir = Path(__file__).parent.absolute()
sys.path.insert(0, str(current_dir))

try:
    from .common import should_skip_phase, mark_phase_complete, setup_build_environment, python_pkg_installed, HOME, log_info, log_success, log_error, log_warning
except ImportError:
    from common import should_skip_phase, mark_phase_complete, setup_build_environment, python_pkg_installed, HOME, log_info, log_success, log_error, log_warning


def find_droidrun_wheel() -> Path:
    """Find pre-built droidrun wheel in common locations."""
    for deps_dir in [
        Path(__file__).parent.parent.parent / "depedencies" / "wheels",
        HOME / "droidrundepedency" / "depedencies" / "wheels",
        HOME / "depedencies" / "wheels",
        HOME / "wheels",
    ]:
        for arch_dir in [deps_dir / "_x86_64_wheels", deps_dir / "arch64_wheels", deps_dir]:
            if arch_dir.exists():
                wheel = next(arch_dir.glob("droidrun*.whl"), None)
                if wheel:
                    return wheel
    return None


def check_network_connectivity() -> bool:
    """Check if network connectivity is available."""
    try:
        import socket
        socket.create_connection(("pypi.org", 443), timeout=3)
        return True
    except (OSError, socket.timeout):
        return False


def main() -> int:
    if should_skip_phase(7):
        return 0
    
    setup_build_environment()
    
    wheels_dir = Path(os.environ.get("WHEELS_DIR", str(HOME / "wheels")))
    wheels_dir.mkdir(exist_ok=True)
    
    # Install droidrun core first
    if not python_pkg_installed("droidrun", "droidrun"):
        log_info("Installing droidrun core...")
        
        # Create clean environment without CC/CXX overrides for better compatibility
        clean_env = os.environ.copy()
        clean_env.pop("CC", None)
        clean_env.pop("CXX", None)
        
        # Check for local wheel first
        droidrun_wheel = find_droidrun_wheel()
        if droidrun_wheel:
            log_info(f"Found local droidrun wheel: {droidrun_wheel.name}")
            wheels_dir.mkdir(parents=True, exist_ok=True)
            shutil.copy2(droidrun_wheel, wheels_dir / droidrun_wheel.name)
            result = subprocess.run(
                [sys.executable, "-m", "pip", "install", "--find-links", str(wheels_dir), 
                 "--no-index", str(wheels_dir / droidrun_wheel.name)],
                env=clean_env,
                check=False
            )
            if result.returncode == 0 and python_pkg_installed("droidrun", "droidrun"):
                log_success("droidrun installed from local wheel")
            else:
                log_warning("Local wheel installation failed, trying PyPI...")
                droidrun_wheel = None  # Fall through to PyPI install
        
        # If no local wheel or local wheel failed, try PyPI
        if not droidrun_wheel or not python_pkg_installed("droidrun", "droidrun"):
            # Check network connectivity
            if not check_network_connectivity():
                log_error("Network connectivity unavailable - cannot download droidrun from PyPI")
                log_error("Please ensure internet connection is available or provide local droidrun wheel")
                log_error("Expected wheel locations:")
                log_error(f"  - {HOME / 'droidrundepedency' / 'depedencies' / 'wheels'}")
                log_error(f"  - {HOME / 'depedencies' / 'wheels'}")
                log_error(f"  - {HOME / 'wheels'}")
                return 1
            
            # Check if pandas is already installed (from Phase 3)
            pandas_installed = python_pkg_installed("pandas", "pandas<2.3.0")
            
            if pandas_installed:
                log_info("pandas is already installed, using --no-build-isolation to prevent rebuild...")
                result = subprocess.run(
                    [sys.executable, "-m", "pip", "install", "--no-cache-dir", 
                     "--no-build-isolation", "droidrun", "--find-links", str(wheels_dir)],
                    env=clean_env,
                    check=False
                )
                
                if result.returncode != 0:
                    log_warning("--no-build-isolation failed, trying normal install...")
                    result = subprocess.run(
                        [sys.executable, "-m", "pip", "install", "--no-cache-dir", 
                         "--upgrade-strategy", "only-if-needed", "droidrun", "--find-links", str(wheels_dir)],
                        env=clean_env,
                        check=False
                    )
            else:
                # Normal install if pandas is not installed
                result = subprocess.run(
                    [sys.executable, "-m", "pip", "install", "--no-cache-dir", 
                     "--upgrade-strategy", "only-if-needed", "droidrun", "--find-links", str(wheels_dir)],
                    env=clean_env,
                    check=False
                )
            
            if result.returncode != 0:
                log_error(f"droidrun core installation failed with exit code {result.returncode}")
                log_error("Check the output above for detailed error messages")
                if "No address associated with hostname" in str(result.stderr) if hasattr(result, 'stderr') else False:
                    log_error("Network connectivity issue detected - please check internet connection")
                return 1
            
            if not python_pkg_installed("droidrun", "droidrun"):
                log_error("droidrun installation succeeded but package not found")
                return 1
        
        log_success("droidrun core installed successfully")
    else:
        log_success("droidrun core is already installed")
    
    # Check if tokenizers is available (required for some providers)
    tokenizers_available = python_pkg_installed("tokenizers", "tokenizers")
    if not tokenizers_available:
        log_warning("tokenizers is not installed - some providers may not be available")
    
    # Install providers
    providers = ["google", "anthropic", "openai", "ollama", "openrouter", "deepseek"]
    installed_providers = []
    failed_providers = []
    
    log_info("Installing droidrun providers...")
    
    for provider in providers:
        # Skip deepseek if tokenizers is not available
        if provider == "deepseek" and not tokenizers_available:
            log_warning(f"Skipping {provider} provider (requires tokenizers)")
            failed_providers.append(f"{provider} (requires tokenizers)")
            continue
        
        log_info(f"Installing droidrun[{provider}] provider...")
        
        # Create clean environment without CC/CXX overrides
        clean_env = os.environ.copy()
        clean_env.pop("CC", None)
        clean_env.pop("CXX", None)
        
        result = subprocess.run(
            [sys.executable, "-m", "pip", "install", "--no-cache-dir", 
             "--upgrade-strategy", "only-if-needed", "--no-build-isolation",
             f"droidrun[{provider}]", "--find-links", str(wheels_dir)],
            env=clean_env,
            check=False
        )
        
        if result.returncode == 0:
            log_success(f"droidrun[{provider}] installed successfully")
            installed_providers.append(provider)
        else:
            log_warning(f"droidrun[{provider}] installation failed with exit code {result.returncode}")
            log_warning("Check the output above for detailed error messages")
            failed_providers.append(provider)
    
    # Summary
    log_info("==========================================")
    log_info("Installation Summary")
    log_info("==========================================")
    
    if installed_providers:
        log_success(f"Successfully installed providers: {', '.join(installed_providers)}")
    
    if failed_providers:
        log_warning(f"Failed or skipped providers: {', '.join(failed_providers)}")
    
    if not installed_providers:
        log_warning("No providers were installed")
        return 1
    
    # Verify droidrun core is installed and can be imported
    if not python_pkg_installed("droidrun", "droidrun"):
        log_error("droidrun core not installed - Phase 7 incomplete")
        return 1
    
    try:
        import droidrun
        log_success("droidrun core verified and working")
    except ImportError as e:
        log_error(f"droidrun verification failed: {e}")
        return 1
    
    log_success(f"Phase 7 complete: Installed {len(installed_providers)} out of {len(providers)} providers")
    mark_phase_complete(7)
    return 0


if __name__ == "__main__":
    sys.exit(main())
