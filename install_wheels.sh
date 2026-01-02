#!/bin/bash
# Simple script to install all .whl files from a directory
# Skips files that result in errors
WHEELS_DIR="."

if [ ! -d "$WHEELS_DIR" ]; then
    echo "Error: Directory not found: $WHEELS_DIR"
    exit 1
fi

echo "Installing wheels from: $WHEELS_DIR"
TOTAL=$(find "$WHEELS_DIR" -name "*.whl" | wc -l)
echo "Found $TOTAL wheel files"
echo ""

SUCCESS=0
FAILED=0

pkg update -y
pkg upgrade -y
pkg install python
pkg install python-pip
pkg install python-numpy
pkg install python-scipy
pkg install python-pandas
pkg install python-grpcio
pkg install python-pillow

for wheel in "$WHEELS_DIR"/*.whl; do
    if [ ! -f "$wheel" ]; then
        continue
    fi
    
    WHEEL_NAME=$(basename "$wheel")
    echo "[INSTALLING] $WHEEL_NAME"
    
    if pip install "$wheel" --find-links "$WHEELS_DIR" --no-index 2>&1 | tee /tmp/wheel_install.log; then
        echo "[✓] Success: $WHEEL_NAME"
        ((SUCCESS++))
    else
        echo "[✗] Failed: $WHEEL_NAME"
        ((FAILED++))
    fi
    echo ""
done

echo "=================================================="
echo "Summary: $SUCCESS succeeded, $FAILED failed out of $TOTAL total"
echo "=================================================="

