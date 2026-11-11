# Project Log

Living record of the work, the tools we use, and the decisions we make. Update it in the same commit as the change it describes (enforced by `.kiro/hooks/project-log-check.json`; see `.kiro/steering/documentation.md`).

Newest entries go at the top of each section. Dates are YYYY-MM-DD (UTC). The "Kiro surface" column records which Kiro app did the work; the hackathon write-up asks how they differed. Allowed values: Kiro IDE, Kiro CLI, Kiro Web, Kiro Crew, Kiro Mobile, Unknown, Not recorded. Run `Scripts/kiro-surface.sh --details` to detect it (see D-007).

## Work log

| Date | Kiro surface | Change | Spec refs | Verified how |
|---|---|---|---|---|
| 2026-11-11 | Kiro Web | Docs review: wrote `docs/architecture.md` (layers, data flow, state machine, pipeline, safety, status table), `docs/LookAndFeel/README.md` (describes the new reference art; image origin and license flagged as unknown), a full timed `docs/demo-script.md`, `docs/README.md` index; added status and doc map to `ProjectOverview.md`; refreshed SubmissionChecklist known gaps, README docs links, and `Scripts/README.md` | project-scaffolding R5; master spec design | `Scripts/verify-scaffold.sh` passes (links, headings, 180-second sentence); viewed the three composed mockups; base images described from file names only. Not built (Linux sandbox) |
| 2026-11-11 | Kiro IDE | Ran the project-scaffolding task list: wrote `Scripts/verify-scaffold.sh` and `Scripts/lint-and-test.sh`; moved tests from XCTest to Swift Testing, loading the Command Line Tools macro plugin from `Package.swift` (see D-010); added `DYLD_FRAMEWORK_PATH` for SwiftLint to the lint scripts; changed the LICENSE holder in Requirement 4.1, design, and tasks to `iolaire mcfadden` | project-scaffolding R2, R4.1, R8, tasks 1.2, 3.3, 4.1, 4.2, 5 | On macOS 27.2.1 with Command Line Tools only: `swift build`, `swift test` (2 placeholder tests), `swiftlint --strict` (0 violations), `Scripts/verify-scaffold.sh`, and `Scripts/lint-and-test.sh` all exit 0. Hook scripts not run on their own; hooks not confirmed live. Task 6 (manual submission checks) still open |
| 2026-11-11 | Kiro Web | Synced local `main` with PR #1 and the IDE hook work; taught `Scripts/kiro-surface.sh` to detect Kiro Web from `AWS_SDK_UA_APP_ID=kiro-web` and `KIRO_CUSTOM_USER_AGENT=KiroWeb/*` (see D-009) | project-scaffolding R7 | Ran the script in this Kiro Web sandbox (reports Kiro Web 1.0.0) and with simulated IDE, no-marker, and override environments; `bash -n` clean. Not built; SwiftLint and Swift are not available in this Linux sandbox |
| 2026-11-11 | Kiro Web | Created `docs/ProjectLog.md`, the `project-log-check` hook, and `Scripts/check-project-log.sh` (see D-005); committed on a branch and merged via PR #1 because agent commits to `main` are not allowed | n/a | Tested the check script by hand against staged files (no staged files, code without log, code with log). Hook not confirmed live. Not built (Linux sandbox) |
| 2026-11-11 | Kiro IDE | Added real git hooks (`Scripts/git-hooks/pre-commit`, `commit-msg`, `Scripts/install-git-hooks.sh`) that call the same scripts; added `--git` mode to `commit-gate.sh` and `check-project-log.sh`; lint scripts now set `TOOLCHAIN_DIR` when only Command Line Tools are installed (see D-008) | project-scaffolding R7, R8 | Tested real `git commit` in a temporary repo with real SwiftLint and a stubbed `swift`: docs-only, clean Swift, missing log, `[skip-log]`, lint violation, ignored `.kiro`, invalid and valid surface. Hooks not enabled in this repo (`core.hooksPath` unset). `swift test` fails on this machine (Swift Testing macros missing from Command Line Tools), so the full gate has not passed here |
| 2026-11-11 | Kiro IDE | Added `Scripts/kiro-surface.sh` (detects the Kiro surface) and made `Scripts/check-project-log.sh` reject new work-log rows with a missing or invalid surface and report the detected surface when it blocks (see D-007) | project-scaffolding R7 | Tested detection with simulated IDE, IDE-hook, VS Code terminal, no-marker, and override environments; tested the commit check in a temporary repo (valid, invalid, empty surface; code without log). Hook not yet confirmed live. Kiro CLI, Web, Crew, and Mobile detection not verified |
| 2026-11-11 | Kiro IDE | Replaced stale SwiftCheck references with swift-property-based (`Package.swift` is the source of truth) in the scaffolding spec, README, and KiroUsage (follow-up to D-003) | project-scaffolding R2.9, R4, R6, R9 | Searched docs for leftover references; not built |
| 2026-11-11 | Kiro IDE | Added three hooks (`lint-on-save`, `pre-commit-check`, `kiro-gitignore-guard`) and scripts `Scripts/hooks/commit-gate.sh`, `Scripts/hooks/lint-on-save.sh`, `Scripts/lint-and-test.sh` (see D-006) | project-scaffolding R7, R8.1-8.4 | Scripts run with sample payloads: non-commit, empty, garbage, commit without SwiftLint (blocks), bad and clean `.gitignore`, non-Swift file. Hooks not yet confirmed live in Kiro. SwiftLint not installed here, so the lint path never ran. Not built |
| 2026-11-11 | Kiro IDE | Updated the scaffolding spec (requirements, design, tasks) against the Kiroween 2026 rules: macOS 27.2.1 only, new Requirement 9 (submission readiness), README and docs content rules, six steering files, three hooks, manual submission task | project-scaffolding R2-R7, R9 | Reviewed against `docs/Hackathon/Rules.md`; text checks only |
| 2026-11-11 | Kiro IDE | Added `docs/SubmissionChecklist.md`, `docs/KiroUsage.md`, hackathon README section, platform-scope wording in README, ProjectOverview, and steering; fast-forwarded `main` to PR #1 | project-scaffolding R3, R5, R6, R9 | Links and wording reviewed; not built |
| 2026-11-11 | Kiro Web | Rewrote steering (product, tech, structure, safety, testing, hackathon) and added swift-conventions, macos-platform, platinum-ui, git-workflow, documentation | n/a | Reviewed against master spec; not built (Linux sandbox). Surface corrected from Kiro IDE to Kiro Web after review; PR #1 |
| 2026-11-11 | Kiro IDE | Project scaffolding: SwiftPM package, CLI stub, placeholder tests, docs, LICENSE | project-scaffolding | `swift build`/`swift test` on macOS |

