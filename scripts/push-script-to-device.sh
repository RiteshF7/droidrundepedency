#!/bin/bash
# Helper script to push build script to device

SCRIPT_FILE="scripts/build-all-wheels-automated.sh"

# Read script content and encode
CONTENT=$(cat "$SCRIPT_FILE" | base64 -w 0 2>/dev/null || cat "$SCRIPT_FILE" | base64)

# Write to device using Python
adb shell "run-as com.termux sh -c '
export PREFIX=/data/data/com.termux/files/usr
export HOME=/data/data/com.termux/files/home
export PATH=\$PREFIX/bin:\$PATH
python3 << \"PYEOF\"
import base64
import sys
content = \"\"\"$CONTENT\"\"\"
try:
    decoded = base64.b64decode(content)
    with open(\"/data/data/com.termux/files/home/build-all-wheels-automated.sh\", \"wb\") as f:
        f.write(decoded)
    print(\"Script written successfully\")
except Exception as e:
    print(f\"Error: {e}\")
    sys.exit(1)
PYEOF
chmod +x \$HOME/build-all-wheels-automated.sh
echo \"Script is ready at \$HOME/build-all-wheels-automated.sh\"
'"


