#!/usr/bin/env bash
# Script to find all .source.gz and .whl files in Termux and organize them into folders

TERMUX_HOME="/data/data/com.termux/files/home"
TERMUX_PREFIX="/data/data/com.termux/files/usr"

echo "=========================================="
echo "Finding and organizing package files in Termux"
echo "=========================================="
echo ""

# Check if ADB is available
if ! command -v adb >/dev/null 2>&1; then
    echo "Error: ADB not found. Please install Android SDK Platform Tools"
    exit 1
fi

# Check if device is connected
DEVICES=$(adb devices | grep -v "List" | grep "device$" | wc -l)
if [ "$DEVICES" -eq 0 ]; then
    echo "Error: No Android device connected via ADB"
    exit 1
fi

echo "[OK] Android device connected"
echo ""

echo "Executing search and organization in Termux..."
echo ""

# Execute commands step by step using the runastermux.sh pattern
adb shell "run-as com.termux sh -c 'cd $TERMUX_HOME && export PATH=$TERMUX_PREFIX/bin:\$PATH && export HOME=$TERMUX_HOME && export PREFIX=$TERMUX_PREFIX && export PIP_CACHE_DIR=\$HOME/.cache/pip && echo \"Creating directories...\" && mkdir -p sources wheels'"

echo "Searching for source files (.tar.gz, .source.gz)..."
adb shell "run-as com.termux sh -c 'cd $TERMUX_HOME && export PATH=$TERMUX_PREFIX/bin:\$PATH && export HOME=$TERMUX_HOME && export PREFIX=$TERMUX_PREFIX && find \$HOME -type f \( -name \"*.tar.gz\" -o -name \"*.source.gz\" \) 2>/dev/null | while read file; do echo \"Found source: \$file\"; cp \"\$file\" sources/ 2>/dev/null || true; done'"

echo "Searching for wheel files (.whl)..."
adb shell "run-as com.termux sh -c 'cd $TERMUX_HOME && export PATH=$TERMUX_PREFIX/bin:\$PATH && export HOME=$TERMUX_HOME && export PREFIX=$TERMUX_PREFIX && find \$HOME -type f -name \"*.whl\" 2>/dev/null | while read file; do echo \"Found wheel: \$file\"; cp \"\$file\" wheels/ 2>/dev/null || true; done'"

echo "Searching in pip cache..."
adb shell "run-as com.termux sh -c 'cd $TERMUX_HOME && export PATH=$TERMUX_PREFIX/bin:\$PATH && export HOME=$TERMUX_HOME && export PREFIX=$TERMUX_PREFIX && export PIP_CACHE_DIR=\$HOME/.cache/pip && if [ -d \"\$PIP_CACHE_DIR\" ]; then find \"\$PIP_CACHE_DIR\" -type f \( -name \"*.tar.gz\" -o -name \"*.source.gz\" \) 2>/dev/null | while read file; do echo \"Found source in cache: \$file\"; cp \"\$file\" sources/ 2>/dev/null || true; done; find \"\$PIP_CACHE_DIR\" -type f -name \"*.whl\" 2>/dev/null | while read file; do echo \"Found wheel in cache: \$file\"; cp \"\$file\" wheels/ 2>/dev/null || true; done; fi'"

echo ""
echo "Getting summary..."
adb shell "run-as com.termux sh -c 'cd $TERMUX_HOME && export PATH=$TERMUX_PREFIX/bin:\$PATH && export HOME=$TERMUX_HOME && export PREFIX=$TERMUX_PREFIX && echo \"Summary:\" && echo \"Sources found: \$(ls -1 sources/ 2>/dev/null | wc -l)\" && echo \"Wheels found: \$(ls -1 wheels/ 2>/dev/null | wc -l)\" && echo \"\" && echo \"Files organized in:\" && echo \"  Sources: \$HOME/sources/\" && echo \"  Wheels: \$HOME/wheels/\"'"

echo ""
echo "=========================================="
echo "Done!"
echo "=========================================="

