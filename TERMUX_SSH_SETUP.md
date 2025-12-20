# Termux SSH Setup Guide

## Quick Connection

If SSH is already set up, use one of these:

**Linux/Mac:**
```bash
bash connect_termux.sh [username] [host] [port]
# Example: bash connect_termux.sh username 192.168.1.100 8022
```

**Windows PowerShell:**
```powershell
.\connect_termux.ps1 -Username username -Host 192.168.1.100 -Port 8022
```

**Manual SSH:**
```bash
ssh -p 8022 username@127.0.0.1
# Password: trex
```

## Setting Up SSH on Termux

### Step 1: Install SSH Server

On your Termux device, run:
```bash
pkg update
pkg install openssh
```

### Step 2: Set Password

Set password for your user (default is usually your device username):
```bash
passwd
# Enter: trex
```

### Step 3: Start SSH Server

```bash
sshd
```

### Step 4: Get Connection Details

**Find your username:**
```bash
whoami
```

**Find your IP address:**
```bash
ifconfig | grep "inet " | grep -v 127.0.0.1
# Or
ip addr show | grep "inet " | grep -v 127.0.0.1
```

**Default SSH port:** 8022 (Termux uses non-standard port)

### Step 5: Connect from Another Machine

**If connecting from same network:**
```bash
ssh -p 8022 <username>@<termux_ip_address>
# Example: ssh -p 8022 u0_a123@192.168.1.100
```

**If using ADB port forwarding (from computer to Android device):**
```bash
# On your computer, forward port 8022
adb forward tcp:8022 tcp:8022

# Then connect to localhost
ssh -p 8022 <username>@127.0.0.1
```

## Common Issues

### Connection Refused
- **SSH server not running:** Run `sshd` in Termux
- **Wrong port:** Termux uses port 8022, not 22
- **Firewall:** Check if firewall is blocking the port

### Permission Denied
- **Wrong password:** Make sure password is set correctly with `passwd`
- **Wrong username:** Check with `whoami` in Termux

### Host Key Verification Failed
```bash
ssh-keygen -R "[127.0.0.1]:8022"
```

## Using the Helper Scripts

### Linux/Mac
```bash
# Basic usage (localhost with port forwarding)
bash connect_termux.sh

# Custom connection
bash connect_termux.sh u0_a123 192.168.1.100 8022
```

### Windows
```powershell
# Basic usage
.\connect_termux.ps1

# Custom connection
.\connect_termux.ps1 -Username u0_a123 -Host 192.168.1.100 -Port 8022
```

## ADB Port Forwarding (Recommended for Development)

If you're developing on a computer and want to connect to Termux on an Android device:

```bash
# Forward SSH port
adb forward tcp:8022 tcp:8022

# Now connect via localhost
ssh -p 8022 <username>@127.0.0.1
```

## Auto-start SSH on Termux Boot

Create `~/.termux/boot/start-sshd`:
```bash
#!/data/data/com.termux/files/usr/bin/bash
sshd
```

Make it executable:
```bash
chmod +x ~/.termux/boot/start-sshd
```

## Security Notes

- Change default password from "trex" to something secure
- Consider using SSH keys instead of passwords
- Only enable SSH when needed, disable when not in use