## Tools

| Tool | Version | Purpose | Scope |
|---|---|---|---|
| Swift / SwiftPM | tools 6.0 | Build and test | Dev + runtime |
| swift-property-based (`PropertyBased`) | 2.0.1 (exact) | Property-based tests | Test only |
| Swift Testing | toolchain (Command Line Tools macro plugin loaded by `Package.swift`) | Unit and property tests | Test only |
| SwiftLint | 0.65.1 (Homebrew), `--strict` | Lint; needs `TOOLCHAIN_DIR` set to the Command Line Tools when Xcode.app is absent (scripts do this) | Dev only |
| DiskArbitration | macOS SDK | Unmount | Runtime (system) |
| `/usr/sbin/lsof`, `/usr/bin/fuser`, `/usr/sbin/diskutil`, `/usr/bin/hdiutil` | macOS 27.2.1 | Lock discovery, unmount fallback, dmg mapping | Runtime (system) |
| Kiro IDE (specs, steering, hooks) | version not recorded | Spec-driven development, hooks, agent work | Dev only |
| Kiro Web (agent work, git/PR via `gh`) | KiroWeb 1.0.0 | Agent sessions in a Linux sandbox; cannot build or run macOS code | Dev only |
| `python3` | system / pyenv | Parses hook JSON payloads in `Scripts/hooks/` | Dev only |

Runtime third-party dependencies: none.

## Decisions

Format: ID, date, status (Accepted / Superseded), context, decision, consequences.

### D-001 (2026-11-11, Accepted): Platform scope is macOS 27.2.1 only
- Context: only that version can be tested.
- Decision: no support or compatibility code for other macOS versions or operating systems.
- Consequences: simpler code; `Package.swift` declares `.macOS("27.2.1")`.

### D-002 (2026-11-11, Accepted): Core library has no AppKit
- Decision: `PhantomTraceCore` imports Foundation only (Darwin/DiskArbitration/OSLog in `System/` adapters). UI lives outside Core.
- Consequences: Core logic is testable; system effects sit behind protocols.

### D-003 (2026-11-11, Accepted): Property-based library is swift-property-based, not SwiftCheck
- Context: `Package.swift` pins `swift-property-based` 2.0.1; older specs and docs say SwiftCheck.
- Decision: `Package.swift` is the source of truth; steering follows it.
- Consequences: scaffolding spec and checks that mention SwiftCheck need updating.

### D-004 (2026-11-11, Accepted): Single SafetyPolicy gate for all actions
- Decision: every `ProposedAction` is approved by `SafetyPolicy`; unknown state means deny.
- Consequences: UI/CLI never call signal or unmount adapters directly.

### D-005 (2026-11-11, Accepted): Hook enforces project log updates at commit time
- Context: pushes to `main` go through PRs, so a commit-time check covers all code.
- Decision: a commit hook blocks commits that change code or config without staging `docs/ProjectLog.md`; a steering rule says what to record.
- Consequences: small friction per commit; escape hatch is an `[skip-log]` marker in the commit message for trivial changes.

