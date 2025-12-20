#!/usr/bin/env python3
"""Phase 7: Install droidrun and providers"""

import sys
import os
import subprocess
from pathlib import Path

current_dir = Path(__file__).parent.absolute()
sys.path.insert(0, str(current_dir))

try:
    from .common import should_skip_phase, mark_phase_complete, setup_build_environment, python_pkg_installed, HOME, log_info, log_success, log_error, log_warning
except ImportError:
    from common import should_skip_phase, mark_phase_complete, setup_build_environment, python_pkg_installed, HOME, log_info, log_success, log_error, log_warning


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
        
        # Try installing from wheels first, then PyPI
        result = subprocess.run(
            [sys.executable, "-m", "pip", "install", "--no-cache-dir", "droidrun", "--find-links", str(wheels_dir)],
            env=clean_env,
            check=False
        )
        
        if result.returncode != 0:
            log_warning("Installation from wheels failed, trying PyPI...")
            result = subprocess.run(
                [sys.executable, "-m", "pip", "install", "--no-cache-dir", "droidrun"],
                env=clean_env,
                check=False
            )
        
        if result.returncode != 0:
            log_error("Failed to install droidrun core")
            return 1
        
        if not python_pkg_installed("droidrun", "droidrun"):
            log_error("droidrun installation completed but package not found")
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
            [sys.executable, "-m", "pip", "install", "--no-cache-dir", f"droidrun[{provider}]", "--find-links", str(wheels_dir)],
            env=clean_env,
            check=False
        )
        
        if result.returncode == 0:
            log_success(f"droidrun[{provider}] installed successfully")
            installed_providers.append(provider)
        else:
            log_warning(f"Failed to install droidrun[{provider}]")
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
    
    log_success(f"Phase 7 complete: Installed {len(installed_providers)} out of {len(providers)} providers")
    mark_phase_complete(7)
    return 0


if __name__ == "__main__":
    sys.exit(main())
