# AI Prompt: Setup SSH in Termux and Connect via ADB

## Prompt Template

```
I need to set up SSH in Termux (Android terminal emulator) and connect to it via ADB from my computer.

Context:
- I have an Android device connected via ADB
- Termux is installed on the device
- I want to SSH into Termux from my computer
- Username in Termux: [DETECT_VIA_ADB or PROVIDE_USERNAME]
- Desired password: [PROVIDE_PASSWORD]
- Termux uses non-standard SSH port: 8022

Requirements:
1. Use ADB to execute commands in Termux (package: com.termux)
2. Install openssh package in Termux if not already installed
3. Set password for the Termux user
4. Start SSH server in Termux
5. Setup ADB port forwarding (localhost:8022 -> Termux:8022)
6. Connect via SSH from my computer
7. Provide both automated script and manual commands

Important Notes:
- Termux home: /data/data/com.termux/files/home
- Termux prefix: /data/data/com.termux/files/usr
- Use "run-as com.termux" to execute commands in Termux context
- Termux PATH needs to be set: /data/data/com.termux/files/usr/bin
- SSH server runs on port 8022 (not standard 22)
- Password authentication must be enabled

Deliverables:
1. Automated bash script that does everything
2. Step-by-step manual commands I can copy/paste
3. Quick connect script for future use
4. Troubleshooting commands for common issues

Please provide clean, working commands that I can execute directly.
```

---

## Alternative: Specific Task Prompt

```
Help me connect to Termux via SSH using ADB.

Current situation:
- Android device connected via ADB
- Termux installed (package: com.termux)
- Need to: install openssh, set password, start SSH, and connect

Constraints:
- Must use ADB to execute commands in Termux
- Termux path: /data/data/com.termux/files/usr
- SSH port: 8022
- Username: [detect via: adb shell "run-as com.termux whoami"]

Provide:
1. ADB commands to install openssh in Termux
2. ADB command to set password
3. ADB command to start SSH server
4. Port forwarding command
5. SSH connection command
6. All commands should be copy-paste ready
```

---

## Quick Reference Prompt

```
Create a script to:
1. Detect Termux username via ADB: adb shell "run-as com.termux whoami"
2. Install openssh in Termux via ADB
3. Set password via ADB
4. Start SSH server via ADB
5. Setup port forwarding: adb forward tcp:8022 tcp:8022
6. Connect via SSH: ssh -p 8022 [username]@127.0.0.1

Termux paths:
- Home: /data/data/com.termux/files/home
- Prefix: /data/data/com.termux/files/usr
- Execute via: run-as com.termux sh -c 'export PATH=/data/data/com.termux/files/usr/bin:$PATH && [command]'
```

---

## Example Usage

Copy one of the prompts above and paste it into your AI assistant. The AI will generate:
- Complete setup scripts
- Manual step-by-step commands
- Connection scripts
- Troubleshooting commands

---

## Key Information to Include in Prompt

When using this prompt, customize these values:

1. **Username**: Either ask AI to detect it or provide manually
   ```bash
   adb shell "run-as com.termux whoami"
   ```

2. **Password**: Your desired password (default examples use "trex")

3. **Port**: Usually 8022 for Termux

4. **Environment**: 
   - Windows (PowerShell/CMD)
   - Linux/Mac (Bash)
   - WSL

---

## Expected Output from AI

The AI should provide:

1. **Setup Script** (`adb_setup_ssh_termux.sh`)
   - Installs openssh
   - Sets password
   - Starts SSH server
   - Sets up port forwarding
   - Connects automatically

2. **Manual Commands** (copy-paste ready)
   - Each step as separate command
   - Clear comments
   - Error handling

3. **Quick Connect Script** (`quick_connect_termux.sh`)
   - Assumes SSH already set up
   - Just port forwarding + connect

4. **Troubleshooting Commands**
   - Restart SSH server
   - Reset password
   - Check SSH status
   - Remove host keys

---

## Tips for Best Results

1. **Be specific about environment**: Mention if you're on Windows/Linux/Mac
2. **Include error messages**: If you've tried before and got errors, include them
3. **Specify automation level**: Do you want a script or just commands?
4. **Mention tools available**: sshpass, expect, plink, etc.

---

## Minimal Prompt (Copy This)

```
I need to SSH into Termux on Android via ADB. 

Setup needed:
- Install openssh in Termux via ADB
- Set password for Termux user (detect username first)
- Start SSH server
- Port forward 8022 via ADB
- Connect via SSH

Termux paths:
- Home: /data/data/com.termux/files/home  
- Prefix: /data/data/com.termux/files/usr
- Execute: run-as com.termux sh -c 'export PATH=/data/data/com.termux/files/usr/bin:$PATH && [cmd]'

Provide bash script and manual commands.
```

