# Commit all changes and push to remote
git add .
git commit -m "Automated: Run install script on device using adb"
git push

# Run droidrun install via adb shell in Termux environment with restore, pull, and chmod
cd /e/Code/LunarLand/MiniLinux/droidrunBuild && \
adb shell "run-as com.termux /data/data/com.termux/files/usr/bin/bash -c ' \
    export PATH=/data/data/com.termux/files/usr/bin:/data/data/com.termux/files/usr/bin/applets:\$PATH && \
    export PREFIX=/data/data/com.termux/files/usr && \
    cd /data/data/com.termux/files/home/droidrundepedency && \
    git restore . && \
    git pull && \
    chmod +x installdroidrun.sh && \
    /data/data/com.termux/files/usr/bin/bash installdroidrun.sh \
'"

