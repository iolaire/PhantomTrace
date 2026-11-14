# How PhantomTrace Uses Kiro

The Rules require a write-up showing how effectively Kiro was used. This document is the draft. Fill each "Evidence" line with what actually happened during the build; leave out anything not used.

## Feature map
One line per Kiro feature, with where it lives and where the evidence is. "Not used" is stated plainly.

| Feature | Where | Evidence |
|---|---|---|
| Specs | `.kiro/specs/phantomtrace-volume-lock-forensics/`, `.kiro/specs/project-scaffolding/` | Work-log rows cite task and requirement numbers; see Spec-driven development |
| Steering | `.kiro/steering/` (11 files) | Lint rules and tests traced to steering rules; see Steering docs |
| Hooks | `.kiro/hooks/` (4 files), scripts in `Scripts/hooks/` | Captured block output for `project-log-check` and `pre-commit-check`; IDE-triggered `lint-on-save` still to add; see Agent hooks |
| Property-based tests | `Tests/PhantomTracePropertyTests` | A real bug found (`/private/var/vm`); see Property-based testing |
| Real-capture fixture | `Tests/Fixtures/real_capture_macos.lsof` | A real `lsof` capture exposed a spec gap (short escapes); see Property-based testing |
| Powers | `swift-expert` | Concurrency audit (D-021); see Other Kiro features |
| Custom agent | `.kiro/agents/safety-reviewer.json` | Defined; its prompt was dry-run once by a general sub-agent, not by the agent itself; see Custom agent |
| Reusable prompt | `.kiro/prompts/score-hackathon.md` | Produces `docs/HackathonScoreReview.md` |
| MCP | none | Not used |

## Spec-driven development

- Master spec: `.kiro/specs/phantomtrace-volume-lock-forensics/` (requirements, design) covering mount-point path resolution, process discovery, and the safe unmount workflow.
- Scaffolding spec: `.kiro/specs/project-scaffolding/` (requirements, design, tasks).
- Evidence: the master spec's `tasks.md` (about 19 top-level tasks) drove the build order, and each work-log row in `docs/ProjectLog.md` names the task and requirement numbers it implemented. Spec-level decisions (SwiftPM-only packaging, the three-window UI, the `PhantomTraceUI` split) were written into the spec before code. Requirement 18 items that the owner had not confirmed were built as labelled `// PROVISIONAL (Req 18.x)` code paths and listed in [architecture.md](architecture.md#provisional-behaviors).
- Evidence to add: a comparison with vibe coding, if one is made.

## Steering docs

Files in `.kiro/steering/`:

- `product.md`: mission, principles, entry points, theme, platform scope (builds for macOS 15.0+, tested on 27.2.1 only), build order.
- `tech.md`: Swift 6, SwiftPM, AppKit, DiskArbitration, concurrency, zero third-party runtime dependencies, quality gates.
- `structure.md`: layering rule (Core library imports no AppKit), directory and file conventions.
- `safety.md`: single SafetyPolicy choke point, protected processes and volumes, escalation rules, no shell strings, no network.
- `testing.md`: Swift Testing, mock protocols for all system effects, round-trip and property coverage map, 500+ iterations.
- `swift-conventions.md` (Swift files only): style, bytes-first data handling, dependency injection, concurrency.
- `macos-platform.md`: macOS 15.0 floor, 27.2.1 test target, lsof/DiskArbitration/TCC notes, packaging, Linux-sandbox caveat.
- `platinum-ui.md` (app/UI files only): Platinum Retro Gothic look, Diagnostic Sheet rules, accessibility.
- `git-workflow.md`: commit style, pre-commit gates, branching.
- `documentation.md`: README, KiroUsage, spec, and checklist upkeep.
- `hackathon.md`: disqualification risks, demo, judging criteria.
- Evidence from `docs/ProjectLog.md` (each is a logged work-log row or decision, not a recollection):
  - `safety.md` and `tech.md` became lint rules. The 2026-11-12 code-quality pass added custom SwiftLint rules that ban `print(` in Core and networking APIs in `Sources`, so the "no `print` in Core" and "zero network" rules are checked by `swiftlint --strict` and no longer depend on a reader remembering them.
  - `testing.md` shaped the test hardening pass (2026-11-12). Its rule against wall-clock dependence led to removing the `Date()` assertion in `LiveProcessRunnerTests`, and its rule that tests must fail fast led to `.timeLimit` traits on every suite that parks on a long sleep.
  - `testing.md` also records that XCTest is unavailable on Command Line Tools. The scaffolding run moved the tests to Swift Testing (D-010).
  - `safety.md` set the protected-volume rule that Property 10 tested, which led to the `/private/var/vm` bug described below.
  - `documentation.md` and the `project-log-check` hook together produced the project log itself: one row per change with the Kiro surface and how it was verified. The log is the source for the evidence on this page.
