#!/usr/bin/env python3
"""
Generic script to upload a ZIP file to GitHub Releases.

Usage:
    python upload_to_github_release.py <zip_path> <repo> <release_tag>
    
    Example:
        python upload_to_github_release.py bootstrap.zip owner/repo v1.0.0

The GitHub token is read from: E:\\Code\\LunarLand\\MiniLinux\\termux-app\\github.token
"""

import sys
import os
import json
import argparse
import io
from pathlib import Path
from typing import Optional

# Fix Windows console encoding
if sys.platform == 'win32':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8', errors='replace')

try:
    import requests
except ImportError:
    print("Error: 'requests' library is required. Install it with: pip install requests")
    sys.exit(1)


# Default token file path
DEFAULT_TOKEN_PATH = r"E:\Code\LunarLand\MiniLinux\termux-app\github.token"


def read_github_token(token_path: str) -> str:
    """Read GitHub token from file."""
    token_file = Path(token_path)
    if not token_file.exists():
        raise FileNotFoundError(f"GitHub token file not found: {token_path}")
    
    token = token_file.read_text().strip()
    if not token:
        raise ValueError(f"GitHub token file is empty: {token_path}")
    
    return token


def create_or_get_release(owner: str, repo: str, tag: str, token: str) -> str:
    """
    Create a new release or get existing release by tag.
    Returns the release ID.
    """
    api_url = f"https://api.github.com/repos/{owner}/{repo}/releases"
    headers = {
        "Authorization": f"token {token}",
        "Accept": "application/vnd.github.v3+json"
    }
    
    # Try to get existing release first
    get_url = f"{api_url}/tags/{tag}"
    response = requests.get(get_url, headers=headers)
    
    if response.status_code == 200:
        release_data = response.json()
        release_id = str(release_data["id"])
        print(f"Found existing release: {tag}")
        return release_id
    
    # Create new release
    print(f"Creating new release: {tag}")
    release_data = {
        "tag_name": tag,
        "name": f"Release {tag}",
        "body": f"Release {tag}",
        "draft": False,
        "prerelease": False
    }
    
    response = requests.post(api_url, headers=headers, json=release_data)
    
    if response.status_code not in range(200, 300):
        error_msg = response.text if response.text else "Unknown error"
        raise Exception(f"Failed to create release (HTTP {response.status_code}): {error_msg}")
    
    release_data = response.json()
    return str(release_data["id"])


def upload_release_asset(owner: str, repo: str, release_id: str, file_path: Path, token: str) -> None:
    """Upload a file as a release asset."""
    upload_url = f"https://uploads.github.com/repos/{owner}/{repo}/releases/{release_id}/assets"
    
    headers = {
        "Authorization": f"token {token}",
        "Accept": "application/vnd.github.v3+json"
    }
    
    file_size = file_path.stat().st_size
    file_name = file_path.name
    
    # Determine content type based on file extension
    content_type = "application/octet-stream"
    if file_path.suffix.lower() == ".zip":
        content_type = "application/zip"
    elif file_path.suffix.lower() == ".tar":
        content_type = "application/x-tar"
    elif file_path.suffix.lower() == ".gz":
        content_type = "application/gzip"
    elif file_path.suffix.lower() == ".7z":
        content_type = "application/x-7z-compressed"
    
    params = {"name": file_name}
    
    print(f"Uploading {file_name} ({file_size / 1024 / 1024:.2f} MB)...")
    
    with open(file_path, "rb") as f:
        headers["Content-Type"] = content_type
        response = requests.post(
            upload_url,
            headers=headers,
            params=params,
            data=f,
            timeout=300  # 5 minute timeout for large files
        )
    
    if response.status_code not in range(200, 300):
        error_msg = response.text if response.text else "Unknown error"
        raise Exception(f"Failed to upload {file_name} (HTTP {response.status_code}): {error_msg}")
    
    print(f"[OK] Uploaded {file_name}")


def main():
    parser = argparse.ArgumentParser(
        description="Upload a ZIP file to GitHub Releases",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=f"""
Examples:
  python upload_to_github_release.py bootstrap.zip owner/repo v1.0.0
  python upload_to_github_release.py bootstrap.zip owner/repo v1.0.0 --token-file custom/path/token

The GitHub token is read from: {DEFAULT_TOKEN_PATH}
        """
    )
    
    parser.add_argument(
        "zip_path",
        type=str,
        help="Path to the ZIP file to upload"
    )
    
    parser.add_argument(
        "repo",
        type=str,
        help="Repository in format 'owner/repo' (e.g., 'RiteshF7/termux-packages')"
    )
    
    parser.add_argument(
        "release_tag",
        type=str,
        help="Release tag (e.g., 'v1.0.0')"
    )
    
    parser.add_argument(
        "--token-file",
        type=str,
        default=DEFAULT_TOKEN_PATH,
        help=f"Path to GitHub token file (default: {DEFAULT_TOKEN_PATH})"
    )
    
    args = parser.parse_args()
    
    # Validate zip file path
    zip_path = Path(args.zip_path)
    if not zip_path.exists():
        print(f"Error: ZIP file not found: {zip_path}")
        sys.exit(1)
    
    if not zip_path.is_file():
        print(f"Error: Path is not a file: {zip_path}")
        sys.exit(1)
    
    # Parse repo
    repo_parts = args.repo.split("/")
    if len(repo_parts) != 2:
        print(f"Error: Invalid repo format. Expected 'owner/repo', got: {args.repo}")
        sys.exit(1)
    
    owner, repo_name = repo_parts
    
    # Read GitHub token
    try:
        token = read_github_token(args.token_file)
    except (FileNotFoundError, ValueError) as e:
        print(f"Error: {e}")
        sys.exit(1)
    
    # Display info
    print("\n=== Uploading to GitHub Releases ===")
    print(f"Repository: {owner}/{repo_name}")
    print(f"Release Tag: {args.release_tag}")
    print(f"File: {zip_path.name} ({zip_path.stat().st_size / 1024 / 1024:.2f} MB)")
    
    try:
        # Step 1: Create or get release
        release_id = create_or_get_release(owner, repo_name, args.release_tag, token)
        print(f"Release ID: {release_id}")
        
        # Step 2: Upload file
        upload_release_asset(owner, repo_name, release_id, zip_path, token)
        
        print("\n=== Upload Complete ===")
        print(f"Release URL: https://github.com/{owner}/{repo_name}/releases/tag/{args.release_tag}")
        
    except Exception as e:
        print(f"\nError: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()

