#!/usr/bin/env bash
# Quick connect to Termux (assumes SSH is already set up)
# Username: u0_a217 (detected via ADB)

USERNAME="u0_a217"
PORT="8022"
PASSWORD="trex"

# Setup port forwarding
adb forward tcp:8022 tcp:8022

# Connect
if command -v sshpass >/dev/null 2>&1; then
    sshpass -p "$PASSWORD" ssh -p $PORT $USERNAME@127.0.0.1
elif command -v expect >/dev/null 2>&1; then
    expect << EOF
spawn ssh -p $PORT $USERNAME@127.0.0.1
expect "password:" { send "$PASSWORD\r" }
expect "Password:" { send "$PASSWORD\r" }
interact
EOF
else
    echo "Password: $PASSWORD"
    ssh -p $PORT $USERNAME@127.0.0.1
fi

