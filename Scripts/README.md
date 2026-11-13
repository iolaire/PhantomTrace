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

- `install-quick-action.sh`: installs the Finder Quick Action into `~/Library/Services`. Its shell test is `Tests/Scripts/install-quick-action-tests.sh` (temporary `HOME` only).
- `demo/setup-demo.sh`, `demo/teardown-demo.sh`, `demo/record-clip.sh`: throwaway demo drive with two locks, its cleanup, and short per-scene screen clips for the Remotion video in `demo/`. See `docs/demo-script.md`.
- `restore-finder-volume-sidebar.sh`: restores a volume (defaults to `Flash1GB`, or pass a volume name like `Scripts/restore-finder-volume-sidebar.sh PTQA`) to the Finder sidebar **Locations** section if it was accidentally dragged out or hidden (`visibility = 1` in `com.apple.LSSharedFileList.FavoriteVolumes.sfl4`).

## Image tooling (Python)

Look-and-feel image scripts use a uv-managed venv at `.venv/` (git-ignored). Dependencies are pinned in `requirements.txt`.

Set up:

```
uv venv .venv
uv pip install --python .venv/bin/python -r Scripts/requirements.txt
```

- `make-transparent-pngs.py`: converts `docs/LookAndFeel/original/base-images/*.jpg` (white background) to transparent PNGs in `docs/LookAndFeel/use/`. Per-image tuning (outline-gap sealing) is in `SEAL_RADIUS_OVERRIDES` at the top of the script.
- `make-proof-sheets.py`: builds `docs/LookAndFeel/proofs/proof-black.png` and `proof-white.png` from `docs/LookAndFeel/use/`.

Run with `.venv/bin/python Scripts/<script>.py`.
