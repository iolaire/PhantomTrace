#!/bin/bash
# Commit-time gate used by Kiro PreToolUse hooks and by the git pre-commit hook.
#   commit-gate.sh checks [--git]     run Scripts/lint-and-test.sh (lint, then tests)
#   commit-gate.sh gitignore [--git]  fail if .gitignore ignores .kiro
#
# Kiro mode (default): reads the hook payload (JSON) on stdin and does nothing
# unless the shell command is a `git commit`.
# Git mode (--git): called by Scripts/git-hooks/pre-commit; stdin is not read and
# the commit is assumed. In git mode `checks` is skipped when no Swift, package,
# lint-config, or script file is staged, so docs-only commits stay fast.
# Exit 2 blocks the action and shows stderr; this script never edits files.
set -u
mode="${1:-}"
git_mode=0
[ "${2:-}" = "--git" ] && git_mode=1
root="$(cd "$(dirname "$0")/../.." && pwd)" || exit 0
cd "$root" || exit 0

if [ "$git_mode" -eq 0 ]; then
    payload="$(cat)"
    command_text="$(printf '%s' "$payload" | python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
    tool_input = data.get("tool_input") or data.get("toolArgs") or {}
    print(tool_input.get("command", "") if isinstance(tool_input, dict) else "")
except Exception:
    pass
' 2>/dev/null)"

    case "$command_text" in
        *"git commit"*) ;;
        *) exit 0 ;;
    esac
fi

case "$mode" in
    checks)
        if [ "$git_mode" -eq 1 ] && ! git diff --cached --name-only 2>/dev/null \
            | grep -Eq '\.swift$|^Package\.swift$|^\.swiftlint\.yml$|^Scripts/'; then
            exit 0
        fi
        if ! command -v swiftlint >/dev/null 2>&1; then
            echo "Commit blocked: SwiftLint is unavailable. Install it with: brew install swiftlint" >&2
            exit 2
        fi
        if ! "$root/Scripts/lint-and-test.sh" >&2; then
            echo "Commit blocked: lint or tests failed (output above)." >&2
            exit 2
        fi
        ;;
    gitignore)
        if [ -f .gitignore ] && grep -Eq '^[[:space:]]*/?\.kiro(/.*|\*)?[[:space:]]*$' .gitignore; then
            echo "Commit blocked: .gitignore ignores .kiro. Ignoring .kiro can disqualify the Kiroween submission." >&2
            exit 2
        fi
        ;;
    *)
        echo "commit-gate.sh: unknown mode '$mode'" >&2
        exit 0
        ;;
esac
exit 0