- Evidence to add: a side-by-side example of Kiro output with and without a steering file; none was recorded.

## Agent hooks

Four hooks in `.kiro/hooks/`, kept small on purpose. Each addresses a different problem, and the logic lives in testable scripts under `Scripts/`.

- `project-log-check.json` (PreToolUse on shell commands): when the agent runs `git commit` with code or config staged, requires `docs/ProjectLog.md` to be staged too (`Scripts/check-project-log.sh`; `[skip-log]` in the message bypasses it).

- `lint-on-save.json` (PostFileSave on `*.swift`): lints only the saved file, for the fastest feedback.
- `pre-commit-check.json` (PreToolUse on shell commands): when the agent runs `git commit`, runs `Scripts/lint-and-test.sh` (`swiftlint --strict`, then `swift test`) and blocks the commit on failure. One hook instead of separate lint and test hooks.
- `kiro-gitignore-guard.json` (PreToolUse on shell commands): blocks a commit if `.gitignore` ignores `.kiro`, a disqualification risk in the Rules.
- Rejected on purpose: a post-task test hook (duplicates the commit gate) and a Stop hook (runs every turn, too noisy).
- Limit: PreToolUse hooks see only commits the agent runs. Real git hooks in `Scripts/git-hooks/` (enabled with `Scripts/install-git-hooks.sh`) call the same scripts so commits typed by hand are covered too.
- Status: scripts tested with sample payloads (commit, non-commit, empty, garbage, missing SwiftLint). Owner statement, 2026-11-12: the hooks were active in Kiro IDE during the build, so the agent's commits and Swift saves ran through them. This is owner-reported; no hook output was captured at the time, so there is no transcript to cite.
- Design evidence from the log: D-006 records why there are four focused hooks and what was rejected. D-008 records a gap found while building them (agent-only PreToolUse hooks miss hand-typed commits), which led to the tracked git hooks. The `project-log-check` hook also validates the Kiro surface column of new log rows (D-007).
- Captured hook output (2026-11-14, Kiro IDE). This is a deliberate demonstration on a throwaway branch, not a bug caught during the build. The branch was deleted and nothing was committed.
  - `project-log-check` blocked a commit. A one-line change to `Sources/PhantomTraceCore/Models/PhantomTraceError.swift` was staged with no ProjectLog row, and the agent ran `git commit -m "test: hook demo"`. Kiro intercepted the call before it ran ("The tool was NOT executed") and returned:

    ```
    docs/ProjectLog.md is not staged. Add a work-log entry (and a decision or tool entry if relevant), stage it, then commit again. For trivial changes include [skip-log] in the commit message.
    Kiro surface detected here (surface | version | evidence): Kiro IDE | n/a | IDE hook process (VSCODE_IPC_HOOK or VSCODE_PID, no TERM_PROGRAM)
    ```
  - The same run shows the Kiro surface detection working: the block message names Kiro IDE.
  - `lint-on-save` was run by hand, not through the IDE. The agent's edit tool did not trigger the save hook, so `Scripts/hooks/lint-on-save.sh` was run directly on a file with a `print(...)` added to Core. It printed the custom steering-derived rule and exited 2:

    ```
    .../Sources/PhantomTraceCore/Models/PhantomTraceError.swift:21:24: error: No print in Core Violation: Use OSLog Logger, not print, in Core. (no_print_in_core)
    SwiftLint found violations in Sources/PhantomTraceCore/Models/PhantomTraceError.swift (output above).
    ```
    This shows the script and the rule. It does not show the IDE hook firing on a save.
  - `pre-commit-check` blocked a commit (2026-11-14, Kiro IDE). On a throwaway branch (deleted afterwards, nothing committed), a `print("hook demo")` line was added to `Sources/PhantomTraceCore/Models/PhantomTraceError.swift`, staged, and `git commit -m "test: pre-commit hook demo [skip-log]"` was run by the agent. Kiro intercepted it ("The tool was NOT executed"). The hook ran `swiftlint --strict` over all 208 files and ended with:
    ```
    .../Sources/PhantomTraceCore/Models/PhantomTraceError.swift:21:19: error: No print in Core Violation: Use OSLog Logger, not print, in Core. (no_print_in_core)
    Done linting! Found 1 violation, 1 serious in 208 files.
    Commit blocked: lint or tests failed (output above).
    ```
    This shows the steering rule (`tech.md`: no `print` in Core) enforced twice: by the custom lint rule and by the commit gate.
  - Not tested: `kiro-gitignore-guard` (stayed silent in the runs above, consistent with passing).
