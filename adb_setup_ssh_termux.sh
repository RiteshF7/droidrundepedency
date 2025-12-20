#!/usr/bin/env bash
# Setup SSH in Termux and connect via ADB
# This script uses ADB to execute commands in Termux

set -euo pipefail

USERNAME="u0_a217"
PORT="8022"
PASSWORD="trex"
TERMUX_HOME="/data/data/com.termux/files/home"
TERMUX_PREFIX="/data/data/com.termux/files/usr"

echo "=========================================="
echo "Setting up SSH in Termux via ADB"
echo "=========================================="
echo "Username: $USERNAME"
echo "Port: $PORT"
echo "=========================================="
echo

# Function to execute command in Termux
termux_exec() {
    local cmd="$1"
    adb shell "run-as com.termux sh -c 'cd $TERMUX_HOME && export PATH=$TERMUX_PREFIX/bin:\$PATH && export HOME=$TERMUX_HOME && export PREFIX=$TERMUX_PREFIX && $cmd'"
}

# Step 1: Check if openssh is installed
echo "[1/5] Checking if openssh is installed..."
if termux_exec "pkg list-installed 2>/dev/null | grep -q openssh"; then
    echo "✓ openssh is already installed"
else
    echo "[1/5] Installing openssh..."
    termux_exec "pkg install -y openssh" || {
        echo "✗ Failed to install openssh"
        echo "Please install manually in Termux: pkg install openssh"
        exit 1
    }
    echo "✓ openssh installed"
fi

# Step 2: Set password
echo "[2/5] Setting password for user $USERNAME..."
termux_exec "echo '$PASSWORD' | passwd $USERNAME" || {
    echo "⚠ Password might already be set, continuing..."
}
echo "✓ Password configured"

# Step 3: Generate SSH host keys if they don't exist
echo "[3/5] Checking SSH host keys..."
if ! termux_exec "test -f $TERMUX_PREFIX/etc/ssh/ssh_host_rsa_key"; then
    echo "Generating SSH host keys..."
    termux_exec "ssh-keygen -A -f $TERMUX_PREFIX" || echo "⚠ Host key generation failed, continuing..."
fi
echo "✓ SSH host keys ready"

# Step 4: Start SSH server
echo "[4/5] Starting SSH server..."
termux_exec "sshd" || {
    echo "⚠ SSH server might already be running"
}
sleep 2
echo "✓ SSH server started"

# Step 5: Setup port forwarding and connect
echo "[5/5] Setting up port forwarding..."
adb forward tcp:8022 tcp:8022
if [ $? -eq 0 ]; then
    echo "✓ Port forwarding: localhost:8022 -> Termux:8022"
else
    echo "✗ Failed to set up port forwarding"
    exit 1
fi

echo
echo "=========================================="
echo "Connecting to Termux via SSH"
echo "=========================================="
echo "Host: 127.0.0.1:$PORT"
echo "Username: $USERNAME"
echo "Password: $PASSWORD"
echo "=========================================="
echo

# Connect via SSH
if command -v sshpass >/dev/null 2>&1; then
    echo "Using sshpass for automatic password..."
    sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no -p $PORT $USERNAME@127.0.0.1
elif command -v expect >/dev/null 2>&1; then
    echo "Using expect for automatic password..."
    expect << EOF
set timeout 30
spawn ssh -o StrictHostKeyChecking=no -p $PORT $USERNAME@127.0.0.1
expect {
    "password:" {
        send "$PASSWORD\r"
        exp_continue
    }
    "Password:" {
        send "$PASSWORD\r"
        exp_continue
    }
    "Are you sure you want to continue connecting" {
        send "yes\r"
        exp_continue
    }
    "~" {
        interact
    }
    "$ " {
        interact
    }
    eof
}
EOF
else
    echo "Enter password manually: $PASSWORD"
    ssh -o StrictHostKeyChecking=no -p $PORT $USERNAME@127.0.0.1
fi

