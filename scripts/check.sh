#!/bin/bash
# Checks available on Linux/macOS. A successful result does NOT mean an iOS build passed.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/checks
exec > >(tee build/checks/checks.log) 2>&1
date -u '+Checked at %Y-%m-%dT%H:%M:%SZ'
swift --version
python3 scripts/validate_project.py
bash -n scripts/build-ios.sh scripts/check.sh
echo 'PASS: shell syntax'
find App Core Storage Shared Widget FocusMonitor Tests -name '*.swift' -print0 | xargs -0 swiftc -frontend -parse
echo 'PASS: Swift syntax (parsing only; no iOS SDK type checking)'
swift test --scratch-path "${MAM_SWIFT_BUILD_DIR:-.build}" \
  -Xswiftc -warnings-as-errors -Xswiftc -strict-concurrency=complete
if command -v actionlint >/dev/null 2>&1; then
  actionlint .github/workflows/build-ios.yml
  echo 'PASS: GitHub Actions workflow lint'
else
  echo 'SKIP: actionlint is not installed; workflow lint was not run'
fi
echo 'DONE: available source checks. Run scripts/build-ios.sh on macOS to verify iOS compilation.'
