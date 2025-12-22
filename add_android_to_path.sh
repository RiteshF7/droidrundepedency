#!/bin/bash
# Add Android SDK paths to PATH for Git Bash
# This adds to ~/.bashrc for permanent use

EMULATOR_PATH="$LOCALAPPDATA/Android/Sdk/emulator"
PLATFORM_TOOLS_PATH="$LOCALAPPDATA/Android/Sdk/platform-tools"
BASHRC="$HOME/.bashrc"

echo "Adding Android SDK paths to Git Bash PATH..."

# Check if paths exist
if [ ! -d "$EMULATOR_PATH" ]; then
    echo "Warning: Emulator path not found: $EMULATOR_PATH"
    exit 1
fi

if [ ! -d "$PLATFORM_TOOLS_PATH" ]; then
    echo "Warning: Platform-tools path not found: $PLATFORM_TOOLS_PATH"
    exit 1
fi

# Create .bashrc if it doesn't exist
if [ ! -f "$BASHRC" ]; then
    touch "$BASHRC"
fi

# Check if already added
if grep -q "Android/Sdk/emulator" "$BASHRC"; then
    echo "Android SDK paths already in ~/.bashrc"
else
    echo "" >> "$BASHRC"
    echo "# Android SDK paths" >> "$BASHRC"
    echo "export PATH=\"\$LOCALAPPDATA/Android/Sdk/emulator:\$LOCALAPPDATA/Android/Sdk/platform-tools:\$PATH\"" >> "$BASHRC"
    echo "Added Android SDK paths to ~/.bashrc"
fi

# Add to current session
export PATH="$EMULATOR_PATH:$PLATFORM_TOOLS_PATH:$PATH"

echo ""
echo "Android SDK paths added to PATH!"
echo "For current session: Already active"
echo "For future sessions: Added to ~/.bashrc"
echo ""
echo "You can now use:"
echo "  emulator -list-avds"
echo "  emulator -avd <avd_name>"
echo "  adb devices"



