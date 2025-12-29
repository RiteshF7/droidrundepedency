#!/usr/bin/env bash
# Generic script to copy files/folders FROM Termux TO laptop via ADB
# Usage: ./copy_from_termux.sh <termux_path> [local_destination]
# Example: ./copy_from_termux.sh wheels ~/Downloads/wheels
# Example: ./copy_from_termux.sh ~/myfile.txt ~/Downloads/

TERMUX_HOME="/data/data/com.termux/files/home"
TERMUX_PREFIX="/data/data/com.termux/files/usr"

# Check arguments
if [ $# -lt 1 ]; then
    echo "Usage: $0 <termux_path> [local_destination]"
    echo ""
    echo "Examples:"
    echo "  $0 wheels                    # Copy 'wheels' folder to ~/Downloads/wheels"
    echo "  $0 wheels ~/my_wheels       # Copy 'wheels' folder to ~/my_wheels"
    echo "  $0 ~/file.txt ~/Downloads/   # Copy file.txt to Downloads"
    echo "  $0 sources ~/backup/         # Copy 'sources' folder to ~/backup/sources"
    exit 1
fi

TERMUX_SOURCE="$1"
LOCAL_DEST="${2:-$HOME/Downloads/$(basename "$TERMUX_SOURCE")}"

# Remove leading ~/ or ./ from source path if present
TERMUX_SOURCE="${TERMUX_SOURCE#~/}"
TERMUX_SOURCE="${TERMUX_SOURCE#./}"
FULL_TERMUX_PATH="$TERMUX_HOME/$TERMUX_SOURCE"

echo "=========================================="
echo "Copying from Termux to Laptop"
echo "=========================================="
echo "Source (Termux): $FULL_TERMUX_PATH"
echo "Destination (Laptop): $LOCAL_DEST"
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

# Check if source exists in Termux
echo "Checking if source exists in Termux..."
SOURCE_EXISTS=$(adb shell "run-as com.termux sh -c 'cd $TERMUX_HOME && export PATH=$TERMUX_PREFIX/bin:\$PATH && test -e \"$FULL_TERMUX_PATH\" && echo exists || echo notfound'")

if [ "$SOURCE_EXISTS" != "exists" ]; then
    echo "Error: Source path does not exist in Termux: $FULL_TERMUX_PATH"
    echo ""
    echo "Listing contents of Termux home:"
    adb shell "run-as com.termux sh -c 'cd $TERMUX_HOME && export PATH=$TERMUX_PREFIX/bin:\$PATH && ls -la'"
    exit 1
fi

echo "[OK] Source found"
echo ""

# Create local destination directory
mkdir -p "$LOCAL_DEST"
if [ -f "$LOCAL_DEST" ]; then
    # If destination is a file, use its directory
    LOCAL_DEST="$(dirname "$LOCAL_DEST")"
fi

echo "Copying files..."
echo ""

# Method 1: Try direct stream via tar (works for files and folders)
echo "Method 1: Streaming via tar..."
if adb shell "run-as com.termux sh -c 'cd $TERMUX_HOME && export PATH=$TERMUX_PREFIX/bin:\$PATH && test -d \"$FULL_TERMUX_PATH\"'" | grep -q "0"; then
    # It's a directory
    adb shell "run-as com.termux sh -c 'cd $TERMUX_HOME && export PATH=$TERMUX_PREFIX/bin:\$PATH && cd \"$(dirname "$FULL_TERMUX_PATH")\" && tar czf - \"$(basename "$FULL_TERMUX_PATH")\" 2>/dev/null'" | tar xzf - -C "$LOCAL_DEST/" 2>/dev/null
    SUCCESS=$?
else
    # It's a file
    FILENAME=$(basename "$FULL_TERMUX_PATH")
    adb shell "run-as com.termux sh -c 'cd $TERMUX_HOME && export PATH=$TERMUX_PREFIX/bin:\$PATH && cat \"$FULL_TERMUX_PATH\"'" > "$LOCAL_DEST/$FILENAME" 2>/dev/null
    SUCCESS=$?
fi

if [ $SUCCESS -eq 0 ]; then
    echo "[OK] Files copied successfully via Method 1!"
else
    echo "Method 1 failed, trying Method 2: Base64 encoding..."
    
    # Method 2: Use base64 for individual files
    if adb shell "run-as com.termux sh -c 'cd $TERMUX_HOME && export PATH=$TERMUX_PREFIX/bin:\$PATH && test -f \"$FULL_TERMUX_PATH\"'" | grep -q "0"; then
        # Single file
        FILENAME=$(basename "$FULL_TERMUX_PATH")
        adb shell "run-as com.termux sh -c 'cd $TERMUX_HOME && export PATH=$TERMUX_PREFIX/bin:\$PATH && base64 \"$FULL_TERMUX_PATH\"'" | base64 -d > "$LOCAL_DEST/$FILENAME"
        SUCCESS=$?
    else
        # Directory - copy files one by one
        mkdir -p "$LOCAL_DEST/$(basename "$FULL_TERMUX_PATH")"
        adb shell "run-as com.termux sh -c 'cd $TERMUX_HOME && export PATH=$TERMUX_PREFIX/bin:\$PATH && find \"$FULL_TERMUX_PATH\" -type f'" | while read file_path; do
            if [ -n "$file_path" ]; then
                rel_path="${file_path#$FULL_TERMUX_PATH/}"
                dir_path="$(dirname "$rel_path")"
                filename="$(basename "$file_path")"
                mkdir -p "$LOCAL_DEST/$(basename "$FULL_TERMUX_PATH")/$dir_path"
                echo "Copying $rel_path..."
                adb shell "run-as com.termux sh -c 'cd $TERMUX_HOME && export PATH=$TERMUX_PREFIX/bin:\$PATH && base64 \"$file_path\"'" | base64 -d > "$LOCAL_DEST/$(basename "$FULL_TERMUX_PATH")/$dir_path/$filename"
            fi
        done
        SUCCESS=$?
    fi
    
    if [ $SUCCESS -eq 0 ]; then
        echo "[OK] Files copied successfully via Method 2!"
    else
        echo "Error: Failed to copy files"
        exit 1
    fi
fi

# Verify and report
echo ""
FILE_COUNT=$(find "$LOCAL_DEST" -type f 2>/dev/null | wc -l)
if [ "$FILE_COUNT" -gt 0 ]; then
    echo "[OK] Copy completed successfully!"
    echo "Files copied: $FILE_COUNT"
    echo "Destination: $LOCAL_DEST"
    echo ""
    echo "Sample files:"
    find "$LOCAL_DEST" -type f 2>/dev/null | head -5 | while read f; do
        ls -lh "$f" 2>/dev/null
    done
else
    echo "Warning: No files found in destination"
fi

echo ""
echo "=========================================="
echo "Done!"
echo "=========================================="


