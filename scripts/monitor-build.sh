#!/bin/bash
# monitor-build.sh - Monitor build progress in real-time

echo "=== Monitoring Build Progress ==="
echo "Press Ctrl+C to stop"
echo ""

while true; do
    clear
    echo "=== Build Log (Last 30 lines) - $(date) ==="
    adb shell "run-as com.termux sh -c 'tail -30 /data/data/com.termux/files/home/build.log 2>&1'" 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g'
    echo ""
    echo "=== Waiting for updates (5 seconds)... ==="
    sleep 5
done

