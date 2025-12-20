# Manual SSH Setup and Connection Commands

## Step 1: Setup Port Forwarding (Run on your computer)
```bash
adb forward tcp:8022 tcp:8022
```

## Step 2: Install openssh in Termux (Run via ADB)
```bash
adb shell "run-as com.termux sh -c 'cd /data/data/com.termux/files/home && export PATH=/data/data/com.termux/files/usr/bin:\$PATH && pkg install -y openssh'"
```

## Step 3: Set Password in Termux (Run via ADB)
```bash
adb shell "run-as com.termux sh -c 'cd /data/data/com.termux/files/home && export PATH=/data/data/com.termux/files/usr/bin:\$PATH && (echo trex; echo trex) | passwd'"
```

## Step 4: Start SSH Server in Termux (Run via ADB)
```bash
adb shell "run-as com.termux sh -c 'cd /data/data/com.termux/files/home && export PATH=/data/data/com.termux/files/usr/bin:\$PATH && sshd'"
```

## Step 5: Connect via SSH (Run on your computer)
```bash
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p 8022 u0_a217@127.0.0.1
# When prompted, enter password: trex
```

---

## All-in-One Commands (Copy and paste each block)

### Complete Setup (Run these in order):
```bash
# 1. Port forwarding
adb forward tcp:8022 tcp:8022

# 2. Install openssh
adb shell "run-as com.termux sh -c 'cd /data/data/com.termux/files/home && export PATH=/data/data/com.termux/files/usr/bin:\$PATH && pkg install -y openssh'"

# 3. Set password
adb shell "run-as com.termux sh -c 'cd /data/data/com.termux/files/home && export PATH=/data/data/com.termux/files/usr/bin:\$PATH && (echo trex; echo trex) | passwd'"

# 4. Start SSH server
adb shell "run-as com.termux sh -c 'cd /data/data/com.termux/files/home && export PATH=/data/data/com.termux/files/usr/bin:\$PATH && sshd'"

# 5. Wait a moment, then connect
sleep 2
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p 8022 u0_a217@127.0.0.1
```

### Quick Connect (If SSH is already set up):
```bash
adb forward tcp:8022 tcp:8022
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p 8022 u0_a217@127.0.0.1
# Password: trex
```

---

## Connection Details
- **Username:** `u0_a217`
- **Host:** `127.0.0.1`
- **Port:** `8022`
- **Password:** `trex`

---

## Troubleshooting

### If connection is refused:
```bash
# Restart SSH server
adb shell "run-as com.termux sh -c 'cd /data/data/com.termux/files/home && export PATH=/data/data/com.termux/files/usr/bin:\$PATH && pkill sshd && sshd'"
```

### If password doesn't work:
```bash
# Reset password
adb shell "run-as com.termux sh -c 'cd /data/data/com.termux/files/home && export PATH=/data/data/com.termux/files/usr/bin:\$PATH && (echo trex; echo trex) | passwd'"
```

### Remove old host key (if needed):
```bash
ssh-keygen -R "[127.0.0.1]:8022"
```

