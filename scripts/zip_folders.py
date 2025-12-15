#!/usr/bin/env python3
"""
Script to create ZIP files from folders.

Usage:
    python zip_folders.py <folder_path> <output_zip_path>
    
    Example:
        python zip_folders.py path/to/folder output.zip
"""

import sys
import argparse
import zipfile
import io
from pathlib import Path

# Fix Windows console encoding
if sys.platform == 'win32':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8', errors='replace')


def zip_folder(folder_path: Path, output_zip_path: Path) -> None:
    """
    Create a ZIP file from a folder.
    
    Args:
        folder_path: Path to the folder to zip
        output_zip_path: Path where the ZIP file will be created
    """
    if not folder_path.exists():
        raise FileNotFoundError(f"Folder not found: {folder_path}")
    
    if not folder_path.is_dir():
        raise ValueError(f"Path is not a directory: {folder_path}")
    
    print(f"Creating ZIP from: {folder_path}")
    print(f"Output: {output_zip_path}")
    
    # Count files first for progress
    file_count = sum(1 for _ in folder_path.rglob("*") if _.is_file())
    print(f"Files to compress: {file_count}")
    
    with zipfile.ZipFile(output_zip_path, 'w', zipfile.ZIP_DEFLATED) as zipf:
        files_processed = 0
        for file_path in folder_path.rglob("*"):
            if file_path.is_file():
                # Get relative path from the folder
                arcname = file_path.relative_to(folder_path)
                zipf.write(file_path, arcname)
                files_processed += 1
                if files_processed % 10 == 0:
                    print(f"  Processed {files_processed}/{file_count} files...", end='\r')
    
    print(f"\n[OK] Created ZIP file: {output_zip_path}")
    print(f"  Size: {output_zip_path.stat().st_size / 1024 / 1024:.2f} MB")


def main():
    parser = argparse.ArgumentParser(
        description="Create a ZIP file from a folder",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python zip_folders.py path/to/folder output.zip
  python zip_folders.py ./my_folder ./my_folder.zip
        """
    )
    
    parser.add_argument(
        "folder_path",
        type=str,
        help="Path to the folder to zip"
    )
    
    parser.add_argument(
        "output_zip_path",
        type=str,
        help="Path where the ZIP file will be created"
    )
    
    args = parser.parse_args()
    
    folder_path = Path(args.folder_path)
    output_zip_path = Path(args.output_zip_path)
    
    # Ensure output directory exists
    output_zip_path.parent.mkdir(parents=True, exist_ok=True)
    
    try:
        zip_folder(folder_path, output_zip_path)
    except (FileNotFoundError, ValueError) as e:
        print(f"Error: {e}")
        sys.exit(1)
    except Exception as e:
        print(f"Unexpected error: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()

