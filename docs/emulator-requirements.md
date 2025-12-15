# Android Emulator Requirements for Building droidrun[google] Dependencies

This document specifies the minimum and recommended storage and RAM requirements for building all `droidrun[google]` dependencies in Termux on an Android emulator.

## Quick Summary

| Resource | Minimum | Recommended | Optimal |
|----------|---------|-------------|---------|
| **RAM** | 4 GB | 6 GB | 8 GB |
| **Storage** | 20 GB | 30 GB | 40 GB |
| **Swap** | 2 GB | 4 GB | 8 GB |

---

## Detailed Requirements

### RAM (Memory) Requirements

#### Minimum: 4 GB
- **Why**: Building packages like scipy, pandas, scikit-learn, and pyarrow requires significant memory
- **Limitations**: 
  - Must use strict parallelism limits (`NINJAFLAGS="-j1"`, `MAKEFLAGS="-j1"`)
  - Builds will be very slow (2-3x slower than recommended)
  - High risk of OOM (Out of Memory) errors
  - System may become unresponsive during builds
- **Not Recommended**: Only use if absolutely necessary

#### Recommended: 6 GB
- **Why**: Allows comfortable building with moderate parallelism
- **Configuration**:
  - Use `NINJAFLAGS="-j2"`, `MAKEFLAGS="-j2"`, `MAX_JOBS=2`
  - Can build most packages without memory issues
  - System remains responsive
- **Build Time**: ~2-4 hours for all dependencies
- **Best Balance**: Good performance without excessive resource usage

#### Optimal: 8 GB
- **Why**: Maximum performance and reliability
- **Configuration**:
  - Can use `NINJAFLAGS="-j3"`, `MAKEFLAGS="-j3"`, `MAX_JOBS=3`
  - Minimal risk of memory issues
  - Fastest build times
- **Build Time**: ~1.5-3 hours for all dependencies
- **Best Choice**: For production builds or frequent rebuilding

### Memory Breakdown by Package

| Package | Peak Memory Usage | Build Time (6GB RAM) |
|--------|------------------|---------------------|
| numpy | ~800 MB | 15-25 min |
| scipy | ~1.5 GB | 30-45 min |
| pandas | ~1.2 GB | 20-30 min |
| scikit-learn | ~1.8 GB | 40-60 min |
| pyarrow | ~2.0 GB | 45-75 min |
| jiter (Rust) | ~1.0 GB | 20-30 min |
| Other packages | ~500 MB | 10-20 min |

**Note**: Memory usage is cumulative during parallel builds. With `-j2`, you need at least 2x the largest package's memory requirement.

---

## Storage Requirements

### Minimum: 20 GB
- **Breakdown**:
  - Android OS: ~8 GB
  - Termux base installation: ~500 MB
  - Python and system packages: ~1 GB
  - Source distributions: ~2 GB
  - Build artifacts (temporary): ~3 GB
  - Built wheel files: ~1.5 GB
  - Installed packages: ~2 GB
  - Pip cache: ~1 GB
  - Swap file: ~2 GB
  - Buffer space: ~1 GB

### Recommended: 30 GB
- **Breakdown**:
  - All minimum requirements: ~20 GB
  - Additional wheel storage: ~2 GB
  - Multiple build attempts: ~3 GB
  - Logs and debugging files: ~1 GB
  - Git repositories (scikit-learn, pyarrow): ~2 GB
  - Buffer space: ~2 GB

### Optimal: 40 GB
- **Breakdown**:
  - All recommended requirements: ~30 GB
  - Multiple Python versions: ~2 GB
  - Development tools: ~2 GB
  - Backup wheels: ~3 GB
  - Additional buffer: ~3 GB

### Storage Breakdown by Component

| Component | Size | Notes |
|-----------|------|-------|
| Android System | 8-10 GB | Base OS and system apps |
| Termux Installation | 500 MB - 1 GB | Base Termux + packages |
| Python Packages (installed) | 2-3 GB | All installed wheels |
| Wheel Files (built) | 1.5-2 GB | All `.whl` files in `~/wheels/` |
| Source Distributions | 2-3 GB | Downloaded `.tar.gz` files |
| Build Artifacts | 3-5 GB | Temporary files during builds |
| Git Repositories | 1-2 GB | scikit-learn, pyarrow sources |
| Pip Cache | 1-2 GB | Pip download cache |
| Swap File | 2-8 GB | Virtual memory |
| Logs | 100-500 MB | Build logs and error logs |
| Buffer Space | 2-5 GB | For temporary operations |

---

## Swap Space Requirements

### Minimum: 2 GB
- **Why**: Provides safety buffer when RAM is exhausted
- **Location**: Can be on host system or emulator
- **Performance**: Slower than RAM but prevents crashes

### Recommended: 4 GB
- **Why**: Comfortable buffer for memory spikes
- **Configuration**: Set in emulator AVD settings
- **Performance**: Good balance

### Optimal: 8 GB
- **Why**: Maximum safety for large builds
- **Note**: More swap doesn't improve performance, only prevents OOM

---

## Emulator Configuration Recommendations

### AVD Settings

#### For 6 GB RAM (Recommended):
```ini
# config.ini
hw.ramSize = 6144
disk.dataPartition.size = 30G
```

#### For 8 GB RAM (Optimal):
```ini
# config.ini
hw.ramSize = 8192
disk.dataPartition.size = 40G
```

### Graphics Settings
- **Graphics**: Software - GLES 2.0 (for compatibility)
- **Multi-display**: Disabled
- **Camera**: None (saves resources)

