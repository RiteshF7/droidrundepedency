#!/data/data/com.termux/files/usr/bin/bash
# monitor-and-continue-build.sh
# Monitors scipy build and continues with remaining packages

set -e

export PREFIX=/data/data/com.termux/files/usr
export HOME=/data/data/com.termux/files/home
export PATH=$PREFIX/bin:$PATH
export NINJAFLAGS="-j2"
export MAKEFLAGS="-j2"
export MAX_JOBS=2

WHEELS_DIR="$HOME/wheels"
LOG_FILE="$HOME/wheels/build-monitor.log"

mkdir -p "$WHEELS_DIR"
touch "$LOG_FILE"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

check_scipy_complete() {
    if pip show scipy &>/dev/null; then
        local version=$(pip show scipy | grep "^Version:" | awk '{print $2}')
        if [ -n "$version" ]; then
            log "✓ Scipy $version is installed"
            return 0
        fi
    fi
    return 1
}

wait_for_scipy() {
    log "Waiting for scipy build to complete..."
    local check_count=0
    while ! check_scipy_complete; do
        check_count=$((check_count + 1))
        if [ $((check_count % 20)) -eq 0 ]; then
            log "Still waiting... (checked $check_count times, ~$((check_count * 3)) minutes)"
        fi
        
        # Check if build process is still running
        if ! ps aux | grep -E "pip.*scipy|python.*scipy|meson.*scipy|ninja.*scipy" | grep -v grep >/dev/null; then
            # No build process, check if wheel exists
            if [ -f "$WHEELS_DIR"/scipy*.whl ]; then
                log "Build process stopped but wheel exists, installing..."
                cd "$WHEELS_DIR"
                pip install --find-links . --no-index scipy*.whl
                if check_scipy_complete; then
                    return 0
                fi
            else
                log "ERROR: Build process stopped but no wheel found!"
                return 1
            fi
        fi
        
        sleep 180  # Wait 3 minutes
    done
    log "Scipy build completed!"
    return 0
}

build_pandas() {
    log "=== Building pandas <2.3.0 ==="
    cd "$WHEELS_DIR"
    
    # Uninstall any existing pandas
    pip uninstall -y pandas 2>/dev/null || true
    
    # Download correct version
    pip download "pandas<2.3.0" --dest . --no-cache-dir --no-build-isolation
    
    # Find the downloaded pandas file (should be 2.2.x)
    local pandas_file=$(ls -t pandas-2.2.*.tar.gz 2>/dev/null | head -1)
    if [ -z "$pandas_file" ]; then
        pandas_file=$(ls -t pandas-*.tar.gz 2>/dev/null | head -1)
    fi
    
    if [ -n "$pandas_file" ] && [ -f "$pandas_file" ]; then
        log "Building wheel from $pandas_file..."
        pip wheel "$pandas_file" --no-deps --wheel-dir .
        local wheel_file=$(ls -t pandas-2.2.*.whl 2>/dev/null | head -1)
        if [ -z "$wheel_file" ]; then
            wheel_file=$(ls -t pandas-*.whl 2>/dev/null | head -1)
        fi
        
        if [ -n "$wheel_file" ] && [ -f "$wheel_file" ]; then
            log "Installing pandas from $wheel_file..."
            pip install --find-links . --no-index "$wheel_file"
            log "✓ Pandas installed: $(pip show pandas | grep '^Version:' | awk '{print $2}')"
            return 0
        fi
    fi
    
    log "ERROR: Failed to build pandas"
    return 1
}

build_scikit_learn() {
    log "=== Building scikit-learn from GitHub ==="
    cd "$WHEELS_DIR"
    
    # Remove old source if exists
    rm -rf scikit-learn-source
    
    # Clone from GitHub
    git clone --depth 1 https://github.com/scikit-learn/scikit-learn.git scikit-learn-source
    cd scikit-learn-source
    
    # Fix version.py
    chmod +x sklearn/_build_utils/version.py
    if ! head -1 sklearn/_build_utils/version.py | grep -q "^#!"; then
        sed -i '1i#!/usr/bin/env python3' sklearn/_build_utils/version.py
    fi
    
    # Build wheel
    pip wheel --no-deps --wheel-dir "$WHEELS_DIR" .
    
    # Install
    local wheel_file=$(ls -t "$WHEELS_DIR"/scikit-learn-*.whl 2>/dev/null | head -1)
    if [ -n "$wheel_file" ] && [ -f "$wheel_file" ]; then
        pip install --find-links "$WHEELS_DIR" --no-index "$wheel_file"
        log "✓ Scikit-learn installed: $(pip show scikit-learn | grep '^Version:' | awk '{print $2}')"
        return 0
    fi
    
    log "ERROR: Failed to build scikit-learn"
    return 1
}

