#!/bin/bash
# follow-install-log-poll.sh
# Continuously monitor the installation log by polling (more reliable with ADB)

ADB="${LOCALAPPDATA}/Android/Sdk/platform-tools/adb.exe"

echo "=== Following Installation Log (Polling Mode) ==="
echo "Press Ctrl+C to stop following"
echo ""

# Check if log file exists first
LOG_EXISTS=$("$ADB" shell "run-as com.termux sh -c '
export HOME=/data/data/com.termux/files/home
if [ -f \$HOME/wheels/install-dependencies.log ]; then
    echo \"exists\"
else
    echo \"not_found\"
fi
'")

if [ "$LOG_EXISTS" != "exists" ]; then
    echo "❌ Log file not found!"
    echo "   The installation may not have started yet."
    exit 1
fi

# Show last 20 lines first
echo "=== Last 20 lines ==="
"$ADB" shell "run-as com.termux sh -c 'export HOME=/data/data/com.termux/files/home && tail -20 \$HOME/wheels/install-dependencies.log'"
echo ""
echo "=== Following log (updating every 2 seconds) ==="
echo "Press Ctrl+C to stop"
echo ""

# Poll the log file every 2 seconds
LAST_LINE_COUNT=0
while true; do
    CURRENT_OUTPUT=$("$ADB" shell "run-as com.termux sh -c 'export HOME=/data/data/com.termux/files/home && wc -l < \$HOME/wheels/install-dependencies.log 2>/dev/null || echo 0'")
    CURRENT_LINE_COUNT=$(echo "$CURRENT_OUTPUT" | tr -d '\r\n ' | grep -o '[0-9]*' || echo "0")
    
    if [ "$CURRENT_LINE_COUNT" -gt "$LAST_LINE_COUNT" ]; then
        # Show new lines
        NEW_LINES=$((CURRENT_LINE_COUNT - LAST_LINE_COUNT))
        "$ADB" shell "run-as com.termux sh -c 'export HOME=/data/data/com.termux/files/home && tail -n $NEW_LINES \$HOME/wheels/install-dependencies.log'" | grep -v "^--:"
        LAST_LINE_COUNT=$CURRENT_LINE_COUNT
    fi
    
    sleep 2
done

