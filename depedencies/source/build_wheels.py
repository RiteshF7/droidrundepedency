#!/usr/bin/env python3
"""
Build wheel files from all source packages in the current directory.
Builds packages in the correct dependency order.

This script handles Termux-specific build requirements from DEPENDENCIES.md:
- Sets up build environment variables (PREFIX, CMAKE, compiler paths, etc.)
- Applies fixes for pandas (meson.build version)
- Applies fixes for scikit-learn (version.py shebang, meson.build)
- Patches grpcio wheel post-build (adds abseil libraries, sets RPATH)
- Sets package-specific environment variables (pyarrow, pillow, grpcio)
- Configures LD_LIBRARY_PATH for grpcio runtime

Usage:
    python3 build_wheels.py [--source-dir DIR] [--wheels-dir DIR]
"""

import os
import sys
import re
import subprocess
import shutil
import tarfile
import zipfile
import tempfile
from pathlib import Path
from typing import Dict, List, Set, Optional, Tuple
from collections import defaultdict, deque

# Known Python package dependencies (from config.sh)
PYTHON_TRANSITIVE_DEPS = {
    "scipy": ["numpy"],
    "pandas": ["numpy"],
    "scikit-learn": ["numpy", "scipy"],
    "scikit_learn": ["numpy", "scipy"],  # Alternative name
    "pyarrow": ["numpy"],
}

# Build tools that should be installed first
BUILD_TOOLS = ["Cython", "meson-python", "maturin"]

# Package name normalization (handle variations)
NAME_NORMALIZATIONS = {
    "scikit-learn": "scikit_learn",
    "scikit_learn": "scikit-learn",
    "pydantic-core": "pydantic_core",
    "pydantic_core": "pydantic-core",
}


