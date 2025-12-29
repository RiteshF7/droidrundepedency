#!/usr/bin/env bash
# Simple script to monitor the pydantic-core build progress

LOG_FILE="/tmp/pydantic_build.log"

if [ ! -f "$LOG_FILE" ]; then
    echo "Log file not found: $LOG_FILE"
    echo "The build may not be running or using a different log file."
    exit 1
fi

echo "Monitoring build progress..."
echo "Press Ctrl+C to stop"
echo "================================"
echo ""

tail -f "$LOG_FILE" | while read line; do
    # Highlight important lines
    if echo "$line" | grep -qE "(ERROR|error|Failed|failed)"; then
        echo -e "\033[31m$line\033[0m"  # Red for errors
    elif echo "$line" | grep -qE "(Building|building|python-pydantic)"; then
        echo -e "\033[32m$line\033[0m"  # Green for build steps
    elif echo "$line" | grep -qE "(Done|done|built|completed)"; then
        echo -e "\033[33m$line\033[0m"  # Yellow for completion
    else
        echo "$line"
    fi
done

