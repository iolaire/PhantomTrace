#!/bin/bash
# Run SwiftLint (strict) first, then the test suite. Stops at the first failure.
set -u
cd "$(dirname "$0")/.." || exit 1

if ! command -v swiftlint >/dev/null 2>&1; then
    echo "SwiftLint is unavailable. Install it with: brew install swiftlint" >&2
    exit 1
fi

swiftlint --strict || exit 1
swift test || exit 1
