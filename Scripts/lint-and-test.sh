#!/bin/bash
set -u
# SwiftLint needs its frameworks on Command Line Tools installs.
if [ "$(xcode-select -p 2>/dev/null)" = "/Library/Developer/CommandLineTools" ] \
    && [ -d /Library/Developer/CommandLineTools/usr/lib ]; then
    export DYLD_FRAMEWORK_PATH=/Library/Developer/CommandLineTools/usr/lib
fi
cd "$(dirname "$0")/.." || exit 1
swiftlint --strict || exit 1
swift test || exit 1
