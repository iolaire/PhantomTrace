# How PhantomTrace Uses Kiro

The Rules require a write-up showing how effectively Kiro was used. This document is the draft. Fill each "Evidence" line with what actually happened during the build; leave out anything not used.

## Spec-driven development

- Master spec: `.kiro/specs/phantomtrace-volume-lock-forensics/` (requirements, design) covering mount-point path resolution, process discovery, and the safe unmount workflow.
- Scaffolding spec: `.kiro/specs/project-scaffolding/` (requirements, design, tasks).
- Evidence to add: how the spec shaped the implementation, and how it compared to vibe coding.

## Steering docs

Files in `.kiro/steering/`:

- `product.md`: mission, principles, entry points, theme, platform scope (macOS 27.2.1 only), build order.
- `tech.md`: Swift 6, SwiftPM, AppKit, DiskArbitration, concurrency, zero third-party runtime dependencies, quality gates.
- `structure.md`: layering rule (Core library imports no AppKit), directory and file conventions.
- `safety.md`: single SafetyPolicy choke point, protected processes and volumes, escalation rules, no shell strings, no network.
- `testing.md`: Swift Testing, mock protocols for all system effects, round-trip and property coverage map, 500+ iterations.
- `swift-conventions.md` (Swift files only): style, bytes-first data handling, dependency injection, concurrency.
- `macos-platform.md`: macOS 27.2.1 specifics, lsof/DiskArbitration/TCC notes, packaging, Linux-sandbox caveat.
- `platinum-ui.md` (app/UI files only): Platinum Retro Gothic look, Diagnostic Sheet rules, accessibility.
- `git-workflow.md`: commit style, pre-commit gates, branching.
- `documentation.md`: README, KiroUsage, spec, and checklist upkeep.
- `hackathon.md`: disqualification risks, demo, judging criteria.
- Evidence to add: which steering rule changed Kiro's output the most.

## Agent hooks

Four hooks in `.kiro/hooks/`, kept small on purpose. Each addresses a different problem, and the logic lives in testable scripts under `Scripts/`.

- `project-log-check.json` (PreToolUse on shell commands): when the agent runs `git commit` with code or config staged, requires `docs/ProjectLog.md` to be staged too (`Scripts/check-project-log.sh`; `[skip-log]` in the message bypasses it).

- `lint-on-save.json` (PostFileSave on `*.swift`): lints only the saved file, for the fastest feedback.
- `pre-commit-check.json` (PreToolUse on shell commands): when the agent runs `git commit`, runs `Scripts/lint-and-test.sh` (`swiftlint --strict`, then `swift test`) and blocks the commit on failure. One hook instead of separate lint and test hooks.
- `kiro-gitignore-guard.json` (PreToolUse on shell commands): blocks a commit if `.gitignore` ignores `.kiro`, a disqualification risk in the Rules.
- Rejected on purpose: a post-task test hook (duplicates the commit gate) and a Stop hook (runs every turn, too noisy).
- Limit: PreToolUse hooks see only commits the agent runs, not commits typed in a terminal.
- Status: scripts tested with sample payloads (commit, non-commit, empty, garbage, missing SwiftLint). Live behavior in Kiro still to confirm.
- Evidence to add: issues the hooks actually caught during the build.

## Property-based testing

- SwiftCheck, pinned to an exact version, in `Tests/PhantomTracePropertyTests`.
- Targets: the `lsof`/`fuser` output parser against malformed paths, non-UTF8 strings, spaces, and symlinks; round-trip properties for every parser and printer.
- Evidence to add: bugs PBT found that unit tests did not.

## Other Kiro features

- Kiro IDE, CLI, Web, or Crew: record which were used and how they differed.
- Custom agents: record any created and their effect.
- MCP: record any servers used and what they enabled.
- Kiro powers: record any powers used.
