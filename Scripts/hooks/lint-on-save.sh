#!/bin/bash
# Lint only the saved Swift file. Used by the Kiro PostFileSave hook.
# Reads the hook payload (JSON) on stdin and looks for the saved file path.
set -u
cd "$(dirname "$0")/../.." || exit 0

payload="$(cat)"
file="$(printf '%s' "$payload" | python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
    tool_input = data.get("tool_input")
    if not isinstance(tool_input, dict):
        tool_input = {}
    for source in (data, tool_input):
        for key in ("file_path", "filePath", "path", "file"):
            value = source.get(key)
            if isinstance(value, str) and value:
                print(value)
                raise SystemExit
except SystemExit:
    raise
except Exception:
    pass
' 2>/dev/null)"

case "$file" in
    *.swift) ;;
    *) exit 0 ;;
esac
[ -f "$file" ] || exit 0

if ! command -v swiftlint >/dev/null 2>&1; then
    echo "SwiftLint is unavailable; skipped linting $file. Install it with: brew install swiftlint" >&2
    exit 0
fi

# Without Xcode.app, SwiftLint needs the Command Line Tools toolchain to find sourcekitd.
if [ -z "${TOOLCHAIN_DIR:-}" ]; then
    developer_dir="$(xcode-select -p 2>/dev/null)"
    case "$developer_dir" in */CommandLineTools) export TOOLCHAIN_DIR="$developer_dir" ;; esac
fi

if ! swiftlint lint --strict --quiet "$file" >&2; then
    echo "SwiftLint found violations in $file (output above)." >&2
    exit 2
fi
exit 0
