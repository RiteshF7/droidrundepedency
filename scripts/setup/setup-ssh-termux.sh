#!/bin/bash
# setup-ssh-termux.sh - Set up SSH in Termux on emulator
# This script will be pushed to emulator and executed via ADB

set -e

echo "=== Setting up SSH in Termux ==="
echo ""

# Install Termux packages
echo "Step 1: Installing packages..."
pkg update -y || echo "Warning: pkg update failed, continuing..."
pkg install -y openssh python python-pip || {
    echo "Error: Failed to install packages"
    exit 1
}

# Set up SSH
echo ""
echo "Step 2: Configuring SSH..."
mkdir -p ~/.ssh
chmod 700 ~/.ssh

# Generate SSH key if not exists
if [ ! -f ~/.ssh/id_rsa ]; then
    echo "Generating SSH key..."
    ssh-keygen -t rsa -f ~/.ssh/id_rsa -N "" -q
fi

# Create authorized_keys with the public key
cat ~/.ssh/id_rsa.pub > ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys

# Create SSH directory for server
mkdir -p ~/.ssh/sshd_config.d || true

# Start SSH server
echo ""
echo "Step 3: Starting SSH server..."
sshd || {
    echo "Warning: SSH server may already be running or failed to start"
    echo "Trying to restart..."
    pkill sshd || true
    sleep 1
    sshd || echo "Note: SSH server start failed, you may need to start manually"
}

# Get IP address
IP=$(ifconfig 2>/dev/null | grep "inet " | grep -v 127.0.0.1 | awk '{print $2}' | head -1 || echo "unknown")
USERNAME=$(whoami)
ARCH=$(uname -m)

echo ""
echo "=== SSH Setup Complete ==="
echo "IP Address: $IP"
echo "SSH Port: 8022"
echo "Username: $USERNAME"
echo "Architecture: $ARCH"
echo ""
echo "SSH server should be running on port 8022"
echo "You can now connect via ADB port forwarding and SSH"