build_jiter() {
    log "=== Installing maturin and building jiter ==="
    cd "$WHEELS_DIR"
    
    # Install maturin
    pip install "maturin<2,>=1.9.4"
    
    # Download and build jiter
    pip download jiter --dest . --no-cache-dir --no-build-isolation
    pip wheel jiter --no-deps --wheel-dir .
    
    # Install
    local wheel_file=$(ls -t jiter-*.whl 2>/dev/null | head -1)
    if [ -n "$wheel_file" ] && [ -f "$wheel_file" ]; then
        pip install --find-links . --no-index "$wheel_file"
        log "✓ Jiter installed: $(pip show jiter | grep '^Version:' | awk '{print $2}')"
        return 0
    fi
    
    log "ERROR: Failed to build jiter"
    return 1
}

build_pyarrow() {
    log "=== Building pyarrow from GitHub ==="
    cd "$WHEELS_DIR"
    
    # Remove old source if exists
    rm -rf pyarrow-source
    
    # Clone from GitHub
    git clone --depth 1 https://github.com/apache/arrow.git pyarrow-source
    cd pyarrow-source/python
    
    # Build wheel
    pip wheel --no-deps --wheel-dir "$WHEELS_DIR" .
    
    # Install
    local wheel_file=$(ls -t "$WHEELS_DIR"/pyarrow-*.whl 2>/dev/null | head -1)
    if [ -n "$wheel_file" ] && [ -f "$wheel_file" ]; then
        pip install --find-links "$WHEELS_DIR" --no-index "$wheel_file"
        log "✓ PyArrow installed: $(pip show pyarrow | grep '^Version:' | awk '{print $2}')"
        return 0
    fi
    
    log "ERROR: Failed to build pyarrow"
    return 1
}

build_psutil() {
    log "=== Building psutil ==="
    cd "$WHEELS_DIR"
    
    pip download psutil --dest . --no-cache-dir --no-build-isolation
    pip wheel psutil --no-deps --wheel-dir .
    
    # Install
    local wheel_file=$(ls -t psutil-*.whl 2>/dev/null | head -1)
    if [ -n "$wheel_file" ] && [ -f "$wheel_file" ]; then
        pip install --find-links . --no-index "$wheel_file"
        log "✓ Psutil installed: $(pip show psutil | grep '^Version:' | awk '{print $2}')"
        return 0
    fi
    
    log "ERROR: Failed to build psutil"
    return 1
}

install_droidrun() {
    log "=== Installing droidrun[google] ==="
    cd "$HOME"
    
    pip install 'droidrun[google]' --find-links "$WHEELS_DIR"
    
    if pip show droidrun &>/dev/null; then
        log "✓ droidrun[google] installed: $(pip show droidrun | grep '^Version:' | awk '{print $2}')"
        return 0
    fi
    
    log "ERROR: Failed to install droidrun[google]"
    return 1
}

# Main execution
main() {
    log "=== Build Monitor Started ==="
    log "Waiting for scipy to complete..."
    
    # Wait for scipy
    if wait_for_scipy; then
        log "Scipy completed, continuing with remaining packages..."
        
        # Build remaining packages
        build_pandas || log "WARNING: Pandas build failed"
        build_scikit_learn || log "WARNING: Scikit-learn build failed"
        build_jiter || log "WARNING: Jiter build failed"
        build_pyarrow || log "WARNING: PyArrow build failed"
        build_psutil || log "WARNING: Psutil build failed"
        
        # Install main package
        install_droidrun || log "WARNING: droidrun[google] installation failed"
        
        log "=== Build Process Complete ==="
        log "Summary:"
        pip list | grep -E "numpy|scipy|pandas|scikit-learn|jiter|pyarrow|psutil|droidrun" | tee -a "$LOG_FILE"
    else
        log "ERROR: Scipy build did not complete successfully"
        exit 1
    fi
}

main "$@"

