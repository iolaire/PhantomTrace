# Scripts

- `lint-and-test.sh`: runs `swiftlint --strict`, then `swift test`.
- `hooks/commit-gate.sh`: used by the Kiro commit-time hooks (`checks` runs `lint-and-test.sh`, `gitignore` fails if `.gitignore` ignores `.kiro`). Acts only on `git commit`.
- `hooks/lint-on-save.sh`: used by the Kiro save hook to lint a single Swift file.

`install-quick-action.sh` is reserved for a later feature and is not present in the Scaffold.
- `check-project-log.sh`: commit-time hook script that requires `docs/ProjectLog.md` to be staged with code or config changes.
- `kiro-surface.sh`: detects which Kiro surface is running (`--details` adds version and evidence); `PHANTOMTRACE_KIRO_SURFACE` overrides. Used by `check-project-log.sh`, which also rejects new work-log rows with an invalid surface.
- `install-git-hooks.sh`: one-time setup per clone; sets `core.hooksPath` to `Scripts/git-hooks` so commits made by hand run the same checks.
- `git-hooks/pre-commit`: runs the `.kiro` guard and lint plus tests (`hooks/commit-gate.sh --git`). Lint and tests run only when a Swift, package, lint-config, or script file is staged.
- `git-hooks/commit-msg`: runs the project-log check (`check-project-log.sh --git`); `[skip-log]` in the message bypasses it.