### D-006 (2026-11-11, Accepted): Three focused hooks plus the project-log hook
- Context: the hackathon rewards visible hook use, but too many hooks add friction. A separate lint hook and test hook would both fire on every commit.
- Decision: `lint-on-save` for per-file feedback, one `pre-commit-check` that runs `Scripts/lint-and-test.sh` (lint, then tests), and `kiro-gitignore-guard` for the rule that `.kiro/` must never be ignored. Hook logic lives in scripts under `Scripts/hooks/`. Rejected: a post-task test hook (duplicates the commit gate) and a Stop hook (runs every turn).
- Consequences: PreToolUse hooks see only commits the agent runs, not terminal commits. With `project-log-check`, three hooks fire on agent commits. SwiftLint must be installed (`brew install swiftlint`) or the commit gate blocks every agent commit. Revisit if the gate gets slow.

### D-007 (2026-11-11, Accepted): Detect the Kiro surface with a script, enforce it in the existing log hook
- Context: the hackathon write-up asks how Kiro IDE, CLI, Web, and Crew differed, so each work-log row names its surface. Typing it by hand is easy to forget or get wrong.
- Decision: `Scripts/kiro-surface.sh` detects the surface. Verified: Kiro IDE (`TERM_PROGRAM=kiro` in the agent shell, `VSCODE_IPC_HOOK` or `VSCODE_PID` in IDE hook processes). Best effort and unverified: Kiro CLI (a `kiro-cli` parent process). Web, Crew, and Mobile have no known markers, so the script reports Unknown and `PHANTOMTRACE_KIRO_SURFACE` overrides it. The existing `project-log-check` hook runs the script and blocks commits whose new work-log rows have a missing or invalid surface. It does not block on a mismatch with the detected value, because a commit may hold rows from earlier work on another surface. No new hook was added.
- Consequences: an agent adding a row runs `Scripts/kiro-surface.sh --details` first. Non-IDE surfaces need the override or manual entry until their markers are known; update the script when they are.

### D-008 (2026-11-11, Accepted): Real git hooks mirror the Kiro commit hooks
- Context: Kiro PreToolUse hooks only see commits the agent runs, so commits made by hand skipped the project-log, lint and test, and `.kiro` checks.
- Decision: tracked git hooks in `Scripts/git-hooks/` call the same scripts in `--git` mode. `pre-commit` runs the `.kiro` guard and lint plus tests (lint and tests only when a Swift, package, lint-config, or script file is staged). `commit-msg` runs the project-log check, because only that hook can read `[skip-log]`. Each clone enables them once with `Scripts/install-git-hooks.sh`, which sets `core.hooksPath`. The Kiro hooks stay.
- Consequences: an agent commit runs the checks twice, once per hook layer. Manual commits are covered. Lint and tests are skipped for docs-only commits. `git commit --no-verify` bypasses the git hooks; the git-workflow steering forbids it for the agent. Resolved by D-010: `swift test` now passes with only Command Line Tools installed.

### D-009 (2026-11-11, Accepted): Detect Kiro Web from its sandbox environment variables
- Context: D-007 found no verified markers for Kiro Web, so Web rows needed a manual override. The Kiro Web agent shell sets `AWS_SDK_UA_APP_ID=kiro-web` and `KIRO_CUSTOM_USER_AGENT=KiroWeb/<version>`.
- Decision: `Scripts/kiro-surface.sh` reports Kiro Web when either marker is present, with the version taken from the user agent. Explicit `PHANTOMTRACE_KIRO_SURFACE` still wins. Crew and Mobile remain undetected. Updates D-007 for Web only.
- Consequences: the project-log hook now prints "Kiro Web" as the detected surface in Web sessions. The markers are vendor-internal and may change; recheck if detection reports Unknown in Web. Kiro Web runs on Linux, so Web work cannot verify macOS builds, and rows must say so.

### D-010 (2026-11-11, Accepted): Use Swift Testing, not XCTest, and load the macro plugin from Command Line Tools
- Context: this Mac has Command Line Tools only. XCTest is not there, so `swift test` failed. The sibling project TheGatekeepersWard runs Swift Testing on the same setup by passing `-load-plugin-library` for `libTestingMacros.dylib`.
- Decision: tests use `import Testing`, `@Test`, and `#expect`. `Package.swift` adds the plugin flag to both test targets through `swiftSettings`, only when the plugin file exists, so full Xcode still works. SwiftLint needs `DYLD_FRAMEWORK_PATH=/Library/Developer/CommandLineTools/usr/lib` on this setup; the lint scripts export it when Command Line Tools is the active toolchain.
- Consequences: no XCTest in this repo (`.kiro/steering/testing.md` says so). `Package.swift` uses `unsafeFlags`, which is allowed because this is the root package. The hardcoded plugin path breaks if the Command Line Tools layout changes. Supersedes the known issue in D-008.
