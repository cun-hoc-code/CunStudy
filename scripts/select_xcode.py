#!/usr/bin/env python3
"""Select the newest installed, stable Xcode 26.x. Prints only its path."""
from pathlib import Path
import plistlib
import re
import sys

candidates = []
for app in Path("/Applications").glob("Xcode*.app"):
    if "beta" in app.name.lower():
        continue
    try:
        with (app / "Contents/version.plist").open("rb") as stream:
            version = plistlib.load(stream)["CFBundleShortVersionString"]
        numbers = tuple(int(n) for n in re.findall(r"\d+", version))
        if numbers[0] == 26:
            candidates.append((numbers, str(app)))
    except (OSError, KeyError, ValueError):
        pass
if not candidates:
    sys.exit("No stable Xcode 26 found on this runner. Inspect the runner-images macOS 15 software list.")
print(max(candidates)[1])
