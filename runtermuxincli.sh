adb shell 
run-as com.termux
export PATH=/data/data/com.termux/files/usr/bin:$PATH
export HOME=/data/data/com.termux/files/home
export PREFIX=/data/data/com.termux/files/usr
pkg update -y
pkg upgrade -y
pkg install -y python3-pip
