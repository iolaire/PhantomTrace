#!/bin/bash
# Run SwiftLint (strict) first, then the test suite. Stops at the first failure.
set -u
cd "$(dirname "$0")/.." || exit 1

if ! command -v swiftlint >/dev/null 2>&1; then
    echo "SwiftLint is unavailable. Install it with: brew install swiftlint" >&2
    exit 1
fi

# Without Xcode.app, SwiftLint cannot find sourcekitd unless it is pointed at the
# Command Line Tools toolchain.
if [ -z "${TOOLCHAIN_DIR:-}" ]; then
    developer_dir="$(xcode-select -p 2>/dev/null)"
    case "$developer_dir" in */CommandLineTools) export TOOLCHAIN_DIR="$developer_dir" ;; esac
fi

swiftlint --strict || exit 1
swift test || exit 1
