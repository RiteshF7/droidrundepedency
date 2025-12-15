#!/usr/bin/env python3
"""
Main dependency discovery script.
Discovers all transitive dependencies and checks wheel availability.
"""

import json
import sys
import subprocess
import os
import argparse
from pathlib import Path
import re
from datetime import datetime

# Add utils directory to path
sys.path.insert(0, os.path.dirname(__file__))

try:
    from check_wheel_availability import check_wheel_availability
except ImportError:
    # Fallback if import fails
    import importlib.util
    spec = importlib.util.spec_from_file_location(
        "check_wheel_availability",
        os.path.join(os.path.dirname(__file__), "check-wheel-availability.py")
    )
    check_wheel_availability_module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(check_wheel_availability_module)
    check_wheel_availability = check_wheel_availability_module.check_wheel_availability


def get_package_requirements(pkg_name):
    """Get requirements for a package using pip show"""
    requirements = []
    try:
        result = subprocess.run(
            ["pip", "show", pkg_name],
            capture_output=True,
            text=True,
            timeout=30
        )
        if result.returncode == 0:
            for line in result.stdout.split('\n'):
                if line.startswith('Requires:'):
                    deps = line.replace('Requires:', '').strip()
                    if deps:
                        requirements.extend([d.strip() for d in deps.split(',')])
    except Exception:
        pass
    return requirements


# Known system package requirements
SYSTEM_PACKAGES = {
    "numpy": ["clang", "ninja", "meson-python"],
    "scipy": ["flang", "blas-openblas", "clang", "cmake", "ninja"],
    "pandas": ["clang", "ninja", "meson-python", "Cython"],
    "scikit-learn": ["flang", "blas-openblas", "clang", "cmake", "ninja"],
    "jiter": ["rust", "maturin"],
    "pyarrow": ["libarrow-cpp", "clang", "cmake", "ninja"],
    "pillow": ["libjpeg-turbo", "libpng", "libtiff", "libwebp", "freetype"],
    "grpcio": ["openssl", "libc++", "zlib", "protobuf", "abseil-cpp", "c-ares", "re2"],
    "patchelf": ["autoconf", "automake", "libtool", "cmake", "ninja"]
}

# Known special fixes
SPECIAL_FIXES = {
    "pandas": ["meson_build_version_fix"],
    "scikit-learn": ["version_py_permissions", "version_py_shebang"],
    "pyarrow": ["arrow_cpp_version_match"],
    "grpcio": ["build_isolation_bypass"],
    "pillow": ["image_library_dependencies"]
}

# Known version constraints from documentation
VERSION_CONSTRAINTS = {
    "pandas": "<2.3.0",
    "scipy": ">=1.8.0,<1.17.0",
    "numpy": ">=1.26.0",
    "jiter": "==0.12.0",
    "meson-python": "<0.19.0,>=0.16.0",
    "maturin": "<2,>=1.9.4",
    "Cython": ">=3.0.10"
}


def extract_package_info(filename):
    """Extract package name and version from filename"""
    # Remove extensions
    base = filename.replace('.tar.gz', '').replace('.zip', '').replace('.whl', '')
    
    # Try to match pattern: package-name-version
    # Handle cases like: package_name-1.2.3, package-name-1.2.3.post1
    match = re.match(r'^(.+?)-([0-9]+(?:\.[0-9]+)*(?:[a-zA-Z0-9._-]*))$', base)
    if match:
        return match.group(1), match.group(2)
    
    # Fallback: split on last dash
    parts = base.rsplit('-', 1)
    if len(parts) == 2:
        return parts[0], parts[1]
    
    return base, None


def discover_dependencies(target_package, python_version, download_dir, output_file, utils_dir):
    """Main discovery function"""
    packages_data = []
    processed_packages = set()
    
    download_path = Path(download_dir)
    if not download_path.exists():
        download_path.mkdir(parents=True, exist_ok=True)
    
    print(f"Downloading {target_package} and dependencies...", file=sys.stderr)
    
    # Download package and dependencies
    try:
        subprocess.run(
            ["pip", "download", target_package, "--dest", str(download_dir), "--no-cache-dir"],
            check=True,
            capture_output=True,
            timeout=600
        )
    except subprocess.CalledProcessError as e:
        print(f"Warning: pip download had issues: {e}", file=sys.stderr)
    
    # Process all downloaded files
    for file in download_path.iterdir():
        if not file.is_file():
            continue
        
        filename = file.name
        if not (filename.endswith('.tar.gz') or filename.endswith('.zip') or filename.endswith('.whl')):
            continue
        
        pkg_name, pkg_version = extract_package_info(filename)
        
        if not pkg_name or pkg_name in processed_packages:
            continue
        
        processed_packages.add(pkg_name)
        
        print(f"Processing: {pkg_name} {pkg_version or 'unknown'}", file=sys.stderr)
        
        # Get version constraint
        constraint = VERSION_CONSTRAINTS.get(pkg_name, "")
        if pkg_version and not constraint:
            constraint = f"=={pkg_version}"
        
        # Check wheel availability
        wheels = check_wheel_availability(pkg_name, pkg_version, python_version)
        
        # Get requirements
        requirements = get_package_requirements(pkg_name)
        
        # Get system requirements
        system_reqs = SYSTEM_PACKAGES.get(pkg_name, [])
        
        # Get special fixes
        fixes = SPECIAL_FIXES.get(pkg_name, [])
        
        package_data = {
            "name": pkg_name,
            "version": pkg_version or "unknown",
            "constraint": constraint,
            "wheels": wheels,
            "requirements": requirements,
            "build_requirements": {
                "system": system_reqs,
                "python": []
            },
            "build_order": 0,  # Will be calculated later
            "special_fixes": fixes
        }
        
        packages_data.append(package_data)
    
    # Calculate build order (simple approach: packages with no deps first)
    build_order = 1
    for pkg in packages_data:
        if not pkg["requirements"]:
            pkg["build_order"] = build_order
            build_order += 1
    
    # Assign order to remaining packages
    for pkg in packages_data:
        if pkg["build_order"] == 0:
            pkg["build_order"] = build_order
            build_order += 1
    
    # System packages info
    system_packages_data = [
        {
            "name": "libarrow-cpp",
            "version": "22.0.0",
            "available_in_termux": True,
            "needs_build": False
        },
        {
            "name": "libjpeg-turbo",
            "version": "latest",
            "available_in_termux": True,
            "needs_build": False
        }
    ]
    
    # Build final manifest
    manifest = {
        "target": target_package,
        "python_version": python_version,
        "architectures": ["aarch64", "x86_64"],
        "generated_at": datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ"),
        "packages": packages_data,
        "system_packages": system_packages_data
    }
    
    # Write manifest
    with open(output_file, "w") as f:
        json.dump(manifest, f, indent=2)
    
    print(f"Manifest written to {output_file}", file=sys.stderr)
    print(f"Total packages: {len(packages_data)}", file=sys.stderr)
    
    return manifest


def main():
    parser = argparse.ArgumentParser(description="Discover all dependencies for a package")
    parser.add_argument("--target", default="droidrun[google]", help="Target package")
    parser.add_argument("--python-version", default="3.12", help="Python version")
    parser.add_argument("--download-dir", required=True, help="Download directory")
    parser.add_argument("--output", required=True, help="Output manifest file")
    parser.add_argument("--utils-dir", help="Utils directory (for imports)")
    
    args = parser.parse_args()
    
    discover_dependencies(
        args.target,
        args.python_version,
        args.download_dir,
        args.output,
        args.utils_dir or os.path.dirname(__file__)
    )


if __name__ == "__main__":
    main()



