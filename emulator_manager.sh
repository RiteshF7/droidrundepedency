#!/bin/bash
# Android Emulator Manager Script
# Usage: ./emulator_manager.sh [launch|relaunch|stop|restart|status]

set -e

# Configuration
ANDROID_HOME="${ANDROID_HOME:-$HOME/Android/Sdk}"
AVD_NAME="${AVD_NAME:-android_dev}"
EMULATOR_BIN="$ANDROID_HOME/emulator/emulator"
ADB_BIN="$ANDROID_HOME/platform-tools/adb"
LOG_FILE="/tmp/emulator.log"
PID_FILE="/tmp/emulator.pid"

# Export paths
export ANDROID_HOME
export PATH="$PATH:$ANDROID_HOME/emulator:$ANDROID_HOME/platform-tools"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

check_emulator_binary() {
    if [ ! -f "$EMULATOR_BIN" ]; then
        print_error "Emulator binary not found at: $EMULATOR_BIN"
        print_error "Please set ANDROID_HOME or install Android SDK"
        exit 1
    fi
}

check_avd_exists() {
    AVD_LIST=$("$EMULATOR_BIN" -list-avds 2>/dev/null)
    if ! echo "$AVD_LIST" | grep -q "^${AVD_NAME}$"; then
        print_error "AVD '$AVD_NAME' not found!"
        print_status "Available AVDs:"
        echo "$AVD_LIST"
        exit 1
    fi
}

get_emulator_pid() {
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        if ps -p "$PID" > /dev/null 2>&1; then
            echo "$PID"
            return 0
        else
            # PID file exists but process is dead
            rm -f "$PID_FILE"
        fi
    fi
    
    # Try to find emulator process
    PID=$(pgrep -f "qemu-system-x86_64.*-avd $AVD_NAME" | head -1)
    if [ -n "$PID" ]; then
        echo "$PID" > "$PID_FILE"
        echo "$PID"
        return 0
    fi
    
    return 1
}

is_emulator_running() {
    PID=$(get_emulator_pid)
    if [ -n "$PID" ]; then
        return 0
    else
        return 1
    fi
}

check_adb_connection() {
    if [ -f "$ADB_BIN" ]; then
        DEVICE=$("$ADB_BIN" devices 2>/dev/null | grep "emulator-" | awk '{print $1}')
        if [ -n "$DEVICE" ]; then
            return 0
        fi
    fi
    return 1
}

launch_emulator() {
    if is_emulator_running; then
        PID=$(get_emulator_pid)
        print_warning "Emulator is already running (PID: $PID)"
        print_status "Use 'relaunch' or 'restart' to stop and start again"
        return 1
    fi
    
    print_status "Launching Android Emulator..."
    print_status "AVD: $AVD_NAME"
    print_status "Log file: $LOG_FILE"
    
    check_emulator_binary
    check_avd_exists
    
    # Start emulator in background
    "$EMULATOR_BIN" -avd "$AVD_NAME" \
        -no-snapshot-load \
        -no-audio \
        > "$LOG_FILE" 2>&1 &
    
    EMULATOR_PID=$!
    echo "$EMULATOR_PID" > "$PID_FILE"
    
    print_success "Emulator started (PID: $EMULATOR_PID)"
    print_status "Waiting for emulator to boot..."
    
    # Wait for emulator to be ready (check ADB connection)
    MAX_WAIT=120
    WAIT_COUNT=0
    while [ $WAIT_COUNT -lt $MAX_WAIT ]; do
        if check_adb_connection; then
            DEVICE=$("$ADB_BIN" devices 2>/dev/null | grep "emulator-" | awk '{print $1}')
            print_success "Emulator is ready! Device: $DEVICE"
            return 0
        fi
        sleep 2
        WAIT_COUNT=$((WAIT_COUNT + 2))
        echo -n "."
    done
    
    echo ""
    print_warning "Emulator started but may not be fully booted yet"
    print_status "Check status with: $0 status"
    return 0
}

stop_emulator() {
    if ! is_emulator_running; then
        print_warning "Emulator is not running"
        return 1
    fi
    
    PID=$(get_emulator_pid)
    print_status "Stopping emulator (PID: $PID)..."
    
    # Try graceful shutdown via ADB first
    if check_adb_connection; then
        "$ADB_BIN" emu kill > /dev/null 2>&1 || true
        sleep 2
    fi
    
    # Force kill if still running
    if ps -p "$PID" > /dev/null 2>&1; then
        print_status "Force killing emulator process..."
        kill -9 "$PID" 2>/dev/null || true
    fi
    
    # Clean up
    rm -f "$PID_FILE"
    
    # Wait a bit and verify
    sleep 2
    if is_emulator_running; then
        print_error "Failed to stop emulator"
        return 1
    else
        print_success "Emulator stopped"
        return 0
    fi
}

relaunch_emulator() {
    print_status "Relaunching emulator..."
    if is_emulator_running; then
        stop_emulator
        sleep 2
    fi
    launch_emulator
}

restart_emulator() {
    print_status "Restarting emulator (stop and relaunch)..."
    relaunch_emulator
}

show_status() {
    echo ""
    echo "=== Android Emulator Status ==="
    echo ""
    
    if is_emulator_running; then
        PID=$(get_emulator_pid)
        print_success "Emulator is RUNNING"
        echo "  PID: $PID"
        echo "  AVD: $AVD_NAME"
        
        if check_adb_connection; then
            DEVICE=$("$ADB_BIN" devices 2>/dev/null | grep "emulator-" | awk '{print $1}')
            print_success "ADB Connected: $DEVICE"
            echo ""
            echo "Connected devices:"
            "$ADB_BIN" devices
        else
            print_warning "ADB not connected (emulator may still be booting)"
        fi
        
        echo ""
        echo "Log file: $LOG_FILE"
        echo "To view logs: tail -f $LOG_FILE"
    else
        print_error "Emulator is NOT running"
    fi
    
    echo ""
    echo "Available AVDs:"
    "$EMULATOR_BIN" -list-avds 2>/dev/null || echo "  (none found)"
    echo ""
}

show_usage() {
    echo "Android Emulator Manager"
    echo ""
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  launch    - Start the emulator"
    echo "  stop      - Stop the running emulator"
    echo "  restart   - Stop and start the emulator"
    echo "  relaunch  - Same as restart"
    echo "  status    - Show emulator status"
    echo "  help      - Show this help message"
    echo ""
    echo "Environment variables:"
    echo "  ANDROID_HOME - Android SDK location (default: \$HOME/Android/Sdk)"
    echo "  AVD_NAME     - AVD name to use (default: android_dev)"
    echo ""
    echo "Examples:"
    echo "  $0 launch"
    echo "  $0 stop"
    echo "  $0 restart"
    echo "  AVD_NAME=my_device $0 launch"
}

# Main script
case "${1:-help}" in
    launch)
        launch_emulator
        ;;
    stop)
        stop_emulator
        ;;
    restart|relaunch)
        restart_emulator
        ;;
    status)
        show_status
        ;;
    help|--help|-h)
        show_usage
        ;;
    *)
        print_error "Unknown command: $1"
        echo ""
        show_usage
        exit 1
        ;;
esac

