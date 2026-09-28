#!/usr/bin/env python3
"""Structural checks only. This does NOT replace an iOS compile or device tests."""
import json
import plistlib
import struct
import re
from collections import Counter
from pathlib import Path
import sys

root = Path(__file__).resolve().parents[1]
for path in sorted(root.glob("Config/*")):
    with path.open("rb") as stream:
        plistlib.load(stream)
with (root / "Resources/PrivacyInfo.xcprivacy").open("rb") as stream:
    plistlib.load(stream)
for contents in root.glob("Resources/**/*.json"):
    data = json.loads(contents.read_text())
    for icon in data.get("images", []):
        if "filename" in icon:
            image = contents.parent / icon["filename"]
            assert image.is_file(), icon
            png = image.read_bytes()
            assert png[:8] == b"\x89PNG\r\n\x1a\n", image
            width, height, depth, color = struct.unpack(">IIBB", png[16:26])
            expected = round(float(icon["size"].split("x")[0]) * float(icon["scale"].removesuffix("x")))
            assert width == height == expected, (image, width, height, expected)
            assert depth == 8 and color == 2, "App icons must be opaque RGB"
required = [
    "App/MamStudyApp.swift", "App/ReminderService.swift", "Widget/MamWidgets.swift",
    "Package.swift", ".github/workflows/build-ios.yml", "Core/StudyProgress.swift",
    "Shared/FocusActivityAttributes.swift", "App/FocusActivityService.swift",
    "Widget/FocusLiveActivity.swift", "App/ReviewHistoryView.swift", "Shared/AdaptiveColor.swift",
    "App/ImportCenter.swift", "App/BookshelfView.swift", "App/BookPages.swift",
    "App/SmoothTabHost.swift", "App/InteractionFeedback.swift", "Core/ReadingModels.swift",
]
for name in required:
    assert (root / name).is_file(), name
app_plist = plistlib.loads((root / "Config/App-Info.plist").read_bytes())
assert app_plist["NSAlarmKitUsageDescription"]
assert app_plist["StudyAppGroup"] == "$(STUDY_APP_GROUP)"
assert app_plist["StudyWidgetsEnabled"] == "$(STUDY_WIDGETS_ENABLED)"
assert app_plist["NSSupportsLiveActivities"] is True
assert app_plist.get("UIUserInterfaceStyle") != "Light", "Dark mode must not be blocked by Info.plist"
widget_plist = plistlib.loads((root / "Config/Widget-Info.plist").read_bytes())
assert widget_plist["StudyAppGroup"] == app_plist["StudyAppGroup"]
entitlements = plistlib.loads((root / "Config/MamStudy.entitlements").read_bytes())
assert entitlements["com.apple.security.application-groups"] == [app_plist["StudyAppGroup"]]
assert widget_plist["NSExtension"]["NSExtensionPointIdentifier"] == "com.apple.widgetkit-extension"
print("PASS: plist, privacy manifest, icon sizes/RGB, required files, widget group wiring")
print("PASS: Live Activity declaration and system/light/dark configuration")
project = root / "MamStudy.xcodeproj/project.pbxproj"
if project.is_file():
    contents = project.read_text()
    counts = Counter(re.findall(r'/\* (\w+\.swift) in Sources \*/ = \{isa = PBXBuildFile;', contents))
    for directory, expected in {"App": 3, "Storage": 3, "Core": 4, "Shared": 4, "Widget": 1, "FocusMonitor": 1}.items():
        for source in (root / directory).glob("*.swift"):
            assert counts[source.name] == expected, f"Regenerate Xcode project: {source.name} has {counts[source.name]} source entries, expected {expected}"
    print("PASS: every Swift file belongs to the expected app/basic/widget targets")
print("Run swift test for core behavior and scripts/build-ios.sh on macOS for iOS compile.")

for key in ["NSCameraUsageDescription", "NSMicrophoneUsageDescription", "NSFaceIDUsageDescription", "NSCalendarsFullAccessUsageDescription"]:
    assert app_plist.get(key), key
assert set(app_plist["CFBundleLocalizations"]) == {"vi", "en"}
assert "audio" in app_plist["UIBackgroundModes"]
managed = plistlib.loads((root / "Config/MamStudyManaged.entitlements").read_bytes())
monitor = plistlib.loads((root / "Config/FocusMonitor.entitlements").read_bytes())
assert managed["com.apple.developer.family-controls"] is True
assert monitor["com.apple.developer.family-controls"] is True
assert managed["com.apple.security.application-groups"] == entitlements["com.apple.security.application-groups"]
for name in ["rain", "cafe", "white"]:
    import wave
    with wave.open(str(root / "Resources/Sounds" / (name + ".wav"))) as audio:
        assert audio.getnchannels() == 1 and audio.getsampwidth() == 2 and audio.getnframes() > 0
for name in ["tap", "selection", "page", "success"]:
    import wave
    with wave.open(str(root / "Resources/Sounds" / ("feedback-" + name + ".wav"))) as audio:
        assert audio.getnchannels() == 1 and audio.getsampwidth() == 2 and audio.getnframes() > 0
for locale in ["vi", "en"]:
    rows = (root / "Resources" / (locale + ".lproj") / "Localizable.strings").read_text().splitlines()
    assert len(rows) >= 300
    for row in rows:
        key, value = row.removesuffix(';').split(' = ', 1)
        assert isinstance(json.loads(key), str) and isinstance(json.loads(value), str)
if project.is_file():
    for resource in ["Localizable.strings", "InfoPlist.strings", "rain.wav", "cafe.wav", "white.wav",
                     "feedback-tap.wav", "feedback-selection.wav", "feedback-page.wav", "feedback-success.wav"]:
        assert resource in contents, resource
reader = (root / "App/BookPages.swift").read_text()
assert reader.count("ReadingFont(id:") >= 10, "Reader must expose at least ten readable fonts"
assert ".pageCurl" in reader and ".scroll" in reader, "Reader needs curl and reduced-motion modes"
assert "fileprivate func controller(at" in reader, "Page controller access level is invalid"
imports = (root / "App/ImportCenter.swift").read_text()
for feature in ["PhotosPicker", "PDFDocument", "TextRecognition", "NSAttributedString", "TextFileDecoder"]:
    assert feature in imports, feature
assert "format = .docFormat" not in imports, "Legacy DOC import is not portable across iOS SDKs"
assert "DocumentType.officeOpenXML" not in imports, "DOCX import must compile across iOS SDKs"
motion = (root / "App/Motion.swift").read_text()
app_root = (root / "App/MamStudyApp.swift").read_text()
assert "var mamReduceMotion: Bool" in motion
assert ".environment(\n          \\.accessibilityReduceMotion" not in app_root, "System Reduce Motion is read-only"
project_spec = (root / "project.yml").read_text()
assert "MARKETING_VERSION: 2.1.0" in project_spec
assert "CURRENT_PROJECT_VERSION: '6'" in project_spec
print("PASS: v2 permissions, Managed entitlements, ambient audio and localization resources")
print("PASS: v2.1 import center, book reader/page curl, ten fonts and interaction feedback")