class WheelBuilder:
    def __init__(self, source_dir: str, wheels_dir: str = None):
        self.source_dir = Path(source_dir).resolve()
        if wheels_dir:
            self.wheels_dir = Path(wheels_dir).resolve()
        else:
            # Default to ~/wheels or ./wheels
            home_wheels = Path.home() / "wheels"
            local_wheels = self.source_dir.parent / "wheels"
            self.wheels_dir = home_wheels if home_wheels.exists() else local_wheels
        
        self.wheels_dir.mkdir(parents=True, exist_ok=True)
        self.temp_dir = Path(tempfile.mkdtemp(prefix="wheel_build_"))
        self.built_packages: Set[str] = set()
        self.failed_packages: Set[str] = set()
        self.package_info: Dict[str, dict] = {}
        
        # Setup build environment for Termux
        self.setup_build_environment()
        
        print(f"Source directory: {self.source_dir}")
        print(f"Wheels directory: {self.wheels_dir}")
        print(f"Temp directory: {self.temp_dir}")
    
    def setup_build_environment(self):
        """Setup build environment variables for Termux (from DEPENDENCIES.md)."""
        # Set PREFIX if not already set (Termux default)
        prefix = os.environ.get('PREFIX', '/data/data/com.termux/files/usr')
        os.environ['PREFIX'] = prefix
        
        # Build parallelization (limit to 2 jobs to avoid memory issues)
        os.environ['NINJAFLAGS'] = '-j2'
        os.environ['MAKEFLAGS'] = '-j2'
        os.environ['MAX_JOBS'] = '2'
        
        # CMAKE configuration (required for patchelf and other CMake-based builds)
        os.environ['CMAKE_PREFIX_PATH'] = prefix
        os.environ['CMAKE_INCLUDE_PATH'] = f'{prefix}/include'
        
        # Compiler environment variables
        os.environ['CC'] = f'{prefix}/bin/clang'
        os.environ['CXX'] = f'{prefix}/bin/clang++'
        
        # Temporary directory (fixes compiler permission issues)
        tmpdir = Path.home() / 'tmp'
        tmpdir.mkdir(exist_ok=True)
        os.environ['TMPDIR'] = str(tmpdir)
        
        print("✓ Build environment variables configured for Termux")
    
    def extract_package_info(self, filename: str) -> Tuple[Optional[str], Optional[str]]:
        """Extract package name and version from filename."""
        # Remove extensions
        base = filename.replace('.tar.gz', '').replace('.zip', '').replace('-fixed', '')
        
        # Handle special cases
        if 'scikit' in base.lower() and 'fixed' in filename.lower():
            # scikit_fixed.tar.gz -> scikit-learn
            return "scikit-learn", None
        
        # Handle pandas-fixed
        if 'pandas' in base.lower() and 'fixed' in filename.lower():
            # Extract version from filename if present
            match = re.search(r'pandas[_-]?(\d+\.\d+\.\d+)', base, re.IGNORECASE)
            if match:
                return "pandas", match.group(1)
            return "pandas", None
        
        # Try to match pattern: package-name-version
        # Handle cases like: package_name-1.2.3, package-name-1.2.3.post1
        match = re.match(r'^(.+?)-([0-9]+(?:\.[0-9]+)*(?:[a-zA-Z0-9._-]*))$', base)
        if match:
            name = match.group(1)
            version = match.group(2)
            # Normalize name
            name = name.replace('_', '-')
            return name, version
        
        # Fallback: split on last dash
        parts = base.rsplit('-', 1)
        if len(parts) == 2 and re.match(r'^[0-9]', parts[1]):
            return parts[0].replace('_', '-'), parts[1]
        
        return base.replace('_', '-'), None
    
    def scan_source_files(self) -> Dict[str, Path]:
        """Scan source directory for all package files."""
        packages = {}
        
        # Files to skip (archives, not actual packages)
        skip_files = {
            'home_sources.tar.gz', 'sources.tar.gz', 'source.7z',
            'test_binary__multipart_extension.snap.tar.gz'
        }
        
        if not self.source_dir.exists():
            print(f"ERROR: Source directory does not exist: {self.source_dir}")
            return packages
        
        for file_path in self.source_dir.iterdir():
            if not file_path.is_file():
                continue
            
            # Skip archive files
            if file_path.name in skip_files:
                print(f"  Skipping archive file: {file_path.name}")
                continue
            
            if file_path.suffix in ['.gz', '.zip'] or file_path.name.endswith('.tar.gz'):
                name, version = self.extract_package_info(file_path.name)
                if name:
                    # Normalize name
                    normalized_name = NAME_NORMALIZATIONS.get(name, name)
                    key = normalized_name.lower()
                    
                    # Prefer versioned packages, and if both have versions, prefer newer
                    if key not in packages:
                        packages[key] = {
                            'name': normalized_name,
                            'version': version,
                            'path': file_path,
                            'filename': file_path.name
                        }
                    elif version:
                        # Compare versions if both have them
                        existing_version = packages[key].get('version')
                        if not existing_version:
                            # Replace unversioned with versioned
                            packages[key] = {
                                'name': normalized_name,
                                'version': version,
                                'path': file_path,
                                'filename': file_path.name
                            }
                        else:
                            # Compare versions - prefer newer version
                            # Simple comparison: split by dots and compare numerically
                            try:
                                v1_parts = [int(x) for x in version.split('.')]
                                v2_parts = [int(x) for x in existing_version.split('.')]
                                # Pad to same length
                                max_len = max(len(v1_parts), len(v2_parts))
                                v1_parts.extend([0] * (max_len - len(v1_parts)))
                                v2_parts.extend([0] * (max_len - len(v2_parts)))
                                # Compare
                                if v1_parts > v2_parts:
                                    packages[key] = {
                                        'name': normalized_name,
                                        'version': version,
                                        'path': file_path,
                                        'filename': file_path.name
                                    }
                            except:
                                # Fallback: prefer longer version string (usually newer)
                                if len(version) >= len(existing_version):
                                    packages[key] = {
                                        'name': normalized_name,
                                        'version': version,
                                        'path': file_path,
                                        'filename': file_path.name
                                    }
        
        return packages
    
    def normalize_package_name(self, name: str) -> str:
        """Normalize package name for comparison."""
        name = name.lower().replace('_', '-')
        return NAME_NORMALIZATIONS.get(name, name)
    
    def build_dependency_graph(self, packages: Dict[str, dict]) -> Dict[str, List[str]]:
        """Build dependency graph from packages."""
        graph = defaultdict(list)
        package_names = {pkg['name'].lower() for pkg in packages.values()}
        
        for pkg_key, pkg_info in packages.items():
            pkg_name = pkg_info['name'].lower()
            # Check if this package has known dependencies
            deps = PYTHON_TRANSITIVE_DEPS.get(pkg_name, [])
            deps.extend(PYTHON_TRANSITIVE_DEPS.get(pkg_info['name'], []))
            
            for dep in deps:
                dep_normalized = self.normalize_package_name(dep)
                # Only add dependency if the package exists in our source files
                if dep_normalized.lower() in package_names:
                    graph[pkg_name].append(dep_normalized.lower())
        
        return dict(graph)
    
    def topological_sort(self, packages: Dict[str, dict], graph: Dict[str, List[str]]) -> List[str]:
        """Topologically sort packages by dependencies."""
        # Build reverse graph and in-degree count
        in_degree = defaultdict(int)
        reverse_graph = defaultdict(list)
        
        all_packages = {pkg['name'].lower() for pkg in packages.values()}
        
        for pkg in all_packages:
            in_degree[pkg] = 0
        
        for pkg, deps in graph.items():
            for dep in deps:
                if dep in all_packages:
                    in_degree[pkg] += 1
                    reverse_graph[dep].append(pkg)
        
        # Kahn's algorithm
        queue = deque([pkg for pkg in all_packages if in_degree[pkg] == 0])
        result = []
        
        while queue:
            # Sort queue to prioritize build tools
            queue_list = list(queue)
            queue_list.sort(key=lambda x: (
                0 if x in [t.lower() for t in BUILD_TOOLS] else 1,
                x
            ))
            queue = deque(queue_list)
            
            pkg = queue.popleft()
            result.append(pkg)
            
            for dependent in reverse_graph.get(pkg, []):
                in_degree[dependent] -= 1
                if in_degree[dependent] == 0:
                    queue.append(dependent)
        
        # Check for cycles
        if len(result) != len(all_packages):
            remaining = all_packages - set(result)
            print(f"WARNING: Possible circular dependencies or missing dependencies: {remaining}")
            # Add remaining packages at the end
            result.extend(sorted(remaining))
        
        return result
    
    def check_wheel_exists(self, package_name: str, version: str = None) -> bool:
        """Check if wheel already exists."""
        pattern = f"{package_name.replace('-', '_')}-*"
        if version:
            pattern = f"{package_name.replace('-', '_')}-{version}*"
        
        for wheel_file in self.wheels_dir.glob(f"{pattern}.whl"):
            return True
        return False
    
    def apply_pandas_fix(self, extract_dir: Path) -> bool:
        """Apply pandas meson.build fix (from DEPENDENCIES.md)."""
        # Find meson.build (might be in root or nested)
        meson_build = None
        for path in extract_dir.rglob("meson.build"):
            meson_build = path
            break
        
        if not meson_build or not meson_build.exists():
            return False
        
        try:
            with open(meson_build, 'r') as f:
                lines = f.readlines()
            
            # Fix line 5 (index 4) - replace version line
            # Replace: version: run_command(['generate_version.py', '--print'], ...)
            # With: version: '2.2.3',
            if len(lines) > 4:
                # Try to extract version from filename or use default
                version = '2.2.3'  # Default pandas version
                # Look for version in the line
                original_line = lines[4]
                if 'run_command' in original_line:
                    lines[4] = f"    version: '{version}',\n"
                    with open(meson_build, 'w') as f:
                        f.writelines(lines)
                    print(f"  ✓ Applied pandas meson.build fix (line 5: version: '{version}')")
                    return True
        except Exception as e:
            print(f"  ✗ Failed to apply pandas fix: {e}")
        
        return False
    
    def apply_scikit_learn_fix(self, extract_dir: Path) -> bool:
        """Apply scikit-learn fixes (from DEPENDENCIES.md)."""
        fixed = False
        
        # Find version.py (might be in different locations)
        version_py = None
        for path in extract_dir.rglob("version.py"):
            if "_build_utils" in str(path):
                version_py = path
                break
        
        # Fix version.py: add shebang
        if version_py and version_py.exists():
            try:
                with open(version_py, 'r') as f:
                    content = f.read()
                
                # Add shebang if missing
                if not content.startswith('#!/'):
                    content = '#!/usr/bin/env python3\n' + content
                    with open(version_py, 'w') as f:
                        f.write(content)
                    os.chmod(version_py, 0o755)
                    print(f"  ✓ Fixed scikit-learn version.py (added shebang)")
                    fixed = True
            except Exception as e:
                print(f"  ✗ Failed to fix version.py: {e}")
        
        # Find and fix meson.build
        meson_build = None
        for path in extract_dir.rglob("meson.build"):
            meson_build = path
            break
        
        if meson_build and meson_build.exists():
            try:
                with open(meson_build, 'r') as f:
                    lines = f.readlines()
                
                # Try to get version from version.py
                version = "1.9.dev0"
                if version_py and version_py.exists():
                    try:
                        result = subprocess.run(
                            [sys.executable, str(version_py)],
                            capture_output=True,
                            text=True,
                            timeout=10,
                            cwd=str(extract_dir)
                        )
                        if result.returncode == 0:
                            version = result.stdout.strip()
                    except:
                        pass
                
                # Fix line 4 (index 3) - hardcode version
                if len(lines) > 3:
                    lines[3] = f"  version: '{version}',\n"
                    with open(meson_build, 'w') as f:
                        f.writelines(lines)
                    print(f"  ✓ Fixed scikit-learn meson.build (line 4: version: '{version}')")
                    fixed = True
            except Exception as e:
                print(f"  ✗ Failed to fix meson.build: {e}")
        
        return fixed
    
    def patch_grpcio_wheel(self, wheel_file: Path) -> bool:
        """Patch grpcio wheel to add abseil library dependencies (from DEPENDENCIES.md)."""
        print(f"  Patching grpcio wheel: {wheel_file.name}")
        
        # Check if patchelf is available
        try:
            subprocess.run(['patchelf', '--version'], capture_output=True, check=True)
        except (subprocess.CalledProcessError, FileNotFoundError):
            print(f"  ⚠ patchelf not found. Install with: pkg install -y patchelf")
            return False
        
        prefix = os.environ.get('PREFIX', '/data/data/com.termux/files/usr')
        extract_dir = self.temp_dir / f"grpcio_patch_{wheel_file.stem}"
        extract_dir.mkdir(exist_ok=True)
        
        try:
            # Extract wheel
            with zipfile.ZipFile(wheel_file, 'r') as zip_ref:
                zip_ref.extractall(extract_dir)
            
            # Find the .so file
            so_files = list(extract_dir.rglob("cygrpc*.so"))
            if not so_files:
                print(f"  ✗ cygrpc*.so not found in wheel")
                return False
            
            so_file = so_files[0]
            print(f"  Found .so file: {so_file.relative_to(extract_dir)}")
            
            # Patch with patchelf
            abseil_libs = [
                'libabsl_flags_internal.so',
                'libabsl_flags.so',
                'libabsl_flags_commandlineflag.so',
                'libabsl_flags_reflection.so'
            ]
            
            for lib in abseil_libs:
                try:
                    subprocess.run(
                        ['patchelf', '--add-needed', lib, str(so_file)],
                        check=True,
                        capture_output=True
                    )
                except subprocess.CalledProcessError as e:
                    print(f"  ⚠ Failed to add {lib}: {e.stderr.decode() if e.stderr else 'unknown error'}")
            
            # Set RPATH
            try:
                subprocess.run(
                    ['patchelf', '--set-rpath', f'{prefix}/lib', str(so_file)],
                    check=True,
                    capture_output=True
                )
            except subprocess.CalledProcessError as e:
                print(f"  ⚠ Failed to set RPATH: {e.stderr.decode() if e.stderr else 'unknown error'}")
            
            # Repackage wheel
            fixed_wheel = wheel_file.parent / f"{wheel_file.stem}_fixed.whl"
            with zipfile.ZipFile(fixed_wheel, 'w', zipfile.ZIP_DEFLATED) as zf:
                for root, dirs, files in os.walk(extract_dir):
                    for file in files:
                        filepath = Path(root) / file
                        arcname = filepath.relative_to(extract_dir)
                        zf.write(filepath, arcname)
            
            # Replace original wheel
            wheel_file.unlink()
            fixed_wheel.rename(wheel_file)
            
            print(f"  ✓ Patched grpcio wheel successfully")
            
            # Set LD_LIBRARY_PATH (add to ~/.bashrc for permanent fix)
            bashrc = Path.home() / '.bashrc'
            ld_library_path_line = f'export LD_LIBRARY_PATH=$PREFIX/lib:$LD_LIBRARY_PATH'
            
            if bashrc.exists():
                with open(bashrc, 'r') as f:
                    content = f.read()
                if 'LD_LIBRARY_PATH' not in content or 'PREFIX/lib' not in content:
                    with open(bashrc, 'a') as f:
                        f.write(f'\n{ld_library_path_line}\n')
                    print(f"  ✓ Added LD_LIBRARY_PATH to ~/.bashrc")
            else:
                with open(bashrc, 'w') as f:
                    f.write(f'{ld_library_path_line}\n')
                print(f"  ✓ Created ~/.bashrc with LD_LIBRARY_PATH")
            
            # Set for current session
            os.environ['LD_LIBRARY_PATH'] = f'{prefix}/lib:{os.environ.get("LD_LIBRARY_PATH", "")}'
            
            return True
            
        except Exception as e:
            print(f"  ✗ Failed to patch grpcio wheel: {e}")
            import traceback
            traceback.print_exc()
            return False
        finally:
            # Cleanup
            if extract_dir.exists():
                shutil.rmtree(extract_dir, ignore_errors=True)
    
    def extract_source(self, source_file: Path, extract_dir: Path) -> bool:
        """Extract source file to directory."""
        try:
            if source_file.suffix == '.gz' or source_file.name.endswith('.tar.gz'):
                with tarfile.open(source_file, 'r:gz') as tar:
                    tar.extractall(extract_dir)
            elif source_file.suffix == '.zip':
                with zipfile.ZipFile(source_file, 'r') as zip_ref:
                    zip_ref.extractall(extract_dir)
            else:
                print(f"  ✗ Unknown file format: {source_file}")
                return False
            
            return True
        except Exception as e:
            print(f"  ✗ Failed to extract {source_file}: {e}")
            return False
    
    def build_wheel(self, package_name: str, package_info: dict) -> bool:
        """Build wheel for a package."""
        source_file = package_info['path']
        version = package_info.get('version')
        
        print(f"\n{'='*60}")
        print(f"Building: {package_name} {version or ''}")
        print(f"Source: {source_file.name}")
        print(f"{'='*60}")
        
        # Check if wheel already exists
        if self.check_wheel_exists(package_name, version):
            print(f"  ✓ Wheel already exists, skipping")
            self.built_packages.add(package_name.lower())
            return True
        
        # Extract source
        extract_dir = self.temp_dir / f"{package_name}_extract"
        extract_dir.mkdir(exist_ok=True)
        
        if not self.extract_source(source_file, extract_dir):
            return False
        
        # Find the actual package directory (might be nested)
        package_dirs = [d for d in extract_dir.iterdir() if d.is_dir()]
        if len(package_dirs) == 1:
            package_dir = package_dirs[0]
        else:
            # Look for setup.py, pyproject.toml, or meson.build
            for d in package_dirs:
                if any((d / f).exists() for f in ['setup.py', 'pyproject.toml', 'meson.build']):
                    package_dir = d
                    break
            else:
                package_dir = extract_dir
        
        # Apply fixes
        if package_name.lower() == 'pandas':
            self.apply_pandas_fix(package_dir)
        elif package_name.lower() in ['scikit-learn', 'scikit_learn']:
            # Install scikit-learn dependencies first (from DEPENDENCIES.md)
            print(f"  Installing scikit-learn dependencies (joblib, threadpoolctl)...")
            try:
                subprocess.run(
                    [sys.executable, "-m", "pip", "install", 
                     "joblib>=1.3.0", "threadpoolctl>=3.2.0"],
                    check=True,
                    capture_output=True,
                    timeout=300
                )
                print(f"  ✓ Dependencies installed")
            except Exception as e:
                print(f"  ⚠ Failed to install dependencies: {e}")
            
            self.apply_scikit_learn_fix(package_dir)
        
        # Build wheel
        build_flags = ["--no-deps", "--wheel-dir", str(self.wheels_dir)]
        
        # Special build flags
        if package_name.lower() in ['scikit-learn', 'scikit_learn', 'grpcio']:
            build_flags.append("--no-build-isolation")
        
        # Set package-specific environment variables
        env = os.environ.copy()
        prefix = os.environ.get('PREFIX', '/data/data/com.termux/files/usr')
        
        if package_name.lower() == 'grpcio':
            # GRPC build flags (from DEPENDENCIES.md)
            env.update({
                'GRPC_PYTHON_BUILD_SYSTEM_OPENSSL': '1',
                'GRPC_PYTHON_BUILD_SYSTEM_ZLIB': '1',
                'GRPC_PYTHON_BUILD_SYSTEM_CARES': '1',
                'GRPC_PYTHON_BUILD_SYSTEM_RE2': '1',
                'GRPC_PYTHON_BUILD_SYSTEM_ABSL': '1',
                'GRPC_PYTHON_BUILD_WITH_CYTHON': '1',
            })
        elif package_name.lower() == 'pyarrow':
            # pyarrow build environment (from DEPENDENCIES.md)
            env['ARROW_HOME'] = prefix
        elif package_name.lower() == 'pillow':
            # Pillow build environment (from DEPENDENCIES.md)
            env['PKG_CONFIG_PATH'] = f'{prefix}/lib/pkgconfig:{env.get("PKG_CONFIG_PATH", "")}'
            env['LDFLAGS'] = f'-L{prefix}/lib'
            env['CPPFLAGS'] = f'-I{prefix}/include'
        
        try:
            cmd = [sys.executable, "-m", "pip", "wheel", str(package_dir)] + build_flags
            print(f"  Running: {' '.join(cmd)}")
            
            result = subprocess.run(
                cmd,
                cwd=str(package_dir),
                env=env,
                capture_output=True,
                text=True,
                timeout=3600  # 1 hour timeout
            )
            
            if result.returncode != 0:
                print(f"  ✗ Build failed:")
                print(result.stderr)
                return False
            
            # Check if wheel was created
            wheels = list(self.wheels_dir.glob(f"{package_name.replace('-', '_')}-*.whl"))
            if not wheels:
                # Try with different name variations
                wheels = list(self.wheels_dir.glob(f"*{package_name.replace('-', '_')}*.whl"))
            
            if wheels:
                wheel_file = wheels[0]
                print(f"  ✓ Wheel built: {wheel_file.name}")
                
                # Apply post-build fixes for grpcio (from DEPENDENCIES.md)
                if package_name.lower() == 'grpcio':
                    if not self.patch_grpcio_wheel(wheel_file):
                        print(f"  ⚠ Failed to patch grpcio wheel, but continuing...")
                
                self.built_packages.add(package_name.lower())
                
                # Install the wheel for dependent packages
                try:
                    install_cmd = [sys.executable, "-m", "pip", "install", 
                                 "--find-links", str(self.wheels_dir), 
                                 "--no-index", str(wheel_file)]
                    subprocess.run(install_cmd, capture_output=True, timeout=300)
                except Exception as e:
                    print(f"  ⚠ Failed to install wheel (non-critical): {e}")
                
                return True
            else:
                print(f"  ✗ Wheel not found after build")
                return False
                
        except subprocess.TimeoutExpired:
            print(f"  ✗ Build timed out")
            return False
        except Exception as e:
            print(f"  ✗ Build error: {e}")
            return False
        finally:
            # Cleanup
            if extract_dir.exists():
                shutil.rmtree(extract_dir, ignore_errors=True)
    
    def install_build_tools(self):
        """Install required build tools first (Phase 1 from DEPENDENCIES.md)."""
        print("\n" + "="*60)
        print("Installing build tools (Phase 1)...")
        print("="*60)
        print("Note: Ensure system dependencies are installed:")
        print("  pkg install -y python python-pip autoconf automake libtool make binutils")
        print("  pkg install -y clang cmake ninja rust flang blas-openblas")
        print("  pkg install -y libjpeg-turbo libpng libtiff libwebp freetype")
        print("  pkg install -y libarrow-cpp openssl libc++ zlib protobuf libprotobuf")
        print("  pkg install -y abseil-cpp c-ares libre2 patchelf")
        print("="*60)
        
        tools = ["pip", "wheel", "setuptools", "Cython", 
                 "meson-python<0.19.0,>=0.16.0", "maturin<2,>=1.9.4"]
        
        for tool in tools:
            try:
                print(f"  Installing {tool}...")
                subprocess.run(
                    [sys.executable, "-m", "pip", "install", "--upgrade", tool],
                    check=True,
                    capture_output=True,
                    timeout=600
                )
                print(f"  ✓ {tool} installed")
            except Exception as e:
                print(f"  ✗ Failed to install {tool}: {e}")
    
    def build_all(self):
        """Build all packages in dependency order."""
        print("="*60)
        print("Wheel Builder - Building from Source")
        print("="*60)
        
        # Install build tools
        self.install_build_tools()
        
        # Scan source files
        print("\nScanning source files...")
        packages = self.scan_source_files()
        print(f"Found {len(packages)} packages:")
        for pkg_key, pkg_info in sorted(packages.items()):
            print(f"  - {pkg_info['name']} {pkg_info.get('version', '')}")
        
        if not packages:
            print("ERROR: No source packages found!")
            return
        
        # Build dependency graph
        print("\nBuilding dependency graph...")
        graph = self.build_dependency_graph(packages)
        print(f"Dependencies:")
        for pkg, deps in sorted(graph.items()):
            if deps:
                print(f"  {pkg} -> {', '.join(deps)}")
        
        # Topological sort
        print("\nDetermining build order...")
        build_order = self.topological_sort(packages, graph)
        print(f"Build order ({len(build_order)} packages):")
        for i, pkg in enumerate(build_order, 1):
            deps = graph.get(pkg, [])
            deps_str = f" (depends on: {', '.join(deps)})" if deps else ""
            print(f"  {i}. {pkg}{deps_str}")
        
        # Build packages
        print("\n" + "="*60)
        print("Starting builds...")
        print("="*60)
        
        for pkg_key in build_order:
            if pkg_key not in packages:
                continue
            
            pkg_info = packages[pkg_key]
            pkg_name = pkg_info['name']
            
            if pkg_name.lower() in self.built_packages:
                print(f"\nSkipping {pkg_name} (already built)")
                continue
            
            success = self.build_wheel(pkg_name, pkg_info)
            if not success:
                self.failed_packages.add(pkg_name)
                print(f"\n✗ Failed to build {pkg_name}")
            else:
                print(f"\n✓ Successfully built {pkg_name}")
        
        # Summary
        print("\n" + "="*60)
        print("Build Summary")
        print("="*60)
        print(f"Total packages: {len(packages)}")
        print(f"Successfully built: {len(self.built_packages)}")
        print(f"Failed: {len(self.failed_packages)}")
        
        if self.failed_packages:
            print(f"\nFailed packages:")
            for pkg in sorted(self.failed_packages):
                print(f"  - {pkg}")
        
        print(f"\nWheels directory: {self.wheels_dir}")
        wheel_count = len(list(self.wheels_dir.glob("*.whl")))
        print(f"Total wheels: {wheel_count}")
    
    def cleanup(self):
        """Cleanup temporary files."""
        if self.temp_dir.exists():
            shutil.rmtree(self.temp_dir, ignore_errors=True)


def main():
    import argparse
    
    parser = argparse.ArgumentParser(
        description="Build wheel files from source packages in dependency order"
    )
    parser.add_argument(
        "--source-dir",
        type=str,
        default=None,
        help="Source directory (default: current directory)"
    )
    parser.add_argument(
        "--wheels-dir",
        type=str,
        default=None,
        help="Wheels output directory (default: ~/wheels or ./wheels)"
    )
    
    args = parser.parse_args()
    
    # Use current directory if not specified
    source_dir = args.source_dir or os.getcwd()
    
    builder = WheelBuilder(source_dir, args.wheels_dir)
    
    try:
        builder.build_all()
    except KeyboardInterrupt:
        print("\n\nBuild interrupted by user")
        sys.exit(1)
    except Exception as e:
        print(f"\n\nERROR: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
    finally:
        builder.cleanup()


if __name__ == "__main__":
    main()

