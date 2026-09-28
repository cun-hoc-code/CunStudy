#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

scheme="${1:-MamStudy}"
case "$scheme" in MamStudy|MamStudyBasic|MamStudyManaged) ;; *) echo "Unknown scheme: $scheme" >&2; exit 2;; esac
if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "This script needs macOS with Xcode 26+. On Arch/Windows, use GitHub Actions." >&2
  exit 2
fi
if ! command -v xcodegen >/dev/null 2>&1; then
  echo "XcodeGen is missing. On macOS install it with: brew install xcodegen" >&2
  exit 2
fi
major=$(xcodebuild -version | awk '/Xcode / {split($2, a, "."); print a[1]}')
case "$major" in ''|*[!0-9]*) echo "Cannot determine Xcode version." >&2; exit 2;; esac
if [ "$major" -lt 26 ]; then
  echo "Xcode 26+ is required to compile AlarmKit. Select an Xcode 26 installation first." >&2
  exit 2
fi
mkdir -p "build/$scheme/logs"
# Remove only previous generated outputs: a failed rebuild must not expose an old IPA.
rm -f "build/$scheme/$scheme-unsigned.ipa" "build/$scheme/SHA256SUMS.txt"
xcodegen generate --spec project.yml 2>&1 | tee "build/$scheme/logs/xcodegen.log"
python3 scripts/validate_project.py 2>&1 | tee "build/$scheme/logs/structure.log"
swift test -Xswiftc -warnings-as-errors -Xswiftc -strict-concurrency=complete 2>&1 | tee "build/$scheme/logs/core-tests.log"
xcodebuild -version > "build/$scheme/logs/toolchain.txt"
xcodebuild -showsdks >> "build/$scheme/logs/toolchain.txt"
xcodebuild -project MamStudy.xcodeproj -scheme "$scheme" -configuration Release \
  -destination 'generic/platform=iOS' -sdk iphoneos -derivedDataPath "build/$scheme/DerivedData" \
  -resultBundlePath "build/$scheme/result-$(date +%Y%m%d%H%M%S)-$$.xcresult" \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" \
  build 2>&1 | tee "build/$scheme/logs/xcodebuild.log"
app_path="build/$scheme/DerivedData/Build/Products/Release-iphoneos/$scheme.app"
test -d "$app_path"
test -s "$app_path/$scheme"
file "$app_path/$scheme" | tee "build/$scheme/logs/binary.txt"
file "$app_path/$scheme" | grep -q 'Mach-O'
if [ "$scheme" != "MamStudyBasic" ]; then
  test -s "$app_path/PlugIns/MamStudyWidgets.appex/MamStudyWidgets"
  file "$app_path/PlugIns/MamStudyWidgets.appex/MamStudyWidgets" | grep -q 'Mach-O'
fi
if [ "$scheme" = "MamStudyManaged" ]; then
  test -s "$app_path/PlugIns/MamFocusMonitor.appex/MamFocusMonitor"
  file "$app_path/PlugIns/MamFocusMonitor.appex/MamFocusMonitor" | grep -q 'Mach-O'
fi
staging=$(mktemp -d "$(pwd)/build/$scheme/staging.XXXXXX")
trap 'rm -rf "$staging"' EXIT
mkdir -p "$staging/Payload"
ditto "$app_path" "$staging/Payload/$scheme.app"
(cd "$staging" && zip -qry "../$scheme-unsigned.ipa" Payload)
unzip -t "build/$scheme/$scheme-unsigned.ipa"
shasum -a 256 "build/$scheme/$scheme-unsigned.ipa" > "build/$scheme/SHA256SUMS.txt"
echo "Created build/$scheme/$scheme-unsigned.ipa (unsigned; re-sign before installing)."
