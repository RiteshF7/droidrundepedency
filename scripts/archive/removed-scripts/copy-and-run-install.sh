#!/bin/bash
# copy-and-run-install.sh
# Copy install-droidrun-dependencies.sh to Termux and execute it

ADB="${LOCALAPPDATA}/Android/Sdk/platform-tools/adb.exe"
SCRIPT_FILE="scripts/install-droidrun-dependencies.sh"
PYTHON_TRANSFER_SCRIPT="/tmp/transfer_script.py"

# Create Python script to transfer the file
cat > "$PYTHON_TRANSFER_SCRIPT" << 'PYEOF'
import subprocess
import sys
import base64

adb = sys.argv[1]
script_file = sys.argv[2]

# Read the script file
with open(script_file, 'rb') as f:
    script_content = f.read()

# Encode to base64
script_b64 = base64.b64encode(script_content).decode('utf-8')

# Write to Termux using Python
python_cmd = f"""
import base64
import os

os.environ['PREFIX'] = '/data/data/com.termux/files/usr'
os.environ['HOME'] = '/data/data/com.termux/files/home'
os.environ['PATH'] = os.environ['PREFIX'] + '/bin:' + os.environ['PATH']

script_b64 = '''{script_b64}'''
script_content = base64.b64decode(script_b64)

script_path = os.path.join(os.environ['HOME'], 'install-droidrun-dependencies.sh')
with open(script_path, 'wb') as f:
    f.write(script_content)

os.chmod(script_path, 0o755)
print(f'Script written to: {{script_path}}')
print(f'Size: {{len(script_content)}} bytes')
"""

# Execute via ADB
cmd = [
    adb, 'shell', 'run-as', 'com.termux', 
    '/data/data/com.termux/files/usr/bin/python3', '-c', python_cmd
]

result = subprocess.run(cmd, capture_output=True, text=True)
print(result.stdout)
if result.stderr:
    print(result.stderr, file=sys.stderr)
sys.exit(result.returncode)
PYEOF

# Run the Python transfer script
python3 "$PYTHON_TRANSFER_SCRIPT" "$ADB" "$SCRIPT_FILE" || {
    echo "Failed to transfer script"
    exit 1
}

# Now execute the script
echo ""
echo "=== Starting dependency installation ==="
echo "This will take 2-4 hours. Progress logged to ~/wheels/install-dependencies.log"
echo ""

"$ADB" shell "run-as com.termux sh -c '
export PREFIX=/data/data/com.termux/files/usr
export HOME=/data/data/com.termux/files/home
export PATH=\$PREFIX/bin:\$PATH
export NINJAFLAGS=\"-j2\"
export MAKEFLAGS=\"-j2\"
export MAX_JOBS=2
cd \$HOME
./install-droidrun-dependencies.sh
'"

