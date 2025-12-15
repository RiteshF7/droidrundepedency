#!/bin/bash
# retry-failed-packages.sh
# Retry building packages that failed during installation

ADB="${LOCALAPPDATA}/Android/Sdk/platform-tools/adb.exe"
TERMUX_BASH="/data/data/com.termux/files/usr/bin/bash"

echo "=== Retrying Failed Packages ==="
echo ""

# Check emulator
if ! "$ADB" devices | grep -q "emulator"; then
    echo "❌ Error: No emulator detected"
    exit 1
fi

echo "✅ Emulator detected"
echo ""

# Copy updated script to Termux
echo "Updating installation script in Termux..."
cat scripts/install-droidrun-dependencies.sh | "$ADB" shell "run-as com.termux sh -c 'export HOME=/data/data/com.termux/files/home && cat > \$HOME/install-droidrun-dependencies.sh && chmod +x \$HOME/install-droidrun-dependencies.sh && echo \"Script updated\"'"

echo ""
echo "=== Retrying scikit-learn and pyarrow ==="
echo ""

"$ADB" shell "run-as com.termux $TERMUX_BASH -c '
export PREFIX=/data/data/com.termux/files/usr
export HOME=/data/data/com.termux/files/home
export PATH=\$PREFIX/bin:\$PATH
export NINJAFLAGS="-j2"
export MAKEFLAGS="-j2"
export MAX_JOBS=2
export PYTHON=\$(which python3)

cd \$HOME/wheels || exit 1

echo "=== Retrying scikit-learn ==="
# Try to build scikit-learn with fixes
if pip download scikit-learn --dest . --no-cache-dir 2>&1; then
    source_file=\$(ls -t scikit-learn-*.tar.gz 2>/dev/null | head -1)
    if [ -n "\$source_file" ] && [ -f "\$source_file" ]; then
        echo "Extracting and fixing source..."
        extract_dir="\$HOME/wheels/sklearn-extract-\$\$"
        mkdir -p "\$extract_dir"
        tar -xzf "\$source_file" -C "\$extract_dir" 2>/dev/null
        
        sklearn_dir=\$(ls -d "\$extract_dir"/scikit-learn-* 2>/dev/null | head -1)
        if [ -n "\$sklearn_dir" ] && [ -d "\$sklearn_dir" ]; then
            version_script="\$sklearn_dir/sklearn/_build_utils/version.py"
            if [ -f "\$version_script" ]; then
                chmod +x "\$version_script"
                if ! head -1 "\$version_script" | grep -q "^#!"; then
                    sed -i "1i#!/usr/bin/env python3" "\$version_script"
                fi
            fi
            
            cd "\$extract_dir" || exit 1
            tar -czf "\$HOME/wheels/\$source_file" "\$(basename "\$sklearn_dir")" 2>/dev/null
            cd "\$HOME/wheels" || exit 1
            rm -rf "\$extract_dir"
        fi
        
        echo "Building wheel..."
        if pip wheel --no-deps --wheel-dir . "\$source_file" 2>&1; then
            wheel_file=\$(ls -t scikit-learn-*.whl 2>/dev/null | head -1)
            if [ -n "\$wheel_file" ] && [ -f "\$wheel_file" ]; then
                echo "Installing scikit-learn..."
                pip install --find-links . --no-index "\$wheel_file" && echo "✅ scikit-learn installed successfully" || echo "❌ Installation failed"
            fi
        fi
    fi
fi

echo ""
echo "=== Retrying pyarrow ==="
# Try pyarrow
if pip download pyarrow --dest . --no-cache-dir 2>&1; then
    source_file=\$(ls -t pyarrow-*.tar.gz 2>/dev/null | head -1)
    if [ -n "\$source_file" ] && [ -f "\$source_file" ]; then
        echo "Building pyarrow wheel..."
        if pip wheel --no-deps --wheel-dir . "\$source_file" 2>&1; then
            wheel_file=\$(ls -t pyarrow-*.whl 2>/dev/null | head -1)
            if [ -n "\$wheel_file" ] && [ -f "\$wheel_file" ]; then
                echo "Installing pyarrow..."
                pip install --find-links . --no-index "\$wheel_file" && echo "✅ pyarrow installed successfully" || echo "❌ Installation failed"
            fi
        fi
    fi
fi

echo ""
echo "=== Checking installed packages ==="
pip list | grep -E "scikit-learn|pyarrow" || echo "Packages not found"
'

