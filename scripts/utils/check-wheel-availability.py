#!/usr/bin/env python3
"""
Check wheel availability for a package on PyPI for specific architectures.
Returns whether pre-built wheels are available for aarch64 and x86_64.
"""

import json
import sys
import urllib.request
import urllib.error
from packaging import version as pkg_version
from packaging.specifiers import SpecifierSet


def check_wheel_availability(package_name, package_version=None, python_version="3.12"):
    """
    Check if wheels are available for a package on PyPI.
    
    Args:
        package_name: Name of the package
        package_version: Specific version to check (optional)
        python_version: Python version (default: 3.12)
    
    Returns:
        dict with 'aarch64' and 'x86_64' keys, each containing:
        - available: bool
        - needs_build: bool (opposite of available)
        - wheel_info: dict with details if available
    """
    result = {
        "aarch64": {"available": False, "needs_build": True, "wheel_info": None},
        "x86_64": {"available": False, "needs_build": True, "wheel_info": None}
    }
    
    try:
        # Fetch package metadata from PyPI JSON API
        url = f"https://pypi.org/pypi/{package_name}/json"
        
        try:
            with urllib.request.urlopen(url, timeout=10) as response:
                data = json.loads(response.read())
        except urllib.error.HTTPError as e:
            if e.code == 404:
                print(f"Package {package_name} not found on PyPI", file=sys.stderr)
                return result
            raise
        
        # Get releases
        releases = data.get("releases", {})
        
        # If specific version requested, check only that version
        if package_version:
            versions_to_check = [package_version] if package_version in releases else []
        else:
            # Get all versions, sorted
            versions_to_check = sorted(releases.keys(), key=pkg_version.parse, reverse=True)
        
        # Check each version for wheels
        for ver in versions_to_check:
            files = releases.get(ver, [])
            
            for file_info in files:
                if not file_info.get("packagetype") == "bdist_wheel":
                    continue
                
                filename = file_info.get("filename", "")
                url = file_info.get("url", "")
                
                # Check architecture tags in filename
                # Format: package-version-py3-none-linux_aarch64.whl
                # or: package-version-cp312-cp312-linux_aarch64.whl
                
                if "linux_aarch64" in filename or "manylinux_aarch64" in filename:
                    if not result["aarch64"]["available"]:
                        result["aarch64"]["available"] = True
                        result["aarch64"]["needs_build"] = False
                        result["aarch64"]["wheel_info"] = {
                            "version": ver,
                            "filename": filename,
                            "url": url
                        }
                
                if "linux_x86_64" in filename or "manylinux_x86_64" in filename or "linux_x86_64" in filename:
                    if not result["x86_64"]["available"]:
                        result["x86_64"]["available"] = True
                        result["x86_64"]["needs_build"] = False
                        result["x86_64"]["wheel_info"] = {
                            "version": ver,
                            "filename": filename,
                            "url": url
                        }
                
                # Also check for universal wheels (py3-none-any.whl)
                if "py3-none-any" in filename or "any" in filename.lower():
                    # Universal wheels work on all architectures
                    if not result["aarch64"]["available"]:
                        result["aarch64"]["available"] = True
                        result["aarch64"]["needs_build"] = False
                        result["aarch64"]["wheel_info"] = {
                            "version": ver,
                            "filename": filename,
                            "url": url,
                            "universal": True
                        }
                    if not result["x86_64"]["available"]:
                        result["x86_64"]["available"] = True
                        result["x86_64"]["needs_build"] = False
                        result["x86_64"]["wheel_info"] = {
                            "version": ver,
                            "filename": filename,
                            "url": url,
                            "universal": True
                        }
        
        return result
    
    except Exception as e:
        print(f"Error checking {package_name}: {e}", file=sys.stderr)
        return result


def main():
    if len(sys.argv) < 2:
        print("Usage: check-wheel-availability.py <package-name> [version] [python-version]")
        sys.exit(1)
    
    package_name = sys.argv[1]
    package_version = sys.argv[2] if len(sys.argv) > 2 else None
    python_version = sys.argv[3] if len(sys.argv) > 3 else "3.12"
    
    result = check_wheel_availability(package_name, package_version, python_version)
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()

