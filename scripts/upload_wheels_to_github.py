#!/usr/bin/env python3
"""
Script to zip wheel folders and upload them to GitHub Releases.

This script:
1. Zips the aarch64_wheels and x86_wheels folders
2. Uploads both ZIP files to a GitHub release

Usage:
    python upload_wheels_to_github.py <release_tag> [--repo owner/repo]
    
    Example:
        python upload_wheels_to_github.py v1.0.0
        python upload_wheels_to_github.py v1.0.0 --repo owner/repo
    
    The repository will be auto-detected from git remote if not provided.
"""

import sys
import subprocess
import argparse
import io
from pathlib import Path

# Fix Windows console encoding
if sys.platform == 'win32':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8', errors='replace')


# Paths
SCRIPT_DIR = Path(__file__).parent.absolute()
DEPENDENCIES_DIR = SCRIPT_DIR / "droidrunandroidwrapper" / "depedencies"
AARCH64_WHEELS_DIR = DEPENDENCIES_DIR / "arch64_wheels"
X86_WHEELS_DIR = DEPENDENCIES_DIR / "x86_wheels"
TOKEN_FILE = SCRIPT_DIR / "termux-app" / "github.token"

# Output ZIP files (in dependencies directory)
AARCH64_ZIP = DEPENDENCIES_DIR / "arch64_wheels.zip"
X86_ZIP = DEPENDENCIES_DIR / "x86_wheels.zip"


def get_repo_from_git() -> str:
    """Get repository owner/repo from git remote."""
    # Try droidrunandroidwrapper directory first
    git_dir = SCRIPT_DIR / "droidrunandroidwrapper"
    if not git_dir.exists():
        # Try root directory
        git_dir = SCRIPT_DIR
    
    try:
        result = subprocess.run(
            ["git", "remote", "get-url", "origin"],
            cwd=git_dir,
            capture_output=True,
            text=True,
            check=True
        )
        remote_url = result.stdout.strip()
        
        # Extract owner/repo from URL
        # Handle both https://github.com/owner/repo.git and git@github.com:owner/repo.git
        if "github.com" in remote_url:
            if remote_url.startswith("https://"):
                # https://github.com/owner/repo.git
                parts = remote_url.replace("https://github.com/", "").replace(".git", "").split("/")
            elif remote_url.startswith("git@"):
                # git@github.com:owner/repo.git
                parts = remote_url.split(":")[1].replace(".git", "").split("/")
            else:
                raise ValueError(f"Unknown git remote format: {remote_url}")
            
            if len(parts) >= 2:
                return f"{parts[0]}/{parts[1]}"
        
        raise ValueError(f"Could not parse repository from: {remote_url}")
    except subprocess.CalledProcessError:
        raise ValueError("Could not get git remote. Make sure you're in a git repository.")
    except Exception as e:
        raise ValueError(f"Error getting git remote: {e}")


def run_command(cmd: list, description: str) -> None:
    """Run a command and handle errors."""
    print(f"\n{'='*60}")
    print(f"{description}")
    print(f"{'='*60}")
    
    result = subprocess.run(cmd, capture_output=True, text=True)
    
    if result.returncode != 0:
        print(f"Error: {description} failed")
        print(f"Command: {' '.join(cmd)}")
        if result.stdout:
            print(f"Stdout: {result.stdout}")
        if result.stderr:
            print(f"Stderr: {result.stderr}")
        sys.exit(1)
    
    if result.stdout:
        print(result.stdout)
    if result.stderr:
        print(result.stderr)


