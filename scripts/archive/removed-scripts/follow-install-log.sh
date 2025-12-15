#!/bin/bash
# follow-install-log.sh
# Continuously follow the installation log (like tail -f)

ADB="${LOCALAPPDATA}/Android/Sdk/platform-tools/adb.exe"

echo "=== Following Installation Log ==="
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
    echo ""
    echo "Checking if wheels directory exists..."
    "$ADB" shell "run-as com.termux sh -c 'export HOME=/data/data/com.termux/files/home && ls -la \$HOME/wheels/ 2>/dev/null || echo \"Wheels directory does not exist\"'"
    exit 1
fi

# Show last 20 lines first
echo "=== Last 20 lines ==="
"$ADB" shell "run-as com.termux sh -c 'export HOME=/data/data/com.termux/files/home && tail -20 \$HOME/wheels/install-dependencies.log'"
echo ""
echo "=== Following log (Press Ctrl+C to stop) ==="
echo ""

# Use tail -f (works if ADB maintains connection)
# If this doesn't work well, use the polling version instead
"$ADB" shell "run-as com.termux sh -c '
export HOME=/data/data/com.termux/files/home
tail -f \$HOME/wheels/install-dependencies.log
'"

