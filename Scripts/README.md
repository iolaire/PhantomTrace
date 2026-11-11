# Scripts

Developer scripts. Lint and test:

- `lint-and-test.sh`: runs `swiftlint --strict`, then `swift test`.

Kiro hook scripts (act only on `git commit` unless noted):

- `hooks/commit-gate.sh`: used by the Kiro commit-time hooks (`checks` runs `lint-and-test.sh`, `gitignore` fails if `.gitignore` ignores `.kiro`).
- `hooks/lint-on-save.sh`: used by the Kiro save hook to lint a single Swift file.
- `check-project-log.sh`: requires `docs/ProjectLog.md` to be staged with code or config changes, and rejects new work-log rows with an invalid Kiro surface.
- `kiro-surface.sh`: detects which Kiro surface is running (`--details` adds version and evidence); `PHANTOMTRACE_KIRO_SURFACE` overrides. Detects Kiro IDE and Kiro Web; Kiro CLI is best effort; Crew and Mobile are not detected.

Git hooks, so commits made by hand run the same checks:

- `install-git-hooks.sh`: one-time setup per clone; sets `core.hooksPath` to `Scripts/git-hooks`.
- `git-hooks/pre-commit`: runs the `.kiro` guard and lint plus tests (`hooks/commit-gate.sh --git`). Lint and tests run only when a Swift, package, lint-config, or script file is staged.
- `git-hooks/commit-msg`: runs the project-log check (`check-project-log.sh --git`); `[skip-log]` in the message bypasses it.

Scaffold verification:

- `verify-scaffold.sh`: checks the repository against the scaffolding spec (required files, links, docs content, steering and hook shape).

Not present yet: `install-quick-action.sh`, reserved for the app feature.
