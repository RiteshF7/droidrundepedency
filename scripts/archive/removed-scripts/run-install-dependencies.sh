#!/bin/bash
# run-install-dependencies.sh
# Helper script to copy and run install-droidrun-dependencies.sh in Termux

set -e

ADB="${LOCALAPPDATA}/Android/Sdk/platform-tools/adb.exe"
TERMUX_PACKAGE="com.termux"
TERMUX_HOME="/data/data/${TERMUX_PACKAGE}/files/home"
TERMUX_BASH="/data/data/${TERMUX_PACKAGE}/files/usr/bin/bash"
SCRIPT_NAME="install-droidrun-dependencies.sh"
LOCAL_SCRIPT="scripts/${SCRIPT_NAME}"
TEMP_LOCATION="/data/local/tmp/${SCRIPT_NAME}"

echo "=== Running droidrun[google] Dependency Installation in Termux ==="
echo ""

# Check if ADB is available
if [ ! -f "$ADB" ]; then
    echo "❌ Error: ADB not found at $ADB"
    echo "   Please ensure Android SDK platform-tools are installed"
    exit 1
fi

# Check if local script exists
if [ ! -f "$LOCAL_SCRIPT" ]; then
    echo "❌ Error: Script not found at $LOCAL_SCRIPT"
    exit 1
fi

# Check emulator connection
echo "Checking emulator connection..."
if ! "$ADB" devices | grep -q "emulator"; then
    echo "❌ Error: No emulator detected"
    echo "   Please start an Android emulator first"
    exit 1
fi

echo "✅ Emulator detected"
echo ""

# Step 1: Push script to temporary location
echo "Step 1: Copying script to emulator..."
"$ADB" push "$LOCAL_SCRIPT" "$TEMP_LOCATION" || {
    echo "❌ Error: Failed to push script to emulator"
    exit 1
}
echo "✅ Script copied to $TEMP_LOCATION"
echo ""

# Step 2: Copy script to Termux home directory and make executable
echo "Step 2: Installing script in Termux..."
"$ADB" shell "run-as $TERMUX_PACKAGE sh -c '
    export PREFIX=/data/data/com.termux/files/usr
    export HOME=/data/data/com.termux/files/home
    export PATH=\$PREFIX/bin:\$PATH
    
    # Copy script to Termux home
    cp /data/local/tmp/$SCRIPT_NAME \$HOME/$SCRIPT_NAME
    
    # Make it executable
    chmod +x \$HOME/$SCRIPT_NAME
    
    echo \"Script installed at: \$HOME/$SCRIPT_NAME\"
'" || {
    echo "❌ Error: Failed to install script in Termux"
    exit 1
}
echo "✅ Script installed in Termux home directory"
echo ""

# Step 3: Run the script
echo "Step 3: Running dependency installation script..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "⚠️  This will take a long time (2-4 hours depending on your system)"
echo "⚠️  The script will install all dependencies step by step"
echo "⚠️  Progress will be logged to ~/wheels/install-dependencies.log"
echo ""
echo "Starting installation..."
echo ""

"$ADB" shell "run-as $TERMUX_PACKAGE $TERMUX_BASH -c '
    export PREFIX=/data/data/com.termux/files/usr
    export HOME=/data/data/com.termux/files/home
    export PATH=\$PREFIX/bin:\$PATH
    
    # Set parallelism limits
    export NINJAFLAGS=\"-j2\"
    export MAKEFLAGS=\"-j2\"
    export MAX_JOBS=2
    
    # Change to home directory
    cd \$HOME
    
    # Run the installation script
    ./$SCRIPT_NAME
'"

EXIT_CODE=$?

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ $EXIT_CODE -eq 0 ]; then
    echo "✅ Installation completed successfully!"
    echo ""
    echo "Next steps:"
    echo "  1. Check the log file: ~/wheels/install-dependencies.log"
    echo "  2. Verify installation: pip list | grep -E 'pandas|numpy|scipy|scikit-learn|jiter|droidrun'"
    echo "  3. Test imports: python -c 'import pandas, numpy, scipy, sklearn, jiter, droidrun'"
else
    echo "❌ Installation completed with errors (exit code: $EXIT_CODE)"
    echo ""
    echo "Please check the log file for details:"
    echo "  ~/wheels/install-dependencies.log"
    echo ""
    echo "You can view the log with:"
    echo "  adb shell \"run-as com.termux sh -c 'cat ~/wheels/install-dependencies.log'\""
fi

echo ""

