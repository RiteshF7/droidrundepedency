#!/usr/bin/env python3
with open("meson.build", "r") as f:
    lines = f.readlines()

# Fix line 5 (index 4) - replace version line with hardcoded version
lines[4] = "    version: '2.2.3',\n"

with open("meson.build", "w") as f:
    f.writelines(lines)

print("Fixed meson.build - line 5 now has version: '2.2.3'")

