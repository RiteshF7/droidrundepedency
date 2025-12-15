#!/usr/bin/env python3
"""Download scikit-learn source tarball from PyPI"""
import json
import urllib.request
import sys
import os

version = "1.5.2"
output_dir = os.path.expanduser("~/wheels")
os.makedirs(output_dir, exist_ok=True)

try:
    # Get package info from PyPI
    json_url = f"https://pypi.org/pypi/scikit-learn/{version}/json"
    print(f"Fetching package info from: {json_url}")
    
    with urllib.request.urlopen(json_url) as response:
        data = json.load(response)
    
    # Find source distribution
    sdist = [f for f in data["urls"] if f["packagetype"] == "sdist"][0]
    download_url = sdist["url"]
    filename = sdist["filename"]
    output_path = os.path.join(output_dir, filename)
    
    print(f"Downloading from: {download_url}")
    print(f"Saving to: {output_path}")
    
    # Download file
    urllib.request.urlretrieve(download_url, output_path)
    
    size = os.path.getsize(output_path)
    print(f"✅ Successfully downloaded: {filename}")
    print(f"   Size: {size:,} bytes ({size / 1024 / 1024:.2f} MB)")
    
except Exception as e:
    print(f"❌ Error: {e}", file=sys.stderr)
    sys.exit(1)

