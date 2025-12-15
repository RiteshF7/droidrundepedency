#!/bin/bash
# view-install-log.sh
# Helper script to view the installation log

ADB="${LOCALAPPDATA}/Android/Sdk/platform-tools/adb.exe"

echo "=== Viewing Installation Log ==="
echo ""

"$ADB" shell "run-as com.termux sh -c '
export PREFIX=/data/data/com.termux/files/usr
export HOME=/data/data/com.termux/files/home
export PATH=\$PREFIX/bin:\$PATH

if [ -f \$HOME/wheels/install-dependencies.log ]; then
    echo \"Log file: \$HOME/wheels/install-dependencies.log\"
    echo \"File size: \$(du -h \$HOME/wheels/install-dependencies.log | cut -f1)\"
    echo \"Last modified: \$(stat -c %y \$HOME/wheels/install-dependencies.log 2>/dev/null || stat -f %Sm \$HOME/wheels/install-dependencies.log 2>/dev/null || echo \"unknown\")\"
    echo \"\"
    echo \"=== Last 50 lines ===\"
    tail -50 \$HOME/wheels/install-dependencies.log
else
    echo \"Log file not found at: \$HOME/wheels/install-dependencies.log\"
    echo \"Checking if wheels directory exists...\"
    ls -la \$HOME/wheels/ 2>/dev/null || echo \"Wheels directory does not exist\"
fi
'"

