#!/usr/bin/env python3
"""
Create GitHub release and upload sourceversion1.7z
Requires: pip install requests
"""

import os
import sys
import json
import requests
from pathlib import Path

# Configuration
GITHUB_REPO = "RiteshF7/droidrundepedency"
RELEASE_TAG = "sourceversion1"
RELEASE_NAME = "Source Version 1"
ARCHIVE_FILE = "depedencies/sourceversion1.7z"
RELEASE_NOTES = """Source packages archive with all standardized source files (24 packages)

This archive contains 24 standardized source packages:
- numpy, scipy, pandas, scikit-learn
- jiter, pyarrow, psutil, grpcio, pillow
- tokenizers, safetensors, cryptography, pydantic-core, orjson
- and more...

All files are renamed to standardized names for easy recognition."""

def main():
    # Check for token
    token = os.environ.get("GITHUB_TOKEN")
    if not token:
        print("Error: GITHUB_TOKEN environment variable not set")
        print("Please set it: export GITHUB_TOKEN=your_token")
        print("Or create a token at: https://github.com/settings/tokens")
        print("Token needs 'repo' scope with write access to releases")
        sys.exit(1)
    
    # Check if archive exists
    archive_path = Path(ARCHIVE_FILE)
    if not archive_path.exists():
        print(f"Error: Archive file not found: {ARCHIVE_FILE}")
        sys.exit(1)
    
    archive_size = archive_path.stat().st_size
    print(f"Archive: {ARCHIVE_FILE} ({archive_size / 1024 / 1024:.1f} MB)")
    
    headers = {
        "Authorization": f"Bearer {token}",
        "Accept": "application/vnd.github.v3+json"
    }
    
    # Check if release already exists
    print(f"Checking if release {RELEASE_TAG} exists...")
    check_url = f"https://api.github.com/repos/{GITHUB_REPO}/releases/tags/{RELEASE_TAG}"
    response = requests.get(check_url, headers=headers)
    
    if response.status_code == 200:
        release_id = response.json()["id"]
        print(f"Release already exists (ID: {release_id})")
        print("You can manually delete it and recreate, or update the tag name")
        sys.exit(1)
    
    # Create release
    print(f"Creating release: {RELEASE_TAG}")
    create_url = f"https://api.github.com/repos/{GITHUB_REPO}/releases"
    release_data = {
        "tag_name": RELEASE_TAG,
        "name": RELEASE_NAME,
        "body": RELEASE_NOTES,
        "draft": False,
        "prerelease": False
    }
    
    response = requests.post(create_url, headers=headers, json=release_data)
    
    if response.status_code != 201:
        print(f"Error creating release: {response.status_code}")
        error_data = response.json()
        print(f"Message: {error_data.get('message', 'Unknown error')}")
        if response.status_code == 403:
            print("\nYour token needs 'repo' scope with write access to releases")
            print("Create a new token at: https://github.com/settings/tokens")
        sys.exit(1)
    
    release_info = response.json()
    upload_url = release_info["upload_url"].split("{")[0]
    print("✓ Release created successfully")
    
    # Upload asset
    print(f"Uploading {archive_path.name}...")
    with open(archive_path, "rb") as f:
        upload_headers = {
            "Authorization": f"Bearer {token}",
            "Accept": "application/vnd.github.v3+json",
            "Content-Type": "application/octet-stream"
        }
        upload_response = requests.post(
            f"{upload_url}?name={archive_path.name}",
            headers=upload_headers,
            data=f
        )
    
    if upload_response.status_code != 201:
        print(f"Error uploading asset: {upload_response.status_code}")
        print(upload_response.json())
        sys.exit(1)
    
    asset_info = upload_response.json()
    download_url = asset_info["browser_download_url"]
    
    print("✓ Upload successful!")
    print(f"\nRelease URL: https://github.com/{GITHUB_REPO}/releases/tag/{RELEASE_TAG}")
    print(f"Download URL: {download_url}")

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\nCancelled by user")
        sys.exit(1)
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)

