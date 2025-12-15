#!/bin/bash
# execute-build-in-termux.sh
# Execute build commands directly in Termux using run-as

set -e

ADB="${LOCALAPPDATA}/Android/Sdk/platform-tools/adb.exe"
TERMUX_PACKAGE="com.termux"
TERMUX_BASH="/data/data/${TERMUX_PACKAGE}/files/usr/bin/bash"
TERMUX_HOME="/data/data/${TERMUX_PACKAGE}/files/home"

echo "=== Executing Build in Termux ==="
echo ""

# Step 1: Update packages
echo "Step 1/6: Updating packages..."
"$ADB" shell "run-as ${TERMUX_PACKAGE} ${TERMUX_BASH} -c 'pkg update -y'" 2>&1 | tail -10

# Step 2: Install Python
echo ""
echo "Step 2/6: Installing Python and pip..."
"$ADB" shell "run-as ${TERMUX_PACKAGE} ${TERMUX_BASH} -c 'pkg install -y python python-pip'" 2>&1 | tail -10

# Step 3: Install build tools
echo ""
echo "Step 3/6: Installing build tools..."
"$ADB" shell "run-as ${TERMUX_PACKAGE} ${TERMUX_BASH} -c 'pip install --upgrade pip wheel build setuptools'" 2>&1 | tail -10

# Step 4: Create wheels directory
echo ""
echo "Step 4/6: Creating wheels directory..."
"$ADB" shell "run-as ${TERMUX_PACKAGE} ${TERMUX_BASH} -c 'mkdir -p ${TERMUX_HOME}/wheels && cd ${TERMUX_HOME}/wheels && pwd'"

# Step 5: Download packages
echo ""
echo "Step 5/6: Downloading droidrun[google] and dependencies..."
echo "This may take a few minutes..."
"$ADB" shell "run-as ${TERMUX_PACKAGE} ${TERMUX_BASH} -c 'cd ${TERMUX_HOME}/wheels && pip download \"droidrun[google]\" --dest . --prefer-binary --no-cache-dir --no-deps=false'" 2>&1 | tail -20

# Step 6: Build wheels
echo ""
echo "Step 6/6: Building wheels from source..."
echo "This will take 10-30 minutes depending on packages..."
"$ADB" shell "run-as ${TERMUX_PACKAGE} ${TERMUX_BASH} -c 'cd ${TERMUX_HOME}/wheels && for src in *.tar.gz; do if [ -f \"\$src\" ]; then wheel_file=\${src%.tar.gz}.whl; if [ ! -f \"\$wheel_file\" ]; then echo \"Building: \$src\"; pip wheel --no-deps --wheel-dir . \"\$src\" || echo \"Failed: \$src\"; fi; fi; done'" 2>&1 | grep -E "Building|Successfully|Failed|ERROR" || echo "Build in progress..."

# Summary
echo ""
echo "=== Build Summary ==="
"$ADB" shell "run-as ${TERMUX_PACKAGE} ${TERMUX_BASH} -c 'cd ${TERMUX_HOME}/wheels && echo \"Wheels: \$(find . -name \"*.whl\" | wc -l)\" && echo \"Sources: \$(find . -name \"*.tar.gz\" | wc -l)\" && du -sh .'"

echo ""
echo "✅ Build process initiated!"
echo ""
echo "Next: Copy wheels to Windows with:"
echo "  bat-scripts\\copy-wheels-from-emulator.bat"




