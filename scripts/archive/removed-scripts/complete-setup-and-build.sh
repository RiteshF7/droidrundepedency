#!/bin/bash
# complete-setup-and-build.sh
# Complete setup of Termux and build droidrun wheels

set -e

ADB="${LOCALAPPDATA}/Android/Sdk/platform-tools/adb.exe"
TERMUX_PACKAGE="com.termux"
TERMUX_BASH="/data/data/${TERMUX_PACKAGE}/files/usr/bin/bash"
TERMUX_HOME="/data/data/${TERMUX_PACKAGE}/files/home"
TERMUX_PREFIX="/data/data/${TERMUX_PACKAGE}/files/usr"

echo "=== Complete Termux Setup and Build ==="
echo ""

# Check emulator
"$ADB" devices | grep -q "emulator" || {
    echo "❌ Error: No emulator detected"
    exit 1
}

# Get architecture
ARCH=$("$ADB" shell "run-as ${TERMUX_PACKAGE} ${TERMUX_BASH} -c 'uname -m'" | tr -d '\r\n ')
echo "Detected architecture: $ARCH"
echo ""

# Step 1: Initialize Termux package manager
echo "Step 1/7: Initializing Termux package manager..."
"$ADB" shell "run-as ${TERMUX_PACKAGE} ${TERMUX_BASH} -c 'cd ${TERMUX_HOME} && export PREFIX=${TERMUX_PREFIX} && ${TERMUX_PREFIX}/bin/apt update'" 2>&1 | tail -10 || {
    echo "Note: If this fails, you may need to open Termux app first to initialize"
}

# Step 2: Install termux-tools (includes pkg command)
echo ""
echo "Step 2/7: Installing termux-tools..."
"$ADB" shell "run-as ${TERMUX_PACKAGE} ${TERMUX_BASH} -c 'export PREFIX=${TERMUX_PREFIX} && export HOME=${TERMUX_HOME} && ${TERMUX_PREFIX}/bin/apt install -y termux-tools'" 2>&1 | tail -10 || {
    echo "Warning: termux-tools installation may have failed"
    echo "You may need to open Termux app once to initialize"
}

# Step 3: Update packages using pkg
echo ""
echo "Step 3/7: Updating packages..."
"$ADB" shell "run-as ${TERMUX_PACKAGE} ${TERMUX_BASH} -c 'export PREFIX=${TERMUX_PREFIX} && export HOME=${TERMUX_HOME} && export PATH=\$PREFIX/bin:\$PATH && pkg update -y'" 2>&1 | tail -10

# Step 4: Install Python
echo ""
echo "Step 4/7: Installing Python and pip..."
"$ADB" shell "run-as ${TERMUX_PACKAGE} ${TERMUX_BASH} -c 'export PREFIX=${TERMUX_PREFIX} && export HOME=${TERMUX_HOME} && export PATH=\$PREFIX/bin:\$PATH && pkg install -y python python-pip'" 2>&1 | tail -10

# Step 5: Install build tools
echo ""
echo "Step 5/7: Installing Python build tools..."
"$ADB" shell "run-as ${TERMUX_PACKAGE} ${TERMUX_BASH} -c 'export PREFIX=${TERMUX_PREFIX} && export HOME=${TERMUX_HOME} && export PATH=\$PREFIX/bin:\$PATH && pip install --upgrade pip wheel build setuptools'" 2>&1 | tail -10

# Step 6: Create wheels directory and download
echo ""
echo "Step 6/7: Downloading droidrun[google] and dependencies..."
echo "This may take 5-10 minutes..."
"$ADB" shell "run-as ${TERMUX_PACKAGE} ${TERMUX_BASH} -c 'export PREFIX=${TERMUX_PREFIX} && export HOME=${TERMUX_HOME} && export PATH=\$PREFIX/bin:\$PATH && mkdir -p ${TERMUX_HOME}/wheels && cd ${TERMUX_HOME}/wheels && pip download \"droidrun[google]\" --dest . --prefer-binary --no-cache-dir'" 2>&1 | tail -20

# Step 7: Build wheels
echo ""
echo "Step 7/7: Building wheels from source..."
echo "This will take 10-30 minutes depending on packages..."
"$ADB" shell "run-as ${TERMUX_PACKAGE} ${TERMUX_BASH} -c 'export PREFIX=${TERMUX_PREFIX} && export HOME=${TERMUX_HOME} && export PATH=\$PREFIX/bin:\$PATH && cd ${TERMUX_HOME}/wheels && for src in *.tar.gz; do if [ -f \"\$src\" ]; then wheel_file=\${src%.tar.gz}.whl; if [ ! -f \"\$wheel_file\" ]; then echo \"Building: \$src\"; pip wheel --no-deps --wheel-dir . \"\$src\" || echo \"Failed: \$src\"; fi; fi; done'" 2>&1 | grep -E "Building|Successfully|Failed|ERROR|Building wheel" || echo "Build in progress..."

# Final summary
echo ""
echo "=== Final Summary ==="
"$ADB" shell "run-as ${TERMUX_PACKAGE} ${TERMUX_BASH} -c 'export PREFIX=${TERMUX_PREFIX} && export HOME=${TERMUX_HOME} && export PATH=\$PREFIX/bin:\$PATH && cd ${TERMUX_HOME}/wheels && echo \"Architecture: $ARCH\" && echo \"Wheels: \$(find . -maxdepth 1 -name \"*.whl\" 2>/dev/null | wc -l)\" && echo \"Sources: \$(find . -maxdepth 1 -name \"*.tar.gz\" 2>/dev/null | wc -l)\" && du -sh . 2>/dev/null'"

echo ""
echo "✅ Build process complete!"
echo ""
echo "Copy wheels to Windows:"
echo "  mkdir -p termux-packages/wheels/${ARCH}"
echo "  adb pull ${TERMUX_HOME}/wheels termux-packages/wheels/${ARCH}/"

