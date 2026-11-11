# Scripts

- `lint-and-test.sh`: runs `swiftlint --strict`, then `swift test`.
- `hooks/commit-gate.sh`: used by the Kiro commit-time hooks (`checks` runs `lint-and-test.sh`, `gitignore` fails if `.gitignore` ignores `.kiro`). Acts only on `git commit`.
- `hooks/lint-on-save.sh`: used by the Kiro save hook to lint a single Swift file.

`install-quick-action.sh` is reserved for a later feature and is not present in the Scaffold.
- `check-project-log.sh`: commit-time hook script that requires `docs/ProjectLog.md` to be staged with code or config changes.