- Evidence to add: an IDE-triggered `lint-on-save` result (open a Swift file, add a `print`, save with Cmd-S), and any issue a hook actually caught during the build. None is recorded in the log, so none is claimed.

## Property-based testing

- swift-property-based, pinned to an exact version, in `Tests/PhantomTracePropertyTests`.
- Targets: the `lsof`/`fuser` output parser against malformed paths, non-UTF8 strings, spaces, and symlinks; round-trip properties for every parser and printer.
- Property tests exist for the spec's properties (parser totality, round-trip, byte fidelity, validity and determinism, truncation safety, unknown fields, classification, symlink containment, mount resolution, protected volumes, safety deny-list, escalation order, identity guard, plan construction, unmount gating, fresh state, discovery idempotence, URL round-trip, truncation, ghost state, window selection, argument-array fidelity), at 500 iterations each.
- Bug found by a property test: `ProtectedVolumeRefusalPropertyTests` (Property 10) failed on the counterexample `/private/var/vm`. `MountResolver.isProtected` used `standardizedFileURL`, which rewrites `/private/var/vm` to `/var/vm`, so the protected path was not refused. Fixed by normalizing `.`/`..` lexically and refusing both forms; `MountResolverProtectionTests` is the regression test. This is a safety rule.
- Bug found by an integration test, not a property test: `DiskImageIntegrationTests` (a real throwaway disk image with a held file and a shell) showed that DiskArbitration reports busy as `0xC000 | EBUSY` (49168). `LiveUnmounter` treated that as a generic failure and ran the `diskutil` fallback instead of returning `unmountBusy`. Fixed in `LiveUnmounter.swift` and covered by `LiveUnmounterTests`. The mock-based tests could not have found this because the mocks encoded the wrong assumption.
- Gap found by a real `lsof` capture (2026-11-14): `Tests/Fixtures/real_capture_macos.lsof` was captured from `/usr/sbin/lsof -F pcLnftau0 -w +f` on macOS 27.2.1 against a throwaway disk image (names with a space, non-ASCII characters, and a newline). lsof writes a newline in a name as the two bytes `\n` (a further probe showed `\b`, `\t`, `\f`, `\r` the same way, and `\\` for a backslash; BEL, VT and ESC come out as raw bytes). Requirement 4.4 lists only octal, `\x` and `\\` escapes, so the parser reports a malformed escape and keeps the two bytes. The generated fixtures could not show this because they were written from the spec. `LsofParserRealCaptureTests` pins today's behavior and marks the desired behavior with `withKnownIssue` until a spec change is decided. The same cause explains the "1 unreadable lsof entries were skipped" note in the 2026-11-13 ManualQA pass. This is a spec gap, not yet fixed.
- Other properties passed without finding bugs; those are logged as "no bug found" in `docs/ProjectLog.md`. Most parser fixtures in `Tests/Fixtures` are generated; `real_capture_macos.lsof` is the one real capture.

## Other Kiro features

