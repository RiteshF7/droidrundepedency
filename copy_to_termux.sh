#!/usr/bin/env bash
# Generic script to copy files/folders FROM laptop TO Termux via ADB
# Usage: ./copy_to_termux.sh <local_path> [termux_destination]
# Example: ./copy_to_termux.sh ~/file.txt
# Example: ./copy_to_termux.sh ~/Downloads/wheels ~/wheels_backup
# Example: ./copy_to_termux.sh myfolder ~/myfolder

TERMUX_HOME="/data/data/com.termux/files/home"
TERMUX_PREFIX="/data/data/com.termux/files/usr"

# Check arguments
if [ $# -lt 1 ]; then
    echo "Usage: $0 <local_path> [termux_destination]"
    echo ""
    echo "Examples:"
    echo "  $0 ~/file.txt              # Copy file.txt to Termux home"
    echo "  $0 ~/file.txt ~/myfile.txt # Copy file.txt to ~/myfile.txt in Termux"
    echo "  $0 myfolder                # Copy 'myfolder' to Termux home"
    echo "  $0 ~/wheels ~/wheels_backup # Copy wheels folder to ~/wheels_backup in Termux"
    exit 1
fi

LOCAL_SOURCE="$1"
TERMUX_DEST="${2:-$(basename "$LOCAL_SOURCE")}"

# Expand local path
LOCAL_SOURCE="${LOCAL_SOURCE/#\~/$HOME}"

# Remove leading ~/ from termux destination if present
TERMUX_DEST="${TERMUX_DEST#~/}"
FULL_TERMUX_PATH="$TERMUX_HOME/$TERMUX_DEST"

echo "=========================================="
echo "Copying from Laptop to Termux"
echo "=========================================="
echo "Source (Laptop): $LOCAL_SOURCE"
echo "Destination (Termux): $FULL_TERMUX_PATH"
echo ""

# Check if local source exists
if [ ! -e "$LOCAL_SOURCE" ]; then
    echo "Error: Local source does not exist: $LOCAL_SOURCE"
    exit 1
fi

echo "[OK] Local source found"
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

# Determine if source is file or directory
if [ -f "$LOCAL_SOURCE" ]; then
    IS_FILE=true
    echo "Source type: File"
elif [ -d "$LOCAL_SOURCE" ]; then
    IS_FILE=false
    echo "Source type: Directory"
else
    echo "Error: Source is neither a file nor a directory"
    exit 1
fi

echo "Copying to Termux..."
echo ""

if [ "$IS_FILE" = true ]; then
    # Copy single file
    FILENAME=$(basename "$LOCAL_SOURCE")
    TERMUX_FILE_DIR="$(dirname "$FULL_TERMUX_PATH")"
    
    echo "Creating directory in Termux: $TERMUX_FILE_DIR"
    adb shell "run-as com.termux sh -c 'cd $TERMUX_HOME && export PATH=$TERMUX_PREFIX/bin:\$PATH && export HOME=$TERMUX_HOME && export PREFIX=$TERMUX_PREFIX && mkdir -p \"$TERMUX_FILE_DIR\"'"
    
    echo "Copying file via base64..."
    base64 "$LOCAL_SOURCE" | adb shell "run-as com.termux sh -c 'cd $TERMUX_HOME && export PATH=$TERMUX_PREFIX/bin:\$PATH && export HOME=$TERMUX_HOME && export PREFIX=$TERMUX_PREFIX && base64 -d > \"$FULL_TERMUX_PATH\"'"
    
    if [ $? -eq 0 ]; then
        echo "[OK] File copied successfully!"
    else
        echo "Error: Failed to copy file"
        exit 1
    fi
else
    # Copy directory
    DIRNAME=$(basename "$LOCAL_SOURCE")
    
    echo "Creating tar archive..."
    TAR_FILE=$(mktemp)
    tar czf "$TAR_FILE" -C "$(dirname "$LOCAL_SOURCE")" "$(basename "$LOCAL_SOURCE")" 2>/dev/null
    
    if [ $? -ne 0 ]; then
        echo "Error: Failed to create tar archive"
        rm -f "$TAR_FILE"
        exit 1
    fi
    
    echo "Creating destination directory in Termux..."
    TERMUX_DEST_DIR="$(dirname "$FULL_TERMUX_PATH")"
    adb shell "run-as com.termux sh -c 'cd $TERMUX_HOME && export PATH=$TERMUX_PREFIX/bin:\$PATH && export HOME=$TERMUX_HOME && export PREFIX=$TERMUX_PREFIX && mkdir -p \"$TERMUX_DEST_DIR\"'"
    
    echo "Copying directory via tar stream..."
    cat "$TAR_FILE" | adb shell "run-as com.termux sh -c 'cd $TERMUX_HOME && export PATH=$TERMUX_PREFIX/bin:\$PATH && export HOME=$TERMUX_HOME && export PREFIX=$TERMUX_PREFIX && cd \"$TERMUX_DEST_DIR\" && tar xzf - 2>/dev/null'"
    
    rm -f "$TAR_FILE"
    
    if [ $? -eq 0 ]; then
        echo "[OK] Directory copied successfully!"
    else
        echo "Error: Failed to copy directory"
        exit 1
    fi
fi

# Verify
echo ""
echo "Verifying copy..."
if [ "$IS_FILE" = true ]; then
    REMOTE_SIZE=$(adb shell "run-as com.termux sh -c 'cd $TERMUX_HOME && export PATH=$TERMUX_PREFIX/bin:\$PATH && stat -c%s \"$FULL_TERMUX_PATH\" 2>/dev/null || stat -f%z \"$FULL_TERMUX_PATH\" 2>/dev/null'")
    LOCAL_SIZE=$(stat -c%s "$LOCAL_SOURCE" 2>/dev/null || stat -f%z "$LOCAL_SOURCE" 2>/dev/null)
    
    if [ "$REMOTE_SIZE" = "$LOCAL_SIZE" ]; then
        echo "[OK] File size matches: $LOCAL_SIZE bytes"
    else
        echo "Warning: File size mismatch (local: $LOCAL_SIZE, remote: $REMOTE_SIZE)"
    fi
else
    REMOTE_COUNT=$(adb shell "run-as com.termux sh -c 'cd $TERMUX_HOME && export PATH=$TERMUX_PREFIX/bin:\$PATH && find \"$FULL_TERMUX_PATH\" -type f 2>/dev/null | wc -l'")
    LOCAL_COUNT=$(find "$LOCAL_SOURCE" -type f 2>/dev/null | wc -l)
    
    echo "Files in directory:"
    echo "  Local: $LOCAL_COUNT"
    echo "  Remote: $REMOTE_COUNT"
    
    if [ "$REMOTE_COUNT" -eq "$LOCAL_COUNT" ]; then
        echo "[OK] File count matches!"
    else
        echo "Warning: File count mismatch"
    fi
fi

echo ""
echo "=========================================="
echo "Done! Files copied to: $FULL_TERMUX_PATH"
echo "=========================================="