def main():
    parser = argparse.ArgumentParser(
        description="Zip wheel folders and upload to GitHub Releases",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python upload_wheels_to_github.py v1.0.0
  python upload_wheels_to_github.py v1.0.0 --repo owner/repo

This script will:
1. Create arch64_wheels.zip from droidrunandroidwrapper/depedencies/arch64_wheels
2. Create x86_wheels.zip from droidrunandroidwrapper/depedencies/x86_wheels
3. Upload both ZIPs to the specified GitHub release
        """
    )
    
    parser.add_argument(
        "release_tag",
        type=str,
        help="Release tag (e.g., 'v1.0.0')"
    )
    
    parser.add_argument(
        "--repo",
        type=str,
        default=None,
        help="Repository in format 'owner/repo' (e.g., 'droidrun/droidrun'). If not provided, will auto-detect from git remote."
    )
    
    args = parser.parse_args()
    
    # Auto-detect repo from git if not provided
    if args.repo is None:
        try:
            args.repo = get_repo_from_git()
            print(f"Auto-detected repository from git: {args.repo}")
        except ValueError as e:
            print(f"Error: {e}")
            print("Please provide --repo argument manually.")
            sys.exit(1)
    
    # Validate paths
    if not AARCH64_WHEELS_DIR.exists():
        print(f"Error: aarch64 wheels directory not found: {AARCH64_WHEELS_DIR}")
        sys.exit(1)
    
    if not X86_WHEELS_DIR.exists():
        print(f"Error: x86 wheels directory not found: {X86_WHEELS_DIR}")
        sys.exit(1)
    
    if not TOKEN_FILE.exists():
        print(f"Error: GitHub token file not found: {TOKEN_FILE}")
        sys.exit(1)
    
    # Get paths to scripts
    zip_script = SCRIPT_DIR / "zip_folders.py"
    upload_script = SCRIPT_DIR / "upload_to_github_release.py"
    
    if not zip_script.exists():
        print(f"Error: zip_folders.py not found: {zip_script}")
        sys.exit(1)
    
    if not upload_script.exists():
        print(f"Error: upload_to_github_release.py not found: {upload_script}")
        sys.exit(1)
    
    print("\n" + "="*60)
    print("Uploading Wheel Dependencies to GitHub Releases")
    print("="*60)
    print(f"Repository: {args.repo}")
    print(f"Release Tag: {args.release_tag}")
    print(f"AArch64 Wheels: {AARCH64_WHEELS_DIR}")
    print(f"X86 Wheels: {X86_WHEELS_DIR}")
    
    try:
        # Step 1: Zip aarch64_wheels folder
        run_command(
            [sys.executable, str(zip_script), str(AARCH64_WHEELS_DIR), str(AARCH64_ZIP)],
            "Creating arch64_wheels.zip"
        )
        
        # Step 2: Zip x86_wheels folder
        run_command(
            [sys.executable, str(zip_script), str(X86_WHEELS_DIR), str(X86_ZIP)],
            "Creating x86_wheels.zip"
        )
        
        # Step 3: Upload aarch64_wheels.zip
        run_command(
            [
                sys.executable,
                str(upload_script),
                str(AARCH64_ZIP),
                args.repo,
                args.release_tag,
                "--token-file",
                str(TOKEN_FILE)
            ],
            f"Uploading arch64_wheels.zip to {args.repo} release {args.release_tag}"
        )
        
        # Step 4: Upload x86_wheels.zip
        run_command(
            [
                sys.executable,
                str(upload_script),
                str(X86_ZIP),
                args.repo,
                args.release_tag,
                "--token-file",
                str(TOKEN_FILE)
            ],
            f"Uploading x86_wheels.zip to {args.repo} release {args.release_tag}"
        )
        
        print("\n" + "="*60)
        print("[OK] All uploads completed successfully!")
        print("="*60)
        print(f"Release URL: https://github.com/{args.repo}/releases/tag/{args.release_tag}")
        print(f"\nCreated ZIP files:")
        print(f"  - {AARCH64_ZIP}")
        print(f"  - {X86_ZIP}")
        print("\nNote: ZIP files are kept in the dependencies directory.")
        print("You can delete them manually if needed.")
        
    except KeyboardInterrupt:
        print("\n\nOperation cancelled by user")
        sys.exit(1)
    except Exception as e:
        print(f"\nError: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()

