#!/bin/bash
# One-time setup per clone: point git at the tracked hooks in Scripts/git-hooks.
# Sets repository-local config only (core.hooksPath).
set -eu
cd "$(dirname "$0")/.."
chmod +x Scripts/git-hooks/pre-commit Scripts/git-hooks/commit-msg
git config core.hooksPath Scripts/git-hooks
echo "Git hooks enabled: core.hooksPath = Scripts/git-hooks"
echo "To disable: git config --unset core.hooksPath"
