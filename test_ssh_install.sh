#!/usr/bin/env bash
# Script to SSH into Termux and test the installation script

# Check if expect is available, if not try to use sshpass or plink
if command -v expect >/dev/null 2>&1; then
    expect << 'EOF'
set timeout 30
spawn ssh -p 8022 username@127.0.0.1 "cd /data/data/com.termux/files/home/droidrundepedency && bash installdroidrun.sh"
expect {
    "password:" {
        send "trex\r"
        exp_continue
    }
    "Password:" {
        send "trex\r"
        exp_continue
    }
    "Are you sure you want to continue connecting" {
        send "yes\r"
        exp_continue
    }
    eof
}
EOF
elif command -v sshpass >/dev/null 2>&1; then
    sshpass -p 'trex' ssh -p 8022 username@127.0.0.1 "cd /data/data/com.termux/files/home/droidrundepedency && bash installdroidrun.sh"
elif command -v plink >/dev/null 2>&1; then
    echo "trex" | plink -ssh -P 8022 username@127.0.0.1 -pw trex "cd /data/data/com.termux/files/home/droidrundepedency && bash installdroidrun.sh"
else
    echo "Error: Need expect, sshpass, or plink to automate password authentication"
    echo "Attempting interactive SSH connection..."
    ssh -p 8022 username@127.0.0.1 "cd /data/data/com.termux/files/home/droidrundepedency && bash installdroidrun.sh"
fi

