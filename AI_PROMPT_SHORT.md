# Short AI Prompt for Termux SSH Setup

## Copy-Paste This Prompt

```
Help me set up SSH in Termux and connect via ADB.

Requirements:
1. Use ADB to execute commands in Termux (package: com.termux)
2. Detect username: adb shell "run-as com.termux whoami"
3. Install openssh in Termux via ADB
4. Set password (use: trex)
5. Start SSH server on port 8022
6. Setup ADB port forwarding: adb forward tcp:8022 tcp:8022
7. Connect via SSH from computer

Termux context:
- Home: /data/data/com.termux/files/home
- Prefix: /data/data/com.termux/files/usr/bin
- Execute via: run-as com.termux sh -c 'export PATH=/data/data/com.termux/files/usr/bin:$PATH && [command]'

Provide:
- Automated bash script
- Manual step-by-step commands
- Quick connect script for future use

All commands should be copy-paste ready.
```

---

## Even Shorter Version

```
Create script to SSH into Termux via ADB:
1. Detect username: adb shell "run-as com.termux whoami"
2. Install openssh in Termux via ADB
3. Set password: trex
4. Start SSH server (port 8022)
5. Port forward: adb forward tcp:8022 tcp:8022
6. Connect: ssh -p 8022 [username]@127.0.0.1

Termux execute: run-as com.termux sh -c 'export PATH=/data/data/com.termux/files/usr/bin:$PATH && [cmd]'

Provide bash script + manual commands.
```

