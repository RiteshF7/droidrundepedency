#!/usr/bin/env python3
"""
DroidRun Dependency Builder

Downloads source archives from GitHub releases and extracts them to Termux localsource directory.
"""

import argparse
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Optional

try:
    import requests
except ImportError:
    print("Error: 'requests' library is required. Install it with: pip install requests")
    sys.exit(1)

try:
    import py7zr
except ImportError:
    py7zr = None
    print("Warning: 'py7zr' library not found. 7z extraction will use system command.")


def check_adb_available() -> bool:
    """Check if ADB is available and device is connected."""
    try:
        result = subprocess.run(
            ["adb", "devices"],
            capture_output=True,
            text=True,
            timeout=5
        )
        if result.returncode == 0:
            # Check if any device is connected (not just "List of devices")
            lines = result.stdout.strip().split('\n')
            devices = [line for line in lines if 'device' in line and 'List' not in line]
            return len(devices) > 0
        return False
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return False


def get_latest_release_tag(repo: str) -> str:
    """Get the latest release tag from GitHub."""
    url = f"https://api.github.com/repos/{repo}/releases/latest"
    try:
        response = requests.get(url, timeout=10)
        response.raise_for_status()
        data = response.json()
        return data["tag_name"]
    except requests.RequestException as e:
        raise Exception(f"Failed to get latest release tag: {e}")


def download_archive(repo: str, release_tag: str, archive_name: str, output_path: Path) -> Path:
    """Download archive from GitHub release."""
    url = f"https://github.com/{repo}/releases/download/{release_tag}/{archive_name}"
    
    print(f"Downloading from: {url}")
    print(f"Saving to: {output_path}")
    
    try:
        response = requests.get(url, stream=True, timeout=30)
        response.raise_for_status()
        
        total_size = int(response.headers.get('content-length', 0))
        downloaded = 0
        
        with open(output_path, 'wb') as f:
            for chunk in response.iter_content(chunk_size=8192):
                if chunk:
                    f.write(chunk)
                    downloaded += len(chunk)
                    if total_size > 0:
                        percent = (downloaded / total_size) * 100
                        print(f"\rProgress: {percent:.1f}% ({downloaded}/{total_size} bytes)", end='', flush=True)
        
        print()  # New line after progress
        print(f"✓ Downloaded archive: {output_path.stat().st_size / (1024*1024):.2f} MB")
        return output_path
        
    except requests.RequestException as e:
        if output_path.exists():
            output_path.unlink()
        raise Exception(f"Failed to download archive: {e}")


def extract_archive(archive_path: Path, extract_dir: Path) -> Path:
    """Extract archive to directory."""
    print(f"Extracting {archive_path.name} to {extract_dir}...")
    
    extract_dir.mkdir(parents=True, exist_ok=True)
    
    archive_ext = archive_path.suffix.lower()
    
    if archive_ext == '.zip':
        import zipfile
        with zipfile.ZipFile(archive_path, 'r') as zip_ref:
            zip_ref.extractall(extract_dir)
    
    elif archive_ext in ['.tar.gz', '.tgz']:
        import tarfile
        with tarfile.open(archive_path, 'r:gz') as tar_ref:
            tar_ref.extractall(extract_dir)
    
    elif archive_ext == '.7z':
        if py7zr:
            with py7zr.SevenZipFile(archive_path, mode='r') as archive:
                archive.extractall(extract_dir)
        else:
            # Fallback to system 7z command
            result = subprocess.run(
                ['7z', 'x', str(archive_path), f'-o{extract_dir}', '-y'],
                capture_output=True,
                text=True
            )
            if result.returncode != 0:
                raise Exception(f"Failed to extract 7z archive: {result.stderr}")
    
    elif archive_ext == '.tar':
        import tarfile
        with tarfile.open(archive_path, 'r') as tar_ref:
            tar_ref.extractall(extract_dir)
    
    else:
        raise Exception(f"Unsupported archive format: {archive_ext}")
    
    print(f"✓ Extracted archive to {extract_dir}")
    return extract_dir


