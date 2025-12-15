#!/usr/bin/env python3
"""
Parse Python package dependencies from pip download output and METADATA files.
Extracts all transitive dependencies with version constraints.
"""

import json
import sys
import subprocess
import tempfile
import os
import tarfile
import zipfile
from pathlib import Path
from packaging.requirements import Requirement


def parse_metadata_file(metadata_path):
    """
    Parse METADATA file to extract dependencies.
    
    Returns:
        list of Requirement objects
    """
    requirements = []
    
    try:
        with open(metadata_path, 'r', encoding='utf-8') as f:
            in_requires = False
            current_requirement = ""
            
            for line in f:
                line = line.strip()
                
                if line.startswith("Requires-Dist:"):
                    req_str = line.replace("Requires-Dist:", "").strip()
                    # Handle multi-line requirements
                    if req_str.endswith("\\"):
                        current_requirement = req_str[:-1].strip()
                        in_requires = True
                    else:
                        if in_requires:
                            req_str = current_requirement + " " + req_str
                            current_requirement = ""
                            in_requires = False
                        try:
                            req = Requirement(req_str)
                            requirements.append(req)
                        except Exception as e:
                            print(f"Warning: Could not parse requirement '{req_str}': {e}", file=sys.stderr)
                
                elif in_requires:
                    if line.endswith("\\"):
                        current_requirement += " " + line[:-1].strip()
                    else:
                        current_requirement += " " + line
                        in_requires = False
                        try:
                            req = Requirement(current_requirement)
                            requirements.append(req)
                        except Exception as e:
                            print(f"Warning: Could not parse requirement '{current_requirement}': {e}", file=sys.stderr)
                        current_requirement = ""
    
    except Exception as e:
        print(f"Error parsing metadata file {metadata_path}: {e}", file=sys.stderr)
    
    return requirements


def extract_metadata_from_sdist(sdist_path):
    """
    Extract METADATA from source distribution (tar.gz or zip).
    
    Returns:
        list of Requirement objects
    """
    requirements = []
    temp_dir = tempfile.mkdtemp()
    
    try:
        if sdist_path.endswith('.tar.gz') or sdist_path.endswith('.tar'):
            with tarfile.open(sdist_path, 'r:*') as tar:
                tar.extractall(temp_dir)
        elif sdist_path.endswith('.zip'):
            with zipfile.ZipFile(sdist_path, 'r') as zipf:
                zipf.extractall(temp_dir)
        else:
            return requirements
        
        # Find METADATA file (usually in .dist-info or PKG-INFO)
        for root, dirs, files in os.walk(temp_dir):
            if 'METADATA' in files:
                metadata_path = os.path.join(root, 'METADATA')
                requirements = parse_metadata_file(metadata_path)
                break
            elif 'PKG-INFO' in files:
                # PKG-INFO is similar to METADATA
                metadata_path = os.path.join(root, 'PKG-INFO')
                requirements = parse_metadata_file(metadata_path)
                break
        
        # Also check for setup.py or pyproject.toml
        setup_py = os.path.join(temp_dir, os.listdir(temp_dir)[0] if os.listdir(temp_dir) else "", "setup.py")
        if os.path.exists(setup_py):
            # Try to extract requirements from setup.py (basic parsing)
            pass  # Could add setup.py parsing here if needed
    
    except Exception as e:
        print(f"Error extracting metadata from {sdist_path}: {e}", file=sys.stderr)
    finally:
        # Cleanup
        import shutil
        shutil.rmtree(temp_dir, ignore_errors=True)
    
    return requirements


def get_all_dependencies(package_spec, download_dir=None):
    """
    Get all transitive dependencies for a package.
    
    Args:
        package_spec: Package specification (e.g., "droidrun[google]")
        download_dir: Directory to download packages to
    
    Returns:
        dict mapping package names to their requirements
    """
    if download_dir is None:
        download_dir = tempfile.mkdtemp()
    else:
        os.makedirs(download_dir, exist_ok=True)
    
    dependencies = {}
    processed = set()
    
    def process_package(pkg_spec):
        if pkg_spec in processed:
            return
        
        processed.add(pkg_spec)
        
        # Download package
        try:
            result = subprocess.run(
                ["pip", "download", "--no-deps", "--dest", download_dir, pkg_spec],
                capture_output=True,
                text=True,
                timeout=300
            )
            
            if result.returncode != 0:
                print(f"Warning: Failed to download {pkg_spec}: {result.stderr}", file=sys.stderr)
                return
            
            # Find downloaded file
            files = list(Path(download_dir).glob(f"{pkg_spec.split('[')[0].split('==')[0].split('>=')[0].split('<=')[0].split('>')[0].split('<')[0]}*"))
            
            if not files:
                # Try to find any matching file
                files = list(Path(download_dir).glob("*"))
            
            for file_path in files:
                if file_path.suffix in ['.tar.gz', '.zip', '.whl']:
                    # Extract package name from filename
                    pkg_name = pkg_spec.split('[')[0].split('==')[0].split('>=')[0].split('<=')[0].split('>')[0].split('<')[0].strip()
                    
                    if file_path.suffix == '.whl':
                        # For wheels, try to get metadata differently
                        continue
                    
                    # Extract metadata
                    reqs = extract_metadata_from_sdist(str(file_path))
                    
                    if pkg_name not in dependencies:
                        dependencies[pkg_name] = {
                            "name": pkg_name,
                            "spec": pkg_spec,
                            "requirements": []
                        }
                    
                    for req in reqs:
                        req_str = str(req)
                        if req_str not in dependencies[pkg_name]["requirements"]:
                            dependencies[pkg_name]["requirements"].append(req_str)
                            # Recursively process dependencies
                            dep_name = req.name
                            if dep_name not in processed:
                                process_package(dep_name)
        
        except Exception as e:
            print(f"Error processing {pkg_spec}: {e}", file=sys.stderr)
    
    # Start with the main package
    process_package(package_spec)
    
    return dependencies


def main():
    if len(sys.argv) < 2:
        print("Usage: dependency-parser.py <package-spec> [download-dir]")
        print("Example: dependency-parser.py 'droidrun[google]' ./downloads")
        sys.exit(1)
    
    package_spec = sys.argv[1]
    download_dir = sys.argv[2] if len(sys.argv) > 2 else None
    
    print(f"Discovering dependencies for {package_spec}...", file=sys.stderr)
    dependencies = get_all_dependencies(package_spec, download_dir)
    
    print(json.dumps(dependencies, indent=2))


if __name__ == "__main__":
    main()



