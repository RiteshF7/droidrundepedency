#!/usr/bin/env bash
# Quick connect to Termux - Copy and paste these commands

echo "=== Quick Connect to Termux ==="
echo
echo "1. Setup port forwarding:"
echo "   adb forward tcp:8022 tcp:8022"
echo
echo "2. Connect via SSH:"
echo "   ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p 8022 u0_a217@127.0.0.1"
echo
echo "   Password: trex"
echo
echo "================================="

