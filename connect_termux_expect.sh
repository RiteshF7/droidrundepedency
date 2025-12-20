#!/usr/bin/env bash
# Connect to Termux using expect
expect << 'EOF'
set timeout 10
spawn ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p 8022 u0_a217@127.0.0.1
expect {
    "password:" {
        send "trex\r"
    }
    "Password:" {
        send "trex\r"
    }
    timeout {
        puts "Connection timeout"
        exit 1
    }
}
expect {
    "$ " {
        send "whoami\r"
        expect "$ "
        send "pwd\r"
        expect "$ "
        interact
    }
    "~" {
        send "whoami\r"
        expect "~"
        send "pwd\r"
        expect "~"
        interact
    }
    eof
}
EOF

