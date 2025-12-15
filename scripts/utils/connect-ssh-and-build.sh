#!/bin/bash
# connect-ssh-and-build.sh
# This script connects via SSH and builds wheels
# Run from Windows PowerShell or Git Bash

set -e

SSH_HOST="localhost"
SSH_PORT="8022"
SSH_USER="u0_a$(adb shell id | sed 's/.*uid=\([0-9]*\).*/\1/' | awk '{print $1}')"

echo "=== Connecting to Termux via SSH ==="
echo "Host: $SSH_HOST"
echo "Port: $SSH_PORT"
echo "User: $SSH_USER"
echo ""

# Forward port if not already done
adb forward tcp:8022 tcp:8022 2>/dev/null || echo "Port forwarding may already be active"

echo "Pushing build script..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_SCRIPT="$SCRIPT_DIR/../build/install-droidrun-dependencies.sh"
adb push "$BUILD_SCRIPT" /data/local/tmp/install-droidrun-dependencies.sh

echo ""
echo "Connecting via SSH..."
echo "Once connected, run: bash /data/local/tmp/install-droidrun-dependencies.sh"
echo ""

ssh -p "$SSH_PORT" "$SSH_USER@$SSH_HOST"




