#!/usr/bin/env python3
"""
Copy build folder to Termux device using ADB
Uses base64 encoding to transfer files through ADB shell
"""

import subprocess
import base64
import os
import sys

def run_adb_command(cmd):
    """Run an ADB command and return output"""
    try:
        result = subprocess.run(
            ["adb", "shell", cmd],
            capture_output=True,
            text=True,
            check=False
        )
        return result.stdout, result.stderr, result.returncode
    except Exception as e:
        return "", str(e), 1

def copy_file_to_device(local_file, remote_path, filename):
    """Copy a file to device using base64 encoding"""
    print(f"Copying {filename}...", end=" ", flush=True)
    
    # Read and encode file
    try:
        with open(local_file, "rb") as f:
            content = f.read()
        encoded = base64.b64encode(content).decode('ascii')
    except Exception as e:
        print(f"✗ Failed to read file: {e}")
        return False
    
    # Create Python script to decode and write
    python_script = f'''
import base64
import os
content = """{encoded}"""
try:
    decoded = base64.b64decode(content)
    os.makedirs("{remote_path}", exist_ok=True)
    with open("{remote_path}/{filename}", "wb") as f:
        f.write(decoded)
    print("SUCCESS")
except Exception as e:
    print(f"ERROR: {{e}}")
    exit(1)
'''
    
    # Execute via adb
    cmd = f"run-as com.termux sh -c 'export PREFIX=/data/data/com.termux/files/usr && export PATH=$PREFIX/bin:$PATH && python3 << \"PYEOF\"\n{python_script}\nPYEOF\nchmod +x {remote_path}/{filename} 2>/dev/null || true'"
    
    stdout, stderr, code = run_adb_command(cmd)
    
    if "SUCCESS" in stdout:
        print("✓")
        return True
    else:
        print(f"✗ {stderr or stdout}")
        return False

def main():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    project_root = os.path.dirname(script_dir)
    build_dir = os.path.join(project_root, "scripts", "build")
    target_dir = "/data/data/com.termux/files/home/droidrunBuild/scripts/build"
    
    print("Copying build folder to device...")
    print(f"Source: {build_dir}")
    print(f"Target: {target_dir}")
    print()
    
    # Create target directory
    cmd = f"run-as com.termux sh -c 'mkdir -p {target_dir}'"
    stdout, stderr, code = run_adb_command(cmd)
    if code != 0:
        print(f"ERROR: Failed to create target directory: {stderr}")
        return 1
    
    # Copy files
    copied = 0
    failed = 0
    
    for filename in os.listdir(build_dir):
        filepath = os.path.join(build_dir, filename)
        if os.path.isfile(filepath) and (filename.endswith('.sh') or filename.endswith('.md')):
            if copy_file_to_device(filepath, target_dir, filename):
                copied += 1
            else:
                failed += 1
    
    # Verify
    print()
    print("=== Verification ===")
    cmd = f"run-as com.termux sh -c 'ls -lah {target_dir}/'"
    stdout, stderr, code = run_adb_command(cmd)
    print(stdout)
    
    print()
    print("=== Summary ===")
    print(f"  Copied: {copied}")
    print(f"  Failed: {failed}")
    
    if copied > 0:
        print(f"\n✓ Build folder successfully copied to: {target_dir}")
        return 0
    else:
        print("\n✗ Failed to copy build folder")
        return 1

if __name__ == "__main__":
    sys.exit(main())

