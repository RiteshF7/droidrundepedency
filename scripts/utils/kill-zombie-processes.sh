#!/bin/bash
# kill-zombie-processes.sh
# Kill all zombie/stuck build processes in Termux
# Based on Error #12 solution in termux-build-errors-and-solutions.md

set -e

ADB="${LOCALAPPDATA}/Android/Sdk/platform-tools/adb.exe"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Killing Zombie/Stuck Processes in Termux"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check if emulator is running
if ! "$ADB" devices | grep -q "emulator"; then
    echo "❌ Error: No emulator detected"
    exit 1
fi

echo "✅ Emulator detected"
echo ""

# Step 1: Check current processes
echo "Step 1: Checking for running build processes..."
"$ADB" shell "run-as com.termux sh -c 'export PREFIX=/data/data/com.termux/files/usr && export PATH=\$PREFIX/bin:\$PATH && ps -o pid,comm,args | grep -E \"python|pip|clang|gcc|rustc|ninja|make|meson|cc\" | grep -v grep || echo \"No build processes found\"'"
echo ""

# Step 2: Kill all build processes
echo "Step 2: Killing all build processes..."
"$ADB" shell "run-as com.termux sh -c 'export PREFIX=/data/data/com.termux/files/usr && export PATH=\$PREFIX/bin:\$PATH && \
pkill -9 python 2>/dev/null || true && \
pkill -9 pip 2>/dev/null || true && \
pkill -9 clang 2>/dev/null || true && \
pkill -9 gcc 2>/dev/null || true && \
pkill -9 rustc 2>/dev/null || true && \
pkill -9 cargo 2>/dev/null || true && \
pkill -9 ninja 2>/dev/null || true && \
pkill -9 make 2>/dev/null || true && \
pkill -9 meson 2>/dev/null || true && \
pkill -9 cc 2>/dev/null || true && \
pkill -9 c++ 2>/dev/null || true && \
pkill -9 cmake 2>/dev/null || true && \
echo \"All build processes killed\"'"

echo ""
echo "✅ Build processes killed"
echo ""

# Step 3: Force stop Termux to release memory
echo "Step 3: Force stopping Termux to release memory..."
"$ADB" shell "am force-stop com.termux"
sleep 2
echo "✅ Termux force stopped"
echo ""

# Step 4: Check memory after cleanup
echo "Step 4: Checking system memory..."
"$ADB" shell "free -h"
echo ""

# Step 5: Verify no processes remain
echo "Step 5: Verifying no processes remain..."
"$ADB" shell "run-as com.termux sh -c 'export PREFIX=/data/data/com.termux/files/usr && export PATH=\$PREFIX/bin:\$PATH && ps -o pid,comm,args | grep -E \"python|pip|clang|gcc|rustc|ninja|make|meson\" | grep -v grep || echo \"✅ No build processes running\"'"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Cleanup complete!"
echo ""
echo "You can now:"
echo "  1. Reopen Termux manually from the launcher"
echo "  2. Or restart the emulator if system is still unresponsive"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

