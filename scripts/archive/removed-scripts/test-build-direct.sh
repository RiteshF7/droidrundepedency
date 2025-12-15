#!/bin/bash
cd droidrun-main
python -m build --wheel --outdir ../wheels/aarch64 2>&1
sleep 2
if [ -f ../wheels/aarch64/droidrun-*.whl ]; then
    echo "✅ Wheel found!"
    ls -lh ../wheels/aarch64/*.whl
else
    echo "❌ Wheel not found"
    find ../wheels -name "*.whl" 2>/dev/null
fi
