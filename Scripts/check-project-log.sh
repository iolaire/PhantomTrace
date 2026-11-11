#!/bin/bash
# Blocks `git commit` when tracked code/config is staged but docs/ProjectLog.md is not.
# Also checks that new work-log rows in docs/ProjectLog.md name a valid Kiro surface.
# Used by .kiro/hooks/project-log-check.json (PreToolUse), which pipes hook JSON on stdin,
# and by Scripts/git-hooks/commit-msg as `check-project-log.sh --git <message-file>`.
# Exit 0 = allow, exit 2 = block (message on stderr).
if [ "${1:-}" = "--git" ]; then
  # Git commit-msg mode: $2 is the commit message file; treat it as a commit.
  input="git commit $(cat "${2:-/dev/null}" 2>/dev/null)"
else
  input=$(cat)
fi
case "$input" in
  *"git commit"*) ;;
  *) exit 0 ;;
esac
case "$input" in
  *"[skip-log]"*) exit 0 ;;
esac

staged=$(git diff --cached --name-only 2>/dev/null)
[ -z "$staged" ] && exit 0

here="$(cd "$(dirname "$0")" && pwd)"
detected=$("$here/kiro-surface.sh" --details 2>/dev/null)

if echo "$staged" | grep -qx 'docs/ProjectLog.md'; then
  # New work-log rows start with a date; column 2 must be a valid Kiro surface.
  bad=$(git diff --cached -U0 -- docs/ProjectLog.md \
    | grep -E '^\+\| ?20[0-9]{2}-[0-9]{2}-[0-9]{2} ' \
    | awk -F'|' '{gsub(/^ +| +$/, "", $3); print $3}' \
    | grep -vxE 'Kiro (IDE|CLI|Web|Crew|Mobile)|Unknown|Not recorded' || true)
  if [ -n "$bad" ] || git diff --cached -U0 -- docs/ProjectLog.md | grep -Eq '^\+\| ?20[0-9]{2}-[0-9]{2}-[0-9]{2} +\| *\|'; then
    echo "A new docs/ProjectLog.md work-log row has a missing or invalid 'Kiro surface' value." >&2
    echo "Use one of: Kiro IDE, Kiro CLI, Kiro Web, Kiro Crew, Kiro Mobile, Unknown, Not recorded." >&2
    echo "Detected here (surface | version | evidence): $detected" >&2
    exit 2
  fi
  exit 0
fi

if echo "$staged" | grep -Eq '^(Sources/|Tests/|Package\.swift|\.swiftlint\.yml|Scripts/|App/|\.kiro/(specs|steering|hooks)/)'; then
  echo "docs/ProjectLog.md is not staged. Add a work-log entry (and a decision or tool entry if relevant), stage it, then commit again. For trivial changes include [skip-log] in the commit message." >&2
  echo "Kiro surface detected here (surface | version | evidence): $detected" >&2
  exit 2
fi
exit 0
