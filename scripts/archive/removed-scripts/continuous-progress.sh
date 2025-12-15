#!/bin/bash
# continuous-progress.sh
# Shows continuous build progress in terminal

ANDROID_SDK="$LOCALAPPDATA/Android/Sdk"
ADB_PATH="$ANDROID_SDK/platform-tools/adb.exe"

while true; do
    clear
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║  DROIDRUN[GOOGLE] BUILD PROGRESS - $(date '+%Y-%m-%d %H:%M:%S')  ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""
    
    "$ADB_PATH" shell "run-as com.termux sh -c 'export PREFIX=/data/data/com.termux/files/usr && export HOME=/data/data/com.termux/files/home && export PATH=\$PREFIX/bin:\$PATH && 
    
    echo \"📦 INSTALLED PACKAGES:\"
    echo \"────────────────────────────────────────────────────────────\"
    pip list 2>/dev/null | grep -E \"^numpy|^scipy|^pandas|^scikit-learn|^jiter|^pyarrow|^psutil|^droidrun|^Cython|^meson-python|^pythran|^pybind11|^maturin\" | awk \"{printf \\\"  ✓ %-20s %s\\n\\\", \\\$1, \\\$2}\" || echo \"  (checking...)\"
    echo \"\"
    
    echo \"🔨 ACTIVE BUILD PROCESSES:\"
    echo \"────────────────────────────────────────────────────────────\"
    BUILD_PROCS=\$(ps aux | grep -E \"pip|python.*wheel|ninja|meson|clang|rustc\" | grep -v grep | grep -v monitor | grep -v progress)
    if [ -n \"\$BUILD_PROCS\" ]; then
        echo \"\$BUILD_PROCS\" | head -5 | awk \"{printf \\\"  → %-12s %s %s %s %s %s\\n\\\", \\\$1, \\\$11, \\\$12, \\\$13, \\\$14, \\\$15}\"
    else
        echo \"  No active build processes\"
    fi
    echo \"\"
    
    echo \"📁 WHEEL FILES:\"
    echo \"────────────────────────────────────────────────────────────\"
    WHEEL_COUNT=\$(ls -1 \$HOME/wheels/*.whl 2>/dev/null | wc -l)
    echo \"  Total: \$WHEEL_COUNT wheel(s)\"
    ls -lh \$HOME/wheels/*.whl 2>/dev/null | tail -5 | awk \"{printf \\\"  %-40s %6s\\n\\\", \\\$9, \\\$5}\" | sed \"s|.*/||\" || echo \"  (building...)\"
    echo \"\"
    
    echo \"📝 BUILD LOG (last 8 lines):\"
    echo \"────────────────────────────────────────────────────────────\"
    if [ -f \$HOME/wheels/build-monitor.log ]; then
        tail -8 \$HOME/wheels/build-monitor.log | sed \"s/^/  /\"
    else
        echo \"  (log will appear when monitor script runs)\"
    fi
    echo \"\"
    
    echo \"💾 SYSTEM RESOURCES:\"
    echo \"────────────────────────────────────────────────────────────\"
    free -h | grep Mem | awk \"{printf \\\"  Memory: %s / %s (%s free)\\n\\\", \\\$3, \\\$2, \\\$4}\"
    echo \"\"
    
    echo \"📊 PROGRESS:\"
    echo \"────────────────────────────────────────────────────────────\"
    COMPLETED=\$(pip list 2>/dev/null | grep -E \"^numpy|^scipy|^pandas|^scikit-learn|^jiter|^pyarrow|^psutil|^droidrun\" | wc -l)
    echo \"  Packages: \$COMPLETED / 8 installed\"
    case \$COMPLETED in
        0) echo \"  Status: 🚀 Starting...\" ;;
        1) echo \"  Status: ⏳ Building scipy (takes 30-60 min)...\" ;;
        2) echo \"  Status: ⏳ Building pandas...\" ;;
        3) echo \"  Status: ⏳ Building scikit-learn...\" ;;
        4) echo \"  Status: ⏳ Building jiter...\" ;;
        5) echo \"  Status: ⏳ Building pyarrow...\" ;;
        6) echo \"  Status: ⏳ Building psutil...\" ;;
        7) echo \"  Status: ⏳ Installing droidrun[google]...\" ;;
        8) echo \"  Status: ✅ ALL COMPLETE!\" ;;
        *) echo \"  Status: ⏳ In progress...\" ;;
    esac
    '"
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Next update in 10 seconds... (Press Ctrl+C to stop)"
    sleep 10
done

