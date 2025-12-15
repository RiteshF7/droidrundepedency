#!/bin/bash
# final-build-script.sh - Final working build script

ADB="${LOCALAPPDATA}/Android/Sdk/platform-tools/adb.exe"
TERMUX_BASH="/data/data/com.termux/files/usr/bin/bash"
TERMUX_HOME="/data/data/com.termux/files/home"

echo "=== Final Build Script ==="
echo ""

# Set up environment and build
"$ADB" shell "run-as com.termux $TERMUX_BASH -c '
export PREFIX=/data/data/com.termux/files/usr
export HOME=$TERMUX_HOME
export PATH=\$PREFIX/bin:\$PATH

cd \$HOME
mkdir -p wheels
cd wheels

echo \"Downloading droidrun[google] and dependencies...\"
pip download \"droidrun[google]\" --dest . --prefer-binary --no-cache-dir 2>&1 | tail -30

echo \"\"
echo \"Building wheels from source...\"
for src in *.tar.gz; do
    if [ -f \"\$src\" ]; then
        wheel_file=\${src%.tar.gz}.whl
        if [ ! -f \"\$wheel_file\" ]; then
            echo \"Building: \$src\"
            pip wheel --no-deps --wheel-dir . \"\$src\" 2>&1 | tail -3 || echo \"Failed: \$src\"
        fi
    fi
done

echo \"\"
echo \"=== Summary ===\"
echo \"Wheels: \$(find . -maxdepth 1 -name \"*.whl\" | wc -l)\"
echo \"Sources: \$(find . -maxdepth 1 -name \"*.tar.gz\" | wc -l)\"
du -sh .
'"




