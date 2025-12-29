# Droidrun Installation Plan for Termux

## Current Status Assessment

### ✅ What's Already Installed

1. **System Packages:**
   - Python 3.12.12 ✅
   - pip 25.3 ✅
   - clang, cmake, rust (build tools) ✅
   - python-numpy, python-scipy, python-pillow, python-grpcio ✅

2. **Python Packages (via pip):**
   - droidrun 0.4.13 ✅ (installed)
   - llama-index and related packages ✅
   - aiohttp, httpx, aiofiles ✅
   - arize-phoenix ✅
   - Various other dependencies ✅

3. **Installation State:**
   - Phase 1 completed (build tools installed)
   - Installation logs exist
   - wheels directory exists (empty)

### ❌ Issues Found

1. **Import Error - Missing Dependency:**
   - `droidrun` package fails to import
   - Error: `ModuleNotFoundError: No module named 'dateutil'`
   - Root cause: `python-dateutil` package is missing
   - Required by: `posthog` → `droidrun.telemetry.tracker`
   - This is a simple missing dependency that can be fixed quickly

2. **Installation Incomplete:**
   - Only Phase 1 completed
   - Phases 2-7 may not be completed
   - Installation scripts not found in home directory

## Installation Plan

### Option 1: Complete Installation via Existing Script (Recommended)

**Steps:**
1. Copy installation script to Termux
2. Run the complete installation script
3. Verify all dependencies are installed
4. Test droidrun import and functionality

**Pros:**
- Uses existing, tested installation script
- Handles all phases automatically
- Includes error handling and logging

**Cons:**
- May take time to complete all phases
- Requires building some packages from source

### Option 2: Install Missing Dependencies Only (FASTEST - Recommended for Quick Fix)

**Steps:**
1. Install missing `python-dateutil` package:
   ```bash
   pip3 install python-dateutil
   ```
2. Test droidrun import
3. Check for any other missing dependencies
4. Install provider packages if needed

**Pros:**
- Fastest solution (seconds)
- Minimal changes
- Low risk

**Cons:**
- May discover more missing dependencies during testing
- Manual dependency resolution

### Option 3: Reinstall Droidrun with All Dependencies

**Steps:**
1. Uninstall current droidrun installation
2. Clear installation progress
3. Run full installation script
4. Verify complete installation

**Pros:**
- Clean slate
- Ensures all dependencies are correctly installed

**Cons:**
- Most time-consuming
- May rebuild packages unnecessarily

## Recommended Approach: Option 2 (Quick Fix) or Option 1 (Complete Installation)

**For immediate fix:** Use Option 2 to install `python-dateutil` and test
**For complete setup:** Use Option 1 to ensure all dependencies are properly installed

## Quick Fix Approach: Option 2 (Recommended First)

### Detailed Steps for Option 2

#### Step 1: Install Missing Dependency
```bash
adb shell "run-as com.termux sh -c 'export PATH=/data/data/com.termux/files/usr/bin:\$PATH && pip3 install python-dateutil'"
```

#### Step 2: Test Import
```bash
adb shell "run-as com.termux sh -c 'export PATH=/data/data/com.termux/files/usr/bin:\$PATH && python3 -c \"import droidrun; print(\"SUCCESS: droidrun imported\")\"'"
```

#### Step 3: Check for Other Missing Dependencies
If import succeeds, proceed to test functionality. If it fails, check error messages for other missing packages.

#### Step 4: Install Provider Packages (Optional)
```bash
adb shell "run-as com.termux sh -c 'export PATH=/data/data/com.termux/files/usr/bin:\$PATH && pip3 install \"droidrun[google,anthropic,openai,deepseek,ollama,openrouter]\"'"
```

---

## Complete Installation Approach: Option 1

### Detailed Steps

#### Phase 1: Prepare Environment
1. **Check repository availability**
   - Verify if droidrundepedency repository is accessible
   - If not, copy installation scripts to Termux

2. **Set up environment variables**
   ```bash
   export PATH=/data/data/com.termux/files/usr/bin:$PATH
   export PREFIX=/data/data/com.termux/files/usr
   export HOME=/data/data/com.termux/files/home
   ```

#### Phase 2: Copy Installation Scripts
1. Copy `installdroidrun.sh` to Termux home directory
2. Make it executable
3. Verify script is accessible

#### Phase 3: Run Installation
1. Execute installation script:
   ```bash
   bash ~/installdroidrun.sh
   ```
2. Monitor progress
3. Handle any errors that occur

#### Phase 4: Verify Installation
1. Test droidrun import:
   ```bash
   python3 -c "import droidrun; print('droidrun imported successfully')"
   ```
2. Check installed packages:
   ```bash
   pip3 list | grep -E "(droidrun|llama-index)"
   ```
3. Test basic functionality

#### Phase 5: Install Provider Extensions (Optional)
If needed, install provider packages:
```bash
pip3 install 'droidrun[google,anthropic,openai,deepseek,ollama,openrouter]'
```

## Files Needed

1. **Installation Script:**
   - `installdroidrun.sh` - Main installation script
   - Or use `installer_refactored/install_droidrun.sh` (modular version)

2. **Support Files (if needed):**
   - Any phase-specific scripts
   - Build scripts for problematic packages

## Potential Issues & Solutions

### Issue 1: Import Error
**Problem:** `droidrun` fails to import
**Solution:** 
- Check if all dependencies are installed
- Install missing packages
- Verify Python path

### Issue 2: Missing Build Tools
**Problem:** Packages fail to build
**Solution:**
- Install missing build tools via `pkg install`
- Set up build environment variables

### Issue 3: Disk Space
**Problem:** Insufficient disk space
**Solution:**
- Check available space: `df -h ~`
- Clean up unnecessary files
- Use pre-built wheels when available

### Issue 4: Memory Issues
**Problem:** Build processes fail due to memory
**Solution:**
- Limit parallel jobs: `export MAX_JOBS=1`
- Build packages one at a time

## Verification Checklist

- [ ] Python 3.12+ installed and working
- [ ] pip installed and working
- [ ] Build tools (clang, cmake, rust) installed
- [ ] Installation script copied and executable
- [ ] All phases completed successfully
- [ ] droidrun imports without errors
- [ ] Basic functionality test passes
- [ ] Provider packages installed (if needed)

## Estimated Time

- **Option 2 (Quick Fix - Missing Dependencies Only):** 1-2 minutes ⚡
- **Option 1 (Complete Installation):** 30-60 minutes
- **Option 3 (Reinstall):** 60-90 minutes

## Summary & Recommendation

**Current Issue:** Missing `python-dateutil` package (quick fix available)

**Recommended Action:** 
1. **First:** Try Option 2 (Quick Fix) - Install `python-dateutil` and test
2. **If more issues:** Proceed with Option 1 (Complete Installation)

**Why Option 2 First?**
- Takes only 1-2 minutes
- Low risk
- Most dependencies already installed
- Can always fall back to Option 1 if needed

## Next Steps

1. **Review this plan**
2. **Choose installation option**
3. **Confirm before proceeding**
4. **Execute installation**
5. **Verify and test**

---

**Note:** The installation script handles dependency resolution, build processes, and error handling. It's recommended to use the existing installation script rather than manual installation.

