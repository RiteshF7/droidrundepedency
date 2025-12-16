#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Update or create GitHub release with sourceversion1.7z
This script can update an existing release or create a new one.
"""

import os
import sys
import json
import requests
from pathlib import Path

# Fix Windows console encoding
if sys.platform == 'win32':
    import io
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8', errors='replace')

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
        print("=" * 60)
        print("GITHUB_TOKEN not set!")
        print("=" * 60)
        print("\nTo create release manually:")
        print("1. Go to: https://github.com/RiteshF7/droidrundepedency/releases/new")
        print("2. Tag: sourceversion1")
        print("3. Title: Source Version 1")
        print("4. Upload: depedencies/sourceversion1.7z")
        print("5. Click 'Publish release'")
        print("\nOr set token: export GITHUB_TOKEN=your_token")
        print("Token needs 'repo' scope: https://github.com/settings/tokens")
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
    print(f"\nChecking if release '{RELEASE_TAG}' exists...")
    check_url = f"https://api.github.com/repos/{GITHUB_REPO}/releases/tags/{RELEASE_TAG}"
    response = requests.get(check_url, headers=headers)
    
    release_id = None
    if response.status_code == 200:
        release_data = response.json()
        release_id = release_data["id"]
        print(f"[OK] Release exists (ID: {release_id})")
        print(f"  URL: {release_data.get('html_url', 'N/A')}")
        
        # Check if asset already exists
        assets = release_data.get("assets", [])
        existing_asset = next((a for a in assets if a["name"] == archive_path.name), None)
        
        if existing_asset:
            print(f"\nAsset '{archive_path.name}' already exists (ID: {existing_asset['id']})")
            print("Deleting existing asset...")
            delete_url = f"https://api.github.com/repos/{GITHUB_REPO}/releases/assets/{existing_asset['id']}"
            del_response = requests.delete(delete_url, headers=headers)
            if del_response.status_code == 204:
                print("[OK] Existing asset deleted")
            else:
                print(f"Warning: Failed to delete existing asset: {del_response.status_code}")
        
        upload_url = release_data["upload_url"].split("{")[0]
    else:
        # Create new release
        print(f"Release does not exist. Creating new release...")
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
            print(f"\n[ERROR] Error creating release: {response.status_code}")
            error_data = response.json()
            print(f"Message: {error_data.get('message', 'Unknown error')}")
            if response.status_code == 403:
                print("\nYour token needs 'repo' scope with write access to releases")
                print("Create a new token at: https://github.com/settings/tokens")
                print("\nAlternatively, create release manually:")
                print("https://github.com/RiteshF7/droidrundepedency/releases/new")
            sys.exit(1)
        
        release_info = response.json()
        release_id = release_info["id"]
        upload_url = release_info["upload_url"].split("{")[0]
        print(f"[OK] Release created successfully (ID: {release_id})")
    
    # Upload asset
    print(f"\nUploading {archive_path.name}...")
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
        print(f"\n[ERROR] Error uploading asset: {upload_response.status_code}")
        print(upload_response.json())
        sys.exit(1)
    
    asset_info = upload_response.json()
    download_url = asset_info["browser_download_url"]
    
    print("\n" + "=" * 60)
    print("[SUCCESS] Release updated/created successfully!")
    print("=" * 60)
    print(f"\nRelease URL: https://github.com/{GITHUB_REPO}/releases/tag/{RELEASE_TAG}")
    print(f"Download URL: {download_url}")
    print(f"\nThe installation script can now download from:")
    print(f"https://github.com/{GITHUB_REPO}/releases/download/{RELEASE_TAG}/sourceversion1.7z")

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n\nCancelled by user")
        sys.exit(1)
    except Exception as e:
        print(f"\nError: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)

