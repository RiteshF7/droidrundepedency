#!/bin/bash
# automated-build-in-termux.sh
# Automated build using ADB to execute commands in Termux context

set -e

ADB="${LOCALAPPDATA}/Android/Sdk/platform-tools/adb.exe"
TERMUX_PACKAGE="com.termux"
TERMUX_BIN="/data/data/${TERMUX_PACKAGE}/files/usr/bin/bash"
TERMUX_HOME="/data/data/${TERMUX_PACKAGE}/files/home"

echo "=== Automated Build in Termux ==="
echo ""

# Check emulator
"$ADB" devices | grep -q "emulator" || {
    echo "❌ Error: No emulator detected"
    exit 1
}

echo "✅ Emulator detected"
echo ""

# Method 1: Try using run-as with proper Termux bash
echo "Attempting to execute build commands in Termux..."
echo ""

# Create a build script content
BUILD_SCRIPT="
cd ${TERMUX_HOME}
pkg update -y
pkg install -y python python-pip
pip install --upgrade pip wheel build setuptools
mkdir -p wheels
cd wheels

# Set parallelism limits to prevent memory exhaustion
export NINJAFLAGS=\"-j2\"
export MAKEFLAGS=\"-j2\"
export MAX_JOBS=2

# Download dependencies
pip download 'droidrun[google]' --dest . --prefer-binary --no-cache-dir --no-deps=false

# Build wheels from source distributions, prioritizing critical packages
echo \"Building critical dependencies first...\"
# Build pandas first (may need specific version for constraints)
for src in pandas*.tar.gz; do
    if [ -f \"\$src\" ]; then
        wheel_file=\${src%.tar.gz}.whl
        if [ ! -f \"\$wheel_file\" ]; then
            echo \"Building: \$src (critical dependency)\"
            pip wheel --no-deps --wheel-dir . \"\$src\" || echo \"Failed: \$src\"
        fi
    fi
done

# Build other wheels
for src in *.tar.gz; do
    if [ -f \"\$src\" ] && [[ ! \"\$src\" =~ ^pandas ]]; then
        wheel_file=\${src%.tar.gz}.whl
        if [ ! -f \"\$wheel_file\" ]; then
            echo \"Building: \$src\"
            pip wheel --no-deps --wheel-dir . \"\$src\" || echo \"Failed: \$src\"
        fi
    fi
done

# Install pre-built wheels FIRST to satisfy dependencies (especially pandas)
echo \"Installing pre-built wheels to satisfy dependencies...\"
cd ..

# Uninstall any conflicting pandas version first
echo \"Checking for version conflicts with pandas...\"
pip uninstall -y pandas 2>/dev/null || true

# Install pandas from wheels first (this ensures correct version is used)
if ls wheels/pandas*.whl 1>/dev/null 2>&1; then
    echo \"Installing pandas from pre-built wheel...\"
    pip install --find-links wheels --no-index wheels/pandas*.whl 2>/dev/null || {
        echo \"Installing pandas with version constraint...\"
        pip install --find-links wheels 'pandas<2.3.0' 2>/dev/null || true
    }
fi

# Install other critical dependencies from wheels
echo \"Installing other critical dependencies from wheels...\"
for wheel in wheels/numpy*.whl wheels/scipy*.whl wheels/scikit*.whl; do
    if [ -f \"\$wheel\" ]; then
        echo \"Installing: \$(basename \$wheel)\"
        pip install --find-links wheels --no-index \"\$wheel\" 2>/dev/null || true
    fi
done

# Now install main package using pre-built wheels (prevents rebuilding)
echo \"Installing droidrun[google] using pre-built wheels...\"
pip install 'droidrun[google]' --find-links wheels --no-index || {
    echo \"Some packages not found locally, trying with PyPI fallback...\"
    pip install 'droidrun[google]' --find-links wheels
}

echo \"Build complete! Wheels in: \$(pwd)/wheels\"
find wheels -name '*.whl' | wc -l
"

# Try to execute via run-as
echo "Executing build commands..."
"$ADB" shell "run-as ${TERMUX_PACKAGE} ${TERMUX_BIN} -c '${BUILD_SCRIPT}'" 2>&1 || {
    echo ""
    echo "⚠️  Direct execution failed. Trying alternative method..."
    echo ""
    
    # Alternative: Create a script file and execute it
    echo "Creating build script in Termux home..."
    
    # Push script via a method that works
    SCRIPT_CONTENT="cd ~ && pkg update -y && pkg install -y python python-pip && pip install --upgrade pip wheel build setuptools && export NINJAFLAGS=\"-j2\" && export MAKEFLAGS=\"-j2\" && export MAX_JOBS=2 && mkdir -p ~/wheels && cd ~/wheels && pip download 'droidrun[google]' --dest . --prefer-binary --no-cache-dir --no-deps=false && for src in *.tar.gz; do [ -f \"\$src\" ] && [ ! -f \"\${src%.tar.gz}.whl\" ] && pip wheel --no-deps --wheel-dir . \"\$src\"; done && cd .. && pip install 'droidrun[google]' --find-links wheels && echo 'Build complete!'"
    
    # Try to write script via echo in Termux
    "$ADB" shell "run-as ${TERMUX_PACKAGE} sh -c 'echo \"${SCRIPT_CONTENT}\" > ${TERMUX_HOME}/build.sh && chmod +x ${TERMUX_HOME}/build.sh && ${TERMUX_BIN} ${TERMUX_HOME}/build.sh'" 2>&1 || {
        echo ""
        echo "❌ Automated execution not possible due to Android security restrictions"
        echo ""
        echo "Please use one of these methods:"
        echo ""
        echo "Method 1: Manual execution in Termux app"
        echo "  1. Open Termux app on emulator"
        echo "  2. Copy commands from termux-build-commands.txt"
        echo "  3. Paste and run in Termux"
        echo ""
        echo "Method 2: Use the automated batch script with manual steps"
        echo "  Run: bat-scripts\\build-droidrun-wheels-emulator.bat"
        echo ""
        exit 1
    }
}

echo ""
echo "✅ Build commands executed!"
echo ""
echo "Step 3: Copying wheels..."
mkdir -p termux-packages/wheels/aarch64

"$ADB" pull "${TERMUX_HOME}/wheels" "termux-packages/wheels/aarch64/" 2>&1 || {
    echo ""
    echo "⚠️  Copy wheels manually with:"
    echo "  adb pull ${TERMUX_HOME}/wheels termux-packages/wheels/aarch64/"
}

echo ""
echo "✅ Done!"




