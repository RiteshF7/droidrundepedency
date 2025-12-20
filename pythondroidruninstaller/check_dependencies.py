#!/usr/bin/env python3
"""Check all Python packages mentioned in DEPENDENCIES.md"""

import sys
from pathlib import Path

current_dir = Path(__file__).parent.absolute()
sys.path.insert(0, str(current_dir))

try:
    from .common import python_pkg_installed, log_info, log_success, log_warning, log_error
except ImportError:
    from common import python_pkg_installed, log_info, log_success, log_warning, log_error


# All Python packages from DEPENDENCIES.md organized by phase
PACKAGES_BY_PHASE = {
    "Phase 1 - Build Tools": [
        ("Cython", "Cython"),
        ("meson-python", "meson-python<0.19.0,>=0.16.0"),
        ("maturin", "maturin<2,>=1.9.4"),
    ],
    "Phase 2 - Foundation": [
        ("numpy", "numpy>=1.26.0"),
        ("patchelf", "patchelf"),  # Python package, not system
    ],
    "Phase 3 - Scientific Stack": [
        ("scipy", "scipy>=1.8.0,<1.17.0"),
        ("pandas", "pandas<2.3.0"),
        ("scikit-learn", "scikit-learn>=1.0.0"),
        ("joblib", "joblib>=1.3.0"),
        ("threadpoolctl", "threadpoolctl>=3.2.0"),
    ],
    "Phase 4 - Rust Packages": [
        ("jiter", "jiter==0.12.0"),
    ],
    "Phase 5 - Other Compiled": [
        ("pyarrow", "pyarrow"),
        ("psutil", "psutil"),
        ("grpcio", "grpcio"),
        ("pillow", "pillow"),
    ],
    "Phase 6 - Optional Compiled": [
        ("tokenizers", "tokenizers"),
        ("safetensors", "safetensors"),
        ("cryptography", "cryptography"),
        ("pydantic-core", "pydantic-core"),
        ("orjson", "orjson"),
    ],
    "Phase 7 - Core & Providers": [
        ("droidrun", "droidrun"),
        # Core dependencies
        ("async-adbutils", "async-adbutils"),
        ("llama-index", "llama-index==0.14.4"),
        ("arize-phoenix", "arize-phoenix>=12.3.0"),
        ("llama-index-readers-file", "llama-index-readers-file<0.6,>=0.5.0"),
        ("llama-index-workflows", "llama-index-workflows==2.8.3"),
        ("llama-index-callbacks-arize-phoenix", "llama-index-callbacks-arize-phoenix>=0.6.1"),
        ("httpx", "httpx>=0.27.0"),
        ("pydantic", "pydantic>=2.11.10"),
        ("rich", "rich>=14.1.0"),
        ("posthog", "posthog>=6.7.6"),
        ("aiofiles", "aiofiles>=25.1.0"),
    ],
    "Phase 7 - LLM Providers": [
        ("llama-index-llms-google-genai", "llama-index-llms-google-genai"),  # google
        ("google-genai", "google-genai"),  # google
        ("anthropic", "anthropic"),  # anthropic
        ("llama-index-llms-anthropic", "llama-index-llms-anthropic"),  # anthropic
        ("openai", "openai>=1.1.0"),  # openai
        ("llama-index-llms-openai", "llama-index-llms-openai<0.7,>=0.6.0"),  # openai
        ("llama-index-llms-deepseek", "llama-index-llms-deepseek"),  # deepseek
        ("transformers", "transformers"),  # deepseek
        ("huggingface-hub", "huggingface-hub"),  # deepseek
        ("llama-index-llms-ollama", "llama-index-llms-ollama"),  # ollama
        ("ollama", "ollama"),  # ollama
        ("llama-index-llms-openrouter", "llama-index-llms-openrouter"),  # openrouter
    ],
}


def check_package(pkg_name: str, version_spec: str) -> bool:
    """Check if a package is installed."""
    try:
        return python_pkg_installed(pkg_name, version_spec)
    except Exception as e:
        log_warning(f"Error checking {pkg_name}: {e}")
        return False


def main() -> int:
    """Check all packages and print results."""
    print("=" * 70)
    print("Checking Python Packages from DEPENDENCIES.md")
    print("=" * 70)
    print()
    
    all_installed = []
    all_missing = []
    
    for phase_name, packages in PACKAGES_BY_PHASE.items():
        print(f"\n{phase_name}:")
        print("-" * 70)
        
        phase_installed = []
        phase_missing = []
        
        for pkg_name, version_spec in packages:
            is_installed = check_package(pkg_name, version_spec)
            
            if is_installed:
                print(f"  ✓ {pkg_name} ({version_spec})")
                phase_installed.append((pkg_name, version_spec))
                all_installed.append((pkg_name, version_spec, phase_name))
            else:
                print(f"  ✗ {pkg_name} ({version_spec})")
                phase_missing.append((pkg_name, version_spec))
                all_missing.append((pkg_name, version_spec, phase_name))
        
        if phase_installed:
            print(f"\n  Installed: {len(phase_installed)}/{len(packages)}")
        if phase_missing:
            print(f"  Missing: {len(phase_missing)}/{len(packages)}")
    
    # Summary
    print("\n" + "=" * 70)
    print("SUMMARY")
    print("=" * 70)
    
    total_packages = len(all_installed) + len(all_missing)
    installed_count = len(all_installed)
    missing_count = len(all_missing)
    
    print(f"\nTotal packages: {total_packages}")
    print(f"Installed: {installed_count} ({installed_count * 100 // total_packages if total_packages > 0 else 0}%)")
    print(f"Missing: {missing_count} ({missing_count * 100 // total_packages if total_packages > 0 else 0}%)")
    
    if all_installed:
        print(f"\n✓ Installed packages ({installed_count}):")
        for pkg_name, version_spec, phase in all_installed:
            print(f"  - {pkg_name} ({version_spec}) [{phase}]")
    
    if all_missing:
        print(f"\n✗ Missing packages ({missing_count}):")
        for pkg_name, version_spec, phase in all_missing:
            print(f"  - {pkg_name} ({version_spec}) [{phase}]")
    
    print("\n" + "=" * 70)
    
    if missing_count == 0:
        log_success("All packages are installed!")
        return 0
    else:
        log_warning(f"{missing_count} package(s) are missing")
        return 1


if __name__ == "__main__":
    sys.exit(main())