def copy_to_termux(source_dir: Path, termux_home: str, localsource_dir: str = "localsource") -> None:
    """Copy extracted files to Termux localsource directory."""
    termux_path = f"{termux_home}/{localsource_dir}"
    
    print(f"Copying files to Termux: {termux_path}")
    
    # Check if ADB is available
    if not check_adb_available():
        raise Exception("ADB is not available or no device is connected")
    
    # Create localsource directory on device
    print(f"Creating directory on device: {termux_path}")
    result = subprocess.run(
        ["adb", "shell", "run-as", "com.termux", "sh", "-c", f"mkdir -p '{termux_path}'"],
        capture_output=True,
        text=True
    )
    if result.returncode != 0:
        raise Exception(f"Failed to create directory on device: {result.stderr}")
    
    # Collect all files first
    files_to_copy = [f for f in source_dir.rglob('*') if f.is_file()]
    total_files = len(files_to_copy)
    
    if total_files == 0:
        print("No files found to copy")
        return
    
    print(f"Found {total_files} files to copy\n")
    
    # Copy each file
    copied = 0
    failed = 0
    
    for idx, file_path in enumerate(files_to_copy, 1):
        relative_path = file_path.relative_to(source_dir)
        filename = file_path.name
        display_path = str(relative_path) if str(relative_path) != filename else filename
        
        print(f"[{idx}/{total_files}] Copying {display_path}...", end=' ', flush=True)
        
        # Use temp file on device with unique name to avoid conflicts
        import hashlib
        file_hash = hashlib.md5(str(relative_path).encode()).hexdigest()[:8]
        temp_path = f"{termux_home}/tmp_{file_hash}_{filename}"
        
        # Push file to temp location
        push_result = subprocess.run(
            ["adb", "push", str(file_path), temp_path],
            capture_output=True,
            text=True
        )
        
        if push_result.returncode == 0:
            # Move to final location
            target_path = f"{termux_path}/{relative_path}".replace('\\', '/')  # Normalize path separators
            target_dir = str(Path(target_path).parent).replace('\\', '/')
            
            # Escape single quotes in paths for shell
            target_path_escaped = target_path.replace("'", "'\"'\"'")
            target_dir_escaped = target_dir.replace("'", "'\"'\"'")
            temp_path_escaped = temp_path.replace("'", "'\"'\"'")
            
            move_cmd = f"mkdir -p '{target_dir_escaped}' && mv '{temp_path_escaped}' '{target_path_escaped}' && chmod 644 '{target_path_escaped}'"
            move_result = subprocess.run(
                ["adb", "shell", "run-as", "com.termux", "sh", "-c", move_cmd],
                capture_output=True,
                text=True
            )
            
            if move_result.returncode == 0:
                copied += 1
                size_mb = file_path.stat().st_size / (1024 * 1024)
                print(f"✓ ({size_mb:.2f} MB)")
            else:
                failed += 1
                print(f"✗ Failed to move: {move_result.stderr.strip()}")
                # Clean up temp file
                subprocess.run(
                    ["adb", "shell", "run-as", "com.termux", "sh", "-c", f"rm -f '{temp_path_escaped}'"],
                    capture_output=True
                )
        else:
            failed += 1
            print(f"✗ Failed to push: {push_result.stderr.strip()}")
    
    print(f"\n{'='*50}")
    print(f"✓ Successfully copied {copied} files")
    if failed > 0:
        print(f"✗ Failed to copy {failed} files")
    print(f"{'='*50}")


def main():
    parser = argparse.ArgumentParser(
        description="Download source archives from GitHub releases and extract to Termux localsource"
    )
    parser.add_argument(
        "--repo",
        default="RiteshF7/droidrundepedency",
        help="GitHub repository (default: RiteshF7/droidrundepedency)"
    )
    parser.add_argument(
        "--release",
        default="latest",
        help="Release tag (default: latest)"
    )
    parser.add_argument(
        "--archive",
        default="source.7z",
        help="Archive filename (default: source.7z)"
    )
    parser.add_argument(
        "--termux-home",
        default="/data/data/com.termux/files/home",
        help="Termux home directory (default: /data/data/com.termux/files/home)"
    )
    parser.add_argument(
        "--localsource-dir",
        default="localsource",
        help="Localsource directory name (default: localsource)"
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="Force re-download even if files exist"
    )
    parser.add_argument(
        "--keep-archive",
        action="store_true",
        help="Keep downloaded archive after extraction"
    )
    
    args = parser.parse_args()
    
    # Determine release tag
    release_tag = args.release
    if release_tag == "latest":
        print("Fetching latest release tag...")
        try:
            release_tag = get_latest_release_tag(args.repo)
            print(f"Latest release tag: {release_tag}")
        except Exception as e:
            print(f"Error: {e}")
            sys.exit(1)
    
    # Create temporary directory for download and extraction
    with tempfile.TemporaryDirectory() as temp_dir:
        temp_path = Path(temp_dir)
        archive_path = temp_path / args.archive
        extract_path = temp_path / "extracted"
        
        try:
            # Download archive
            print("\n" + "="*50)
            print("Downloading source archive")
            print("="*50)
            download_archive(args.repo, release_tag, args.archive, archive_path)
            
            # Extract archive
            print("\n" + "="*50)
            print("Extracting archive")
            print("="*50)
            extract_archive(archive_path, extract_path)
            
            # Copy to Termux
            print("\n" + "="*50)
            print("Copying to Termux")
            print("="*50)
            copy_to_termux(extract_path, args.termux_home, args.localsource_dir)
            
            print("\n" + "="*50)
            print("✓ Successfully completed!")
            print("="*50)
            
        except Exception as e:
            print(f"\n✗ Error: {e}")
            sys.exit(1)


if __name__ == "__main__":
    main()

