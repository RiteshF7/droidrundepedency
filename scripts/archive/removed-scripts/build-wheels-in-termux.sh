#!/bin/bash
# build-wheels-in-termux.sh
# Build wheels by executing commands in Termux app context

set -e

ADB="${LOCALAPPDATA}/Android/Sdk/platform-tools/adb.exe"
TERMUX_PACKAGE="com.termux"
TERMUX_DIR="/data/data/${TERMUX_PACKAGE}/files"
TERMUX_HOME="${TERMUX_DIR}/home"

echo "=== Building droidrun wheels in Termux ==="
echo ""

# Check emulator
"$ADB" devices | grep -q "emulator" || {
    echo "❌ Error: No emulator detected"
    exit 1
}

echo "✅ Emulator detected"
echo ""

# Create a command script that will be executed in Termux
cat > /tmp/termux-build-commands.sh << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
set -e

echo "=== Building droidrun[google] wheels ==="

# Update packages
echo "Updating packages..."
pkg update -y

# Install dependencies
echo "Installing Python and build tools..."
pkg install -y python python-pip

# Install build tools
echo "Installing pip build tools..."
pip install --upgrade pip wheel build setuptools

# Create wheels directory
cd ~
mkdir -p wheels
cd wheels

# Download and build
echo "Downloading droidrun[google] and dependencies..."
pip download 'droidrun[google]' --dest . --prefer-binary --no-cache-dir --no-deps=false

# Build wheels from source
echo "Building wheels from source..."
for src in *.tar.gz; do
    if [ -f "$src" ]; then
        wheel_file="${src%.tar.gz}.whl"
        if [ ! -f "$wheel_file" ]; then
            echo "Building: $src"
            pip wheel --no-deps --wheel-dir . "$src" || echo "Warning: Failed to build $src"
        fi
    fi
done

# Summary
echo ""
echo "=== Build Summary ==="
echo "Wheels: $(find . -name '*.whl' | wc -l)"
echo "Location: $(pwd)"
echo ""
echo "✅ Build complete!"
EOF

echo "Step 1: Opening Termux app..."
"$ADB" shell am start -n com.termux/.HomeActivity

echo "Waiting for Termux to initialize..."
sleep 3

echo ""
echo "Step 2: Executing build commands in Termux..."
echo "Note: This will execute commands directly in Termux's shell"
echo ""

# Execute commands using run-as or via Termux's executable
"$ADB" shell "run-as ${TERMUX_PACKAGE} sh -c 'cd ${TERMUX_HOME} && ${TERMUX_DIR}/usr/bin/bash << \"ENDSCRIPT\"
pkg update -y
pkg install -y python python-pip
pip install --upgrade pip wheel build setuptools
mkdir -p wheels
cd wheels
pip download \"droidrun[google]\" --dest . --prefer-binary --no-cache-dir --no-deps=false
for src in *.tar.gz; do
    [ -f \"\$src\" ] && [ ! -f \"\${src%.tar.gz}.whl\" ] && pip wheel --no-deps --wheel-dir . \"\$src\"
done
echo \"Build complete!\"
ENDSCRIPT
'" || {
    echo ""
    echo "⚠️  Direct execution via run-as may not work due to security restrictions"
    echo ""
    echo "Please manually run these commands in Termux app:"
    echo ""
    echo "  pkg update -y"
    echo "  pkg install -y python python-pip"
    echo "  pip install --upgrade pip wheel build setuptools"
    echo "  mkdir -p ~/wheels && cd ~/wheels"
    echo "  pip download 'droidrun[google]' --dest . --prefer-binary --no-cache-dir --no-deps=false"
    echo "  for src in *.tar.gz; do [ -f \"\$src\" ] && pip wheel --no-deps --wheel-dir . \"\$src\"; done"
    echo ""
}

echo ""
echo "Step 3: After building, copy wheels with:"
echo "  adb pull /data/data/com.termux/files/home/wheels termux-packages/wheels/aarch64/"
echo ""