- Kiro IDE, CLI, Web, Crew, or Mobile: each work-log row in `docs/ProjectLog.md` names the surface (detected by `Scripts/kiro-surface.sh`), so the log shows which surface did what. Evidence to add: how they differed.
- Kiro operating the real app (2026-11-13, Kiro IDE): with Accessibility and Screen Recording granted by the owner, Kiro drove PhantomTrace through the macOS Accessibility API and recorded the demo clips. One shows Finder's own eject failure (`s01-problem`). One continuous take goes from the desktop Quick Action through Egress Shells, Graceful Request and Eject, and is cut into `s03-trigger`, `s06-egress`, `s07-graceful` and `s09-handoff`. It used a real pointer glide and clicks, so the clip shows the cursor and click rings. The tools are in the repo (`Scripts/demo/ax-drive.swift`, `Scripts/demo/record-flow.sh`, see `demo/CLIPS.md`). While doing this, Kiro found a real bug: the app drops `StageOutcome.manual`, so a shell that cannot be sent `cd ~` gets no on-screen instruction (Requirement 7.5). Fixing it showed a second, older bug: the stage results list had always collapsed to 0 pt, so failed actions (Requirement 14.5) were never visible either. Both are fixed and checked on screen with a shell on a bare pty. It also fixed `teardown-demo.sh` for the state after Eject. Details in `docs/ProjectLog.md`.
- Custom agent, `safety-reviewer` (`.kiro/agents/safety-reviewer.json`, prompt in `.kiro/agents/prompts/safety-reviewer.md`): read-only (read tools only; write, shell and web excluded and denied by permission rules), loaded with `safety.md`, `structure.md`, `tech.md` and `testing.md`. It checks code against the safety rules and reports `severity | file:line | rule | problem`. The agent has not yet been run from the IDE or CLI. Its prompt was dry-run once on 2026-11-14 by a general sub-agent (read-only) over Core Resolution and System, the UI, the app and the CLI. It found no blockers and seven minor notes, including two real gaps against `safety.md`: `StagePlanBuilder` never passes `determinationMilliseconds`, so the 1000 ms undeterminable-state denial cannot trigger in production, and `ResolutionPipeline.execute` runs actions approved at `plan()` time without calling `SafetyPolicy.evaluate` again. Both were fixed the same day (2026-11-14): the pipeline now measures fact-gathering time and passes it to the policy, and `execute` asks `SafetyPolicy.evaluate` again right before each send and reports a refusal as `PhantomTraceError.safetyDenied`. `ResolutionPipelineSafetyRecheckTests` covers both (a kill is refused when the recorded graceful attempt is gone at send time; a 1.5 s fact lookup denies the action). That is the review loop closing: steering rule, agent prompt, finding, fix, test. Evidence to add: a run of the agent itself on a real diff.
- MCP: not used. No server is configured and none is claimed.
- Kiro powers: the `swift-expert` power is installed (`~/.kiro/powers/installed/swift-expert`, with `swift-general.md` and `swift-api-design-guidelines.md` steering files) and was used in Kiro IDE for Swift guidance. Two uses are logged in `docs/ProjectLog.md`, both dated 2026-11-12:
  - Concurrency audit (decision D-021, the stronger use). An audit of Core against the power's concurrency guidance found three problems: cancellation was swallowed in `ResolutionPipeline.execute` (a cancelled stage kept signalling, then rescanned), a cancelled scan was reported as `lsofUnavailable`, and a semaphore with `Task.detached` blocked the coordinator actor during `.dmg` resolution. The fixes added `PhantomTraceError.cancelled` and `EgressFailure.cancelled`, made `MountResolving.resolve` and `MountTableProviding.mounts(forDiskImage:)` `async`, made `LiveUnmounter` resume its continuation exactly once, and added `ResolutionPipelineCancellationTests`. Verified on macOS: 259 tests pass and `swiftlint --strict` reports 0 violations. Not covered by a test: the cancel-with-grace change in `LiveProcessRunner` and the 60 s unmount timeout, which is provisional.
  - Test hardening. Only the general Swift Testing guidance was used. The power's concurrency testing reference was not available, so nothing more is claimed for that row.
  - Owner statement, 2026-11-12: the power was used during the build. The two rows above are the logged evidence.
