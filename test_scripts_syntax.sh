#!/usr/bin/env bash
# Test script to check syntax of all installer scripts
# Can be run in WSL to catch common errors

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER_DIR="$SCRIPT_DIR/installer_refactored"
ERRORS=0

echo "Testing installer scripts syntax..."
echo "=================================="
echo

# Test common.sh
echo "Testing common.sh..."
if bash -n "$INSTALLER_DIR/common.sh" 2>&1; then
    echo "✓ common.sh syntax OK"
else
    echo "✗ common.sh syntax error"
    ((ERRORS++))
fi
echo

# Test main script
echo "Testing install_droidrun.sh..."
if bash -n "$INSTALLER_DIR/install_droidrun.sh" 2>&1; then
    echo "✓ install_droidrun.sh syntax OK"
else
    echo "✗ install_droidrun.sh syntax error"
    ((ERRORS++))
fi
echo

# Test all phase scripts
for script in "$INSTALLER_DIR/scripts"/*.sh; do
    script_name=$(basename "$script")
    echo "Testing $script_name..."
    if bash -n "$script" 2>&1; then
        echo "✓ $script_name syntax OK"
    else
        echo "✗ $script_name syntax error"
        ((ERRORS++))
    fi
    echo
done

# Summary
echo "=================================="
if [ $ERRORS -eq 0 ]; then
    echo "✓ All scripts passed syntax check!"
    exit 0
else
    echo "✗ Found $ERRORS script(s) with syntax errors"
    exit 1
fi

