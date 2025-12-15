#!/bin/bash
# setup-and-build-via-adb.sh
# Set up SSH and build wheels directly via ADB shell commands

set -e

ADB_PATH="${LOCALAPPDATA}/Android/Sdk/platform-tools/adb.exe"

echo "=== Setting up SSH and building wheels via ADB ==="
echo ""

# Check if emulator is connected
"$ADB_PATH" devices | grep -q "emulator" || {
    echo "Error: No emulator detected. Please start the Pixel 4a emulator first."
    exit 1
}

echo "Step 1: Setting up SSH in Termux..."
echo "Opening Termux and running setup commands..."

# Execute commands in Termux via ADB
# Note: We need to use am start to open Termux and then use run-as or direct execution

"$ADB_PATH" shell << 'TERMUX_EOF'
# Try to execute via Termux's shell
export PREFIX=/data/data/com.termux/files/usr
export HOME=/data/data/com.termux/files/home
export PATH=$PREFIX/bin:$PATH

# Install packages
pkg update -y && pkg install -y openssh python python-pip

# Set up SSH
mkdir -p $HOME/.ssh
chmod 700 $HOME/.ssh

# Generate SSH key if needed
if [ ! -f $HOME/.ssh/id_rsa ]; then
    ssh-keygen -t rsa -f $HOME/.ssh/id_rsa -N "" -q
fi

# Set up authorized_keys
cat $HOME/.ssh/id_rsa.pub > $HOME/.ssh/authorized_keys
chmod 600 $HOME/.ssh/authorized_keys

# Start SSH server
sshd

echo "SSH setup complete!"
TERMUX_EOF

echo ""
echo "Step 2: Building wheels..."
echo "This will take several minutes..."

"$ADB_PATH" shell << 'BUILD_EOF'
export PREFIX=/data/data/com.termux/files/usr
export HOME=/data/data/com.termux/files/home
export PATH=$PREFIX/bin:$PATH

cd $HOME
mkdir -p wheels
cd wheels

# Install build tools
pip install --upgrade pip wheel build setuptools

# Download and build droidrun
pip download 'droidrun[google]' --dest . --prefer-binary --no-cache-dir --no-deps=false

# Build wheels from source
for src in *.tar.gz; do
    [ -f "$src" ] && [ ! -f "${src%.tar.gz}.whl" ] && pip wheel --no-deps --wheel-dir . "$src"
done

echo "Build complete! Check $HOME/wheels"
BUILD_EOF

echo ""
echo "Step 3: Copying wheels to Windows..."
mkdir -p termux-packages/wheels/aarch64

"$ADB_PATH" pull /data/data/com.termux/files/home/wheels termux-packages/wheels/aarch64/

echo ""
echo "✅ Done! Wheels are in termux-packages/wheels/aarch64/"




