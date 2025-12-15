#!/bin/bash
# build-with-progress.sh - Build with visible progress and logs

set -e

ADB="${LOCALAPPDATA}/Android/Sdk/platform-tools/adb.exe"
TERMUX_BASH="/data/data/com.termux/files/usr/bin/bash"
TERMUX_HOME="/data/data/com.termux/files/home"
LOG_FILE="build-progress.log"

echo "=========================================="
echo "  Building droidrun[google] wheels"
echo "  Progress will be shown in real-time"
echo "=========================================="
echo ""
echo "Log file: $LOG_FILE"
echo ""

# Function to show progress with timestamp
show_progress() {
    echo "[$(date '+%H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Check emulator
show_progress "Checking emulator connection..."
"$ADB" devices | grep -q "emulator" || {
    echo "❌ Error: No emulator detected" | tee -a "$LOG_FILE"
    exit 1
}
show_progress "✅ Emulator connected"

# Get architecture
ARCH=$("$ADB" shell "run-as com.termux $TERMUX_BASH -c 'uname -m'" | tr -d '\r\n ')
show_progress "Architecture: $ARCH"
echo ""

# Create log file
> "$LOG_FILE"

# Step 1: Setup
show_progress "Step 1/6: Ensuring wheels directory exists..."
"$ADB" shell "run-as com.termux $TERMUX_BASH -c 'export HOME=$TERMUX_HOME && mkdir -p \$HOME/wheels && echo \"Directory ready\"'" 2>&1 | tee -a "$LOG_FILE"
echo ""

# Step 2: Download
show_progress "Step 2/6: Downloading droidrun[google] and all dependencies..."
echo "This may take 5-10 minutes. Please wait..."
echo ""

"$ADB" shell "run-as com.termux $TERMUX_BASH -c '
export PREFIX=/data/data/com.termux/files/usr
export HOME=$TERMUX_HOME
export PATH=\$PREFIX/bin:\$PATH

cd \$HOME/wheels

echo \"Starting download...\"
echo \"Downloading packages...\"

echo \"Downloading packages (this may take several minutes)...\"
pip download \"droidrun[google]\" --dest . --prefer-binary --no-cache-dir --no-binary :all: 2>&1 || \
pip download \"droidrun[google]\" --dest . --no-cache-dir 2>&1

echo \"\"
echo \"Download complete!\"
echo \"Checking downloaded files...\"
echo \"Wheel files: \$(find . -maxdepth 1 -name '*.whl' 2>/dev/null | wc -l)\"
echo \"Source files: \$(find . -maxdepth 1 -name '*.tar.gz' 2>/dev/null | wc -l)\"
ls -lh *.whl *.tar.gz 2>/dev/null | head -20
'" 2>&1 | while IFS= read -r line; do
    echo "[$(date '+%H:%M:%S')] $line" | tee -a "$LOG_FILE"
done

echo ""
show_progress "✅ Download step complete"
echo ""

# Step 3: Check what was downloaded
show_progress "Step 3/6: Checking downloaded files..."
"$ADB" shell "run-as com.termux $TERMUX_BASH -c '
export HOME=$TERMUX_HOME
cd \$HOME/wheels

echo \"Wheels already downloaded:\"
find . -maxdepth 1 -name \"*.whl\" | wc -l

echo \"Source packages to build:\"
find . -maxdepth 1 -name \"*.tar.gz\" | wc -l

echo \"\"
echo \"Listing files:\"
ls -lh *.whl *.tar.gz 2>/dev/null | head -10
'" 2>&1 | while IFS= read -r line; do
    echo "[$(date '+%H:%M:%S')] $line" | tee -a "$LOG_FILE"
done

echo ""

# Step 4: Build wheels
show_progress "Step 4/6: Building wheels from source packages..."
echo "This will take 10-30 minutes depending on packages..."
echo "Progress will be shown below:"
echo ""

"$ADB" shell "run-as com.termux $TERMUX_BASH -c '
export PREFIX=/data/data/com.termux/files/usr
export HOME=$TERMUX_HOME
export PATH=\$PREFIX/bin:\$PATH

cd \$HOME/wheels

count=0
total=\$(find . -maxdepth 1 -name \"*.tar.gz\" | wc -l)
echo \"Total packages to build: \$total\"
echo \"\"

for src in *.tar.gz; do
    if [ -f \"\$src\" ]; then
        wheel_file=\${src%.tar.gz}.whl
        if [ ! -f \"\$wheel_file\" ]; then
            count=\$((count + 1))
            echo \"[BUILD \$count/\$total] Building: \$src\"
            echo \"----------------------------------------\"
            
            if pip wheel --no-deps --wheel-dir . \"\$src\" 2>&1; then
                echo \"✅ Successfully built: \$src\"
            else
                echo \"❌ Failed to build: \$src\"
            fi
            echo \"\"
        fi
    fi
done

echo \"Build process complete!\"
'" 2>&1 | while IFS= read -r line; do
    timestamp="[$(date '+%H:%M:%S')]"
    echo "$timestamp $line" | tee -a "$LOG_FILE"
done

echo ""

# Step 5: Final summary
show_progress "Step 5/6: Generating summary..."
"$ADB" shell "run-as com.termux $TERMUX_BASH -c '
export HOME=$TERMUX_HOME
cd \$HOME/wheels

echo \"========================================\"
echo \"           BUILD SUMMARY\"
echo \"========================================\"
echo \"Architecture: $ARCH\"
echo \"\"
echo \"Total wheel files: \$(find . -maxdepth 1 -name \"*.whl\" | wc -l)\"
echo \"Total source files: \$(find . -maxdepth 1 -name \"*.tar.gz\" | wc -l)\"
echo \"Total size: \$(du -sh . | awk \"{print \\\$1}\")\"
echo \"\"
echo \"Top 10 largest wheels:\"
ls -lhS *.whl 2>/dev/null | head -10 | awk \"{print \\\$9, \\\$5}\"
echo \"========================================\"
'" 2>&1 | while IFS= read -r line; do
    echo "$line" | tee -a "$LOG_FILE"
done

echo ""

# Step 6: Copy to Windows
show_progress "Step 6/6: Copying wheels to Windows..."
DEST_DIR="termux-packages/wheels/${ARCH}"
mkdir -p "$DEST_DIR"

show_progress "Copying from emulator to: $DEST_DIR"
"$ADB" pull "${TERMUX_HOME}/wheels" "$DEST_DIR/" 2>&1 | tee -a "$LOG_FILE"

if [ $? -eq 0 ]; then
    echo ""
    show_progress "✅ Successfully copied wheels!"
    echo ""
    echo "=========================================="
    echo "  BUILD COMPLETE!"
    echo "=========================================="
    echo ""
    echo "Wheels location: $DEST_DIR"
    echo "Total wheels: $(find "$DEST_DIR" -name "*.whl" 2>/dev/null | wc -l)"
    echo "Log file: $LOG_FILE"
    echo ""
else
    echo ""
    show_progress "⚠️  Failed to copy automatically"
    echo "Copy manually with:"
    echo "  adb pull ${TERMUX_HOME}/wheels $DEST_DIR/"
    echo ""
fi

echo ""
echo "View full log: cat $LOG_FILE"
echo ""

