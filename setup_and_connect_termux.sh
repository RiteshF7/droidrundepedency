#!/usr/bin/env bash
# Setup SSH in Termux and connect
# Username: u0_a217
# Port: 8022 (forwarded via ADB)

set -euo pipefail

USERNAME="u0_a217"
PORT="8022"
PASSWORD="trex"

echo "=========================================="
echo "Termux SSH Setup and Connection"
echo "=========================================="
echo "Username: $USERNAME"
echo "Port: $PORT (ADB forwarded)"
echo "=========================================="
echo

# Step 1: Setup port forwarding
echo "Setting up ADB port forwarding..."
adb forward tcp:8022 tcp:8022
if [ $? -eq 0 ]; then
    echo "✓ Port forwarding set up"
else
    echo "✗ Failed to set up port forwarding"
    exit 1
fi

# Step 2: Install openssh in Termux (if not installed)
echo "Checking if openssh is installed in Termux..."
adb shell "run-as com.termux sh -c 'cd /data/data/com.termux/files/home && source /data/data/com.termux/files/usr/etc/profile && pkg list-installed 2>/dev/null | grep -q openssh || pkg install -y openssh'"

# Step 3: Start SSH server in Termux
echo "Starting SSH server in Termux..."
adb shell "run-as com.termux sh -c 'cd /data/data/com.termux/files/home && source /data/data/com.termux/files/usr/etc/profile && sshd'"

# Wait a moment for SSH to start
sleep 2

# Step 4: Set password (if not already set)
echo "Setting password (if needed)..."
adb shell "run-as com.termux sh -c 'cd /data/data/com.termux/files/home && source /data/data/com.termux/files/usr/etc/profile && echo \"$PASSWORD\" | passwd $USERNAME'"

# Step 5: Connect via SSH
echo "Connecting to Termux via SSH..."
echo "Password: $PASSWORD"
echo

if command -v expect >/dev/null 2>&1; then
    expect << EOF
set timeout 30
spawn ssh -p $PORT $USERNAME@127.0.0.1
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
    eof
}
EOF
elif command -v sshpass >/dev/null 2>&1; then
    sshpass -p "$PASSWORD" ssh -p $PORT $USERNAME@127.0.0.1
else
    echo "Note: expect or sshpass not found. Enter password manually: $PASSWORD"
    ssh -p $PORT $USERNAME@127.0.0.1
fi

