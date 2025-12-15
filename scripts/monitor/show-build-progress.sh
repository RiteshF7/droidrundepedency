#!/bin/bash
# show-build-progress.sh
# Continuous build progress monitor

ANDROID_SDK="$LOCALAPPDATA/Android/Sdk"
ADB_PATH="$ANDROID_SDK/platform-tools/adb.exe"

while true; do
    clear
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║     DROIDRUN[GOOGLE] BUILD PROGRESS MONITOR                  ║"
    echo "║     $(date '+%Y-%m-%d %H:%M:%S')                                    ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""
    
    "$ADB_PATH" shell "run-as com.termux sh -c 'export PREFIX=/data/data/com.termux/files/usr && export HOME=/data/data/com.termux/files/home && export PATH=\$PREFIX/bin:\$PATH && 
    
    echo \"📦 INSTALLED PACKAGES:\"
    echo \"────────────────────────────────────────────────────────────\"
    pip list 2>/dev/null | grep -E \"numpy|scipy|pandas|scikit-learn|jiter|pyarrow|psutil|droidrun|Cython|meson-python|pythran|pybind11|maturin\" | awk \"{printf \\\"  ✓ %-20s %s\\n\\\", \\\$1, \\\$2}\" || echo \"  (checking...)\"
    echo \"\"
    
    echo \"🔨 BUILD STATUS:\"
    echo \"────────────────────────────────────────────────────────────\"
    if [ -f \$HOME/wheels/build-monitor.log ]; then
        echo \"  Recent log entries:\"
        tail -10 \$HOME/wheels/build-monitor.log | sed \"s/^/  /\" | tail -8
    else
        echo \"  Waiting for scipy build to complete...\"
    fi
    echo \"\"
    
    echo \"⚙️  ACTIVE BUILD PROCESSES:\"
    echo \"────────────────────────────────────────────────────────────\"
    BUILD_PROCS=\$(ps aux | grep -E \"pip|python.*wheel|ninja|meson|clang.*scipy|rustc\" | grep -v grep | grep -v monitor)
    if [ -n \"\$BUILD_PROCS\" ]; then
        echo \"\$BUILD_PROCS\" | head -5 | awk \"{printf \\\"  → %-12s %s %s %s %s %s\\n\\\", \\\$1, \\\$11, \\\$12, \\\$13, \\\$14, \\\$15}\"
    else
        echo \"  No active build processes\"
    fi
    echo \"\"
    
    echo \"📁 WHEEL FILES:\"
    echo \"────────────────────────────────────────────────────────────\"
    WHEEL_COUNT=\$(ls -1 \$HOME/wheels/*.whl 2>/dev/null | wc -l)
    echo \"  Total wheels built: \$WHEEL_COUNT\"
    ls -lh \$HOME/wheels/*.whl 2>/dev/null | tail -5 | awk \"{printf \\\"  %-45s %6s\\n\\\", \\\$9, \\\$5}\" | sed \"s|.*/||\" || echo \"  (wheels being built...)\"
    echo \"\"
    
    echo \"💾 SYSTEM RESOURCES:\"
    echo \"────────────────────────────────────────────────────────────\"
    free -h | grep Mem | awk \"{printf \\\"  Memory: %s / %s (%s free)\\n\\\", \\\$3, \\\$2, \\\$4}\"
    echo \"\"
    
    echo \"📊 PROGRESS SUMMARY:\"
    echo \"────────────────────────────────────────────────────────────\"
    COMPLETED=\$(pip list 2>/dev/null | grep -E \"^numpy|^scipy|^pandas|^scikit-learn|^jiter|^pyarrow|^psutil|^droidrun\" | wc -l)
    echo \"  Packages installed: \$COMPLETED / 8\"
    if [ \$COMPLETED -eq 8 ]; then
        echo \"  ✅ ALL PACKAGES INSTALLED!\"
    elif [ \$COMPLETED -ge 2 ]; then
        echo \"  ⏳ Build in progress...\"
    else
        echo \"  🚀 Starting build...\"
    fi
    '"
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Next update in 15 seconds... (Press Ctrl+C to stop)"
    sleep 15
done

