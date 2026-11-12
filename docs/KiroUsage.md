# How PhantomTrace Uses Kiro

The Rules require a write-up showing how effectively Kiro was used. This document is the draft. Fill each "Evidence" line with what actually happened during the build; leave out anything not used.

## Spec-driven development

- Master spec: `.kiro/specs/phantomtrace-volume-lock-forensics/` (requirements, design) covering mount-point path resolution, process discovery, and the safe unmount workflow.
- Scaffolding spec: `.kiro/specs/project-scaffolding/` (requirements, design, tasks).
- Evidence: the master spec's `tasks.md` (about 19 top-level tasks) drove the build order, and each work-log row in `docs/ProjectLog.md` names the task and requirement numbers it implemented. Spec-level decisions (SwiftPM-only packaging, the three-window UI, the `PhantomTraceUI` split) were written into the spec before code. Requirement 18 items that the owner had not confirmed were built as labelled `// PROVISIONAL (Req 18.x)` code paths and listed in [architecture.md](architecture.md#provisional-behaviors).
- Evidence to add: a comparison with vibe coding, if one is made.

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
- Limit: PreToolUse hooks see only commits the agent runs. Real git hooks in `Scripts/git-hooks/` (enabled with `Scripts/install-git-hooks.sh`) call the same scripts so commits typed by hand are covered too.
- Status: scripts tested with sample payloads (commit, non-commit, empty, garbage, missing SwiftLint). Owner statement, 2026-11-12: the hooks were active in Kiro IDE during the build, so the agent's commits and Swift saves ran through them. This is owner-reported; no hook output was captured at the time, so there is no transcript to cite.
- Evidence to add: a captured block message or lint output from a hook, and any issue a hook actually caught during the build.

## Property-based testing

- swift-property-based, pinned to an exact version, in `Tests/PhantomTracePropertyTests`.
- Targets: the `lsof`/`fuser` output parser against malformed paths, non-UTF8 strings, spaces, and symlinks; round-trip properties for every parser and printer.
- Property tests exist for the spec's properties (parser totality, round-trip, byte fidelity, validity and determinism, truncation safety, unknown fields, classification, symlink containment, mount resolution, protected volumes, safety deny-list, escalation order, identity guard, plan construction, unmount gating, fresh state, discovery idempotence, URL round-trip, truncation, ghost state, window selection, argument-array fidelity), at 500 iterations each.
- Bug found by a property test: `ProtectedVolumeRefusalPropertyTests` (Property 10) failed on the counterexample `/private/var/vm`. `MountResolver.isProtected` used `standardizedFileURL`, which rewrites `/private/var/vm` to `/var/vm`, so the protected path was not refused. Fixed by normalizing `.`/`..` lexically and refusing both forms; `MountResolverProtectionTests` is the regression test. This is a safety rule.
- Bug found by an integration test, not a property test: `DiskImageIntegrationTests` (a real throwaway disk image with a held file and a shell) showed that DiskArbitration reports busy as `0xC000 | EBUSY` (49168). `LiveUnmounter` treated that as a generic failure and ran the `diskutil` fallback instead of returning `unmountBusy`. Fixed in `LiveUnmounter.swift` and covered by `LiveUnmounterTests`. The mock-based tests could not have found this because the mocks encoded the wrong assumption.
- Other properties passed without finding bugs; those are logged as "no bug found" in `docs/ProjectLog.md`. Parser fixtures in `Tests/Fixtures` are generated, not captured from real `lsof`.

## Other Kiro features

- Kiro IDE, CLI, Web, Crew, or Mobile: each work-log row in `docs/ProjectLog.md` names the surface (detected by `Scripts/kiro-surface.sh`), so the log shows which surface did what. Evidence to add: how they differed.
- Custom agents: record any created and their effect.
- MCP: record any servers used and what they enabled.
- Kiro powers: the `swift-expert` power is installed (`~/.kiro/powers/installed/swift-expert`, with `swift-general.md` and `swift-api-design-guidelines.md` steering files) and was used in Kiro IDE for Swift guidance. The one recorded use is the test-hardening row dated 2026-11-12 in `docs/ProjectLog.md` (general Swift Testing guidance). Its concurrency testing reference was not available, so no concurrency guidance from it is claimed. Owner statement, 2026-11-12: the power was used during the build. Evidence to add: which specific guidance changed code.
