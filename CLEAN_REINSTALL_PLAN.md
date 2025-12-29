# Clean Reinstall Plan for Droidrun

## Approach: Complete Clean Reinstall

### Phase 1: Uninstall Droidrun and Related Packages
1. Uninstall droidrun package via pip
2. Uninstall droidrun-related Python packages
3. Clean up installation logs and progress files
4. Remove wheels directory (optional)

### Phase 2: Reinstall Using Installation Script
1. Copy installation script to Termux
2. Run complete installation
3. Verify all dependencies

## Commands to Execute

### Step 1: Uninstall
```bash
adb shell "run-as com.termux sh -c 'export PATH=/data/data/com.termux/files/usr/bin:\$PATH && pip3 uninstall -y droidrun'"
```

### Step 2: Clean Installation Files
```bash
adb shell "run-as com.termux sh -c 'rm -f ~/.droidrun_install* ~/.droidrun_*'"
```

### Step 3: Copy Installation Script
```bash
adb push installdroidrun.sh /data/local/tmp/
adb shell "run-as com.termux sh -c 'cp /data/local/tmp/installdroidrun.sh ~/ && chmod +x ~/installdroidrun.sh'"
```

### Step 4: Run Installation
```bash
adb shell "run-as com.termux sh -c 'export PATH=/data/data/com.termux/files/usr/bin:\$PATH && bash ~/installdroidrun.sh'"
```



