#!/usr/bin/env bash
# Simple SSH connection to Termux
# Password: trex

# Setup port forwarding
adb forward tcp:8022 tcp:8022

echo "=========================================="
echo "Connecting to Termux via SSH"
echo "=========================================="
echo "Host: 127.0.0.1:8022"
echo "Username: u0_a217"
echo "Password: trex"
echo "=========================================="
echo
echo "Enter password when prompted: trex"
echo

# Connect
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p 8022 u0_a217@127.0.0.1

