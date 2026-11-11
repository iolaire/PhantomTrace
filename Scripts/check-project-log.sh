#!/bin/bash
# Blocks `git commit` when tracked code/config is staged but docs/ProjectLog.md is not.
# Used by .kiro/hooks/project-log-check.json (PreToolUse). Reads hook JSON on stdin.
# Exit 0 = allow, exit 2 = block (message on stderr).
input=$(cat)
case "$input" in
  *"git commit"*) ;;
  *) exit 0 ;;
esac
case "$input" in
  *"[skip-log]"*) exit 0 ;;
esac

staged=$(git diff --cached --name-only 2>/dev/null)
[ -z "$staged" ] && exit 0

if echo "$staged" | grep -qx 'docs/ProjectLog.md'; then
  exit 0
fi

if echo "$staged" | grep -Eq '^(Sources/|Tests/|Package\.swift|\.swiftlint\.yml|Scripts/|App/|\.kiro/(specs|steering|hooks)/)'; then
  echo "docs/ProjectLog.md is not staged. Add a work-log entry (and a decision or tool entry if relevant), stage it, then commit again. For trivial changes include [skip-log] in the commit message." >&2
  exit 2
fi
exit 0
