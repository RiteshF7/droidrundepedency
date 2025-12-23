#!/usr/bin/env bash
# Simple script to run commands in Termux via ADB one by one

TERMUX_HOME="/data/data/com.termux/files/home"
TERMUX_PREFIX="/data/data/com.termux/files/usr"

# Default sequence to mimic manual steps
DEFAULT_CMDS=(
    "cd /data/data/com.termux/files/home"
    "export PATH=/data/data/com.termux/files/usr/bin:\$PATH"
    "export HOME=/data/data/com.termux/files/home"
    "export PREFIX=/data/data/com.termux/files/usr"
    "pkg"
)

# If commands are provided as arguments, execute them one by one; otherwise run the default sequence
if [ $# -gt 0 ]; then
    CMDS=("$@")
else
    CMDS=("${DEFAULT_CMDS[@]}")
fi

for cmd in "${CMDS[@]}"; do
    echo "Running: $cmd"
    adb shell "run-as com.termux sh -c 'cd $TERMUX_HOME && export PATH=$TERMUX_PREFIX/bin:\$PATH && export HOME=$TERMUX_HOME && export PREFIX=$TERMUX_PREFIX && $cmd'"
    echo ""
done

adb shell && run-as com.termux 