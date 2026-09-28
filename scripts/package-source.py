#!/usr/bin/env python3
"""Package source and verification notes; never include caches, signing keys or fake IPAs."""
import argparse
import hashlib
from pathlib import Path
import zipfile

parser = argparse.ArgumentParser()
parser.add_argument("--output", type=Path)
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
output = args.output or root.parent / "MamStudy-source.zip"
excluded = {".build", "build", ".git", "__pycache__", "xcuserdata", ".swiftpm"}
forbidden_suffixes = {".ipa", ".p12", ".pfx", ".mobileprovision", ".cer", ".key", ".pyc"}
files = sorted(p for p in root.rglob("*") if p.is_file() and not p.is_symlink()
    and not any(part in excluded for part in p.relative_to(root).parts)
    and p.suffix not in forbidden_suffixes and p.name != ".DS_Store" and p.resolve() != output.resolve())
output.parent.mkdir(parents=True, exist_ok=True)
with zipfile.ZipFile(output, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
    for path in files:
        archive.write(path, Path(root.name) / path.relative_to(root))
with zipfile.ZipFile(output) as archive:
    assert archive.testzip() is None
    names = set(archive.namelist())
    for required in [
        "MamStudy/.github/workflows/build-ios.yml",
        "MamStudy/MamStudy.xcodeproj/project.pbxproj",
        "MamStudy/App/ImportCenter.swift",
        "MamStudy/App/BookshelfView.swift",
        "MamStudy/App/BookPages.swift",
        "MamStudy/App/SmoothTabHost.swift",
        "MamStudy/App/InteractionFeedback.swift",
        "MamStudy/docs/UPGRADE-v2.1.md",
        "MamStudy/Verification/UPDATE-v2.1-STATUS.md",
    ]:
        assert required in names, required
    assert not any("/.build/" in name or "/xcuserdata/" in name for name in names)
print(f"{output}: {len(files)} files, {output.stat().st_size} bytes")
print("SHA256", hashlib.sha256(output.read_bytes()).hexdigest())
