#!/usr/bin/env bash
# Run Python Phase 1 installer in Termux via ADB

set -euo pipefail

echo "=========================================="
echo "Running Python Phase 1 via ADB"
echo "=========================================="
echo

# Fix import if needed
echo "[1/3] Ensuring common.py has correct imports..."
adb shell "run-as com.termux sh -c 'cd /data/data/com.termux/files/home/droidrundepedency/pythondroidruninstaller && export PATH=/data/data/com.termux/files/usr/bin:\$PATH && sed -i \"s/from typing import Optional\$/from typing import Optional, List/\" common.py 2>/dev/null || true'"

# Setup environment
TERMUX_HOME="/data/data/com.termux/files/home"
TERMUX_PREFIX="/data/data/com.termux/files/usr"
SCRIPT_DIR="$TERMUX_HOME/droidrundepedency/pythondroidruninstaller"

# Run Phase 1
echo "[2/3] Running Phase 1 installer..."
echo

FORCE="${FORCE_RERUN:-}"
if [ -n "$FORCE" ]; then
    echo "FORCE_RERUN is set - will rerun even if completed"
    adb shell "run-as com.termux sh -c 'cd $SCRIPT_DIR && export PATH=$TERMUX_PREFIX/bin:\$PATH && export HOME=$TERMUX_HOME && export FORCE_RERUN=1 && python3 phase1_build_tools.py'"
else
    adb shell "run-as com.termux sh -c 'cd $SCRIPT_DIR && export PATH=$TERMUX_PREFIX/bin:\$PATH && export HOME=$TERMUX_HOME && python3 phase1_build_tools.py'"
fi

echo
echo "[3/3] Done!"
echo "=========================================="