### Performance Settings
- **VM heap**: 512 MB (default)
- **Snapshot**: Disabled (saves space, faster boot)
- **Quick boot**: Disabled (cleaner state)

---

## Build Configuration by RAM

### 4 GB RAM Configuration
```bash
export NINJAFLAGS="-j1"
export MAKEFLAGS="-j1"
export MAX_JOBS=1
```
- **Build Time**: 4-6 hours
- **Risk Level**: High (frequent OOM errors)

### 6 GB RAM Configuration (Recommended)
```bash
export NINJAFLAGS="-j2"
export MAKEFLAGS="-j2"
export MAX_JOBS=2
```
- **Build Time**: 2-4 hours
- **Risk Level**: Low

### 8 GB RAM Configuration
```bash
export NINJAFLAGS="-j3"
export MAKEFLAGS="-j3"
export MAX_JOBS=3
```
- **Build Time**: 1.5-3 hours
- **Risk Level**: Very Low

---

## Why Pixel Emulators Have Issues

### Common Problems:
1. **Default RAM**: Pixel emulators often default to 2 GB, which is insufficient
2. **Graphics**: Hardware acceleration can cause rendering issues
3. **Storage**: Default storage may be too small
4. **Memory Management**: Android's aggressive memory management kills processes

### Solutions:
1. **Increase RAM**: Edit AVD settings to 6-8 GB
2. **Use Software Graphics**: Set to "Software - GLES 2.0"
3. **Increase Storage**: Set to 30-40 GB
4. **Disable Memory Optimization**: In developer options

---

## Recommended Emulator Setup

### Step 1: Create New AVD
1. Open Android Studio → AVD Manager
2. Create Virtual Device
3. Select **Generic System Image** (not Pixel)
   - More stable for development
   - Better resource management
4. Or use **Pixel 6** with custom settings

### Step 2: Configure Hardware
- **RAM**: 6144 MB (6 GB) or 8192 MB (8 GB)
- **VM heap**: 512 MB
- **Internal Storage**: 30-40 GB
- **SD Card**: Not required

### Step 3: Configure Graphics
- **Graphics**: Software - GLES 2.0
- **Multi-display**: Disabled
- **Camera**: None

### Step 4: Advanced Settings
- **Boot option**: Cold boot (cleaner)
- **Snapshot**: Disabled
- **Quick boot**: Disabled

---

## Monitoring Resources During Build

### Check Memory Usage:
```bash
# In Termux
free -h

# Via ADB
adb shell "free -h"
```

### Check Storage Usage:
```bash
# In Termux
df -h

# Check wheel directory
du -sh ~/wheels

# Check Termux installation
du -sh $PREFIX
```

### Check Build Processes:
```bash
# In Termux
ps aux | grep -E "python|pip|clang|rustc|ninja|make"
top -n 1
```

---

## Troubleshooting Resource Issues

### Out of Memory (OOM) Errors
**Symptoms**: Build fails, system freezes, Termux crashes

**Solutions**:
1. Reduce parallelism: `export MAX_JOBS=1`
2. Build one package at a time
3. Increase emulator RAM to 6-8 GB
4. Add swap space
5. Close other apps in emulator

### Storage Full Errors
**Symptoms**: "No space left on device", build fails

**Solutions**:
1. Clean pip cache: `pip cache purge`
2. Remove old wheels: `rm ~/wheels/*.tar.gz`
3. Remove build artifacts: `rm -rf /tmp/pip-*`
4. Increase emulator storage to 30-40 GB
5. Wipe emulator and start fresh

### Slow Build Performance
**Symptoms**: Builds take much longer than expected

**Solutions**:
1. Increase RAM to 6-8 GB
2. Use parallelism: `export MAX_JOBS=2` or `3`
3. Disable unnecessary emulator features
4. Close other applications
5. Use SSD storage for AVD files

---

## Cost-Benefit Analysis

### 4 GB RAM
- **Pros**: Lower resource usage
- **Cons**: Very slow builds, frequent failures
- **Verdict**: ❌ Not recommended

### 6 GB RAM
- **Pros**: Good balance, reliable builds
- **Cons**: Slightly slower than 8 GB
- **Verdict**: ✅ **Recommended**

### 8 GB RAM
- **Pros**: Fastest builds, most reliable
- **Cons**: Higher resource usage
- **Verdict**: ✅ **Optimal for frequent builds**

---

## Final Recommendations

### For One-Time Build:
- **RAM**: 6 GB
- **Storage**: 30 GB
- **Time**: 2-4 hours

### For Development/Testing:
- **RAM**: 8 GB
- **Storage**: 40 GB
- **Time**: 1.5-3 hours per full build

### For CI/CD or Production:
- **RAM**: 8 GB
- **Storage**: 40 GB
- **Swap**: 8 GB
- **Time**: 1.5-3 hours

---

## Emulator Alternatives

If Pixel emulators continue to cause issues, consider:

1. **Generic System Image**: More stable, better resource management
2. **Android x86_64**: Better performance on x86 hosts
3. **Physical Device**: Best performance, but requires USB debugging setup

---

## Summary

**Minimum Viable Configuration**:
- RAM: 4 GB (not recommended)
- Storage: 20 GB
- Build Time: 4-6 hours
- Success Rate: ~60%

**Recommended Configuration**:
- RAM: 6 GB ✅
- Storage: 30 GB ✅
- Build Time: 2-4 hours
- Success Rate: ~95%

**Optimal Configuration**:
- RAM: 8 GB ✅
- Storage: 40 GB ✅
- Build Time: 1.5-3 hours
- Success Rate: ~99%

---

*Last Updated: 2024-12-03*
*Based on experience building droidrun[google] dependencies in Termux*

