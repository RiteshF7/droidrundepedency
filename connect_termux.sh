#!/usr/bin/env bash
# Helper script to connect to Termux via SSH
# Usage: ./connect_termux.sh [username] [host] [port]

set -euo pipefail

# Default values (username detected via ADB: u0_a217)
USERNAME="${1:-u0_a217}"
HOST="${2:-127.0.0.1}"
PORT="${3:-8022}"
PASSWORD="trex"

echo "=========================================="
echo "Termux SSH Connection Helper"
echo "=========================================="
echo "Username: $USERNAME"
echo "Host: $HOST"
echo "Port: $PORT"
echo "=========================================="
echo

# Check if expect is available
if command -v expect >/dev/null 2>&1; then
    echo "Using expect for password authentication..."
    expect << EOF
set timeout 30
spawn ssh -p $PORT $USERNAME@$HOST
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
    echo "Using sshpass for password authentication..."
    sshpass -p "$PASSWORD" ssh -p $PORT $USERNAME@$HOST
else
    echo "Note: expect or sshpass not found. You'll need to enter password manually."
    echo "Connecting to $USERNAME@$HOST:$PORT..."
    echo "Password: $PASSWORD"
    echo
    ssh -p $PORT $USERNAME@$HOST
fi

