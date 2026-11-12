# Implementation Plan: PhantomTrace — Volume Lock Forensics & Banishment

## Overview

The design is written in Swift, so no language question applies. Work proceeds bottom-up: a pure Core library (Foundation only, system effects behind protocols), then live adapters, the CLI, the pure window-state model, asset export, the programmatic AppKit app, the Quick Action, the bundling script, documentation, and final submission checks.

Conventions that apply to every task:
- Swift Testing (not XCTest). Property tests use swift-property-based (`PropertyBased`) in `Tests/PhantomTracePropertyTests`. Unit tests go in `Tests/PhantomTraceCoreTests`. Fixtures go in `Tests/Fixtures`.
- `PhantomTraceCore` imports Foundation only. Darwin and DiskArbitration are allowed only inside live adapters under `Sources/PhantomTraceCore/System/`. Anything needing AppKit lives in the app-side targets (Req 15.4).
- Run `swiftlint --strict` and `swift test` before each commit, and update `docs/ProjectLog.md` in every commit.
- Only the Command Line Tools are available. Do not use `xcodebuild`, `actool`, Interface Builder, `.xcassets`, or App Intents (Req 16.1, 17.1, 12.10).
- Package layout decision: the AppKit code is split into a `PhantomTraceUI` library target (testable) and a thin `PhantomTraceApp` executable target, so app-side logic can be tested without importing an executable. A `PhantomTraceTestSupport` target (not a product) holds shared mocks so unit and property test targets can both use them.
- Provisional behaviors (Req 18.6, 18.7, 18.15, 18.16, 18.21, 18.23, 18.26) are implemented as specified, isolated behind clearly named code paths, and labelled `// PROVISIONAL (Req 18.x)` so they are easy to change after user confirmation.

## Tasks

- [x] 1. Early packaging spike
  - [x] 1.1 Verify codesign and notarytool availability with Command Line Tools only
    - Write `Scripts/spike-signing.sh` that builds a trivial executable with `swift build`, wraps it in a minimal throwaway `.app` under a temp directory, runs `codesign --force --options runtime --sign -` with a minimal entitlements file, then `codesign --verify --strict`
    - Check `xcrun --find notarytool` and `xcrun --find stapler`; report presence or absence without submitting anything
    - Confirm the built app launches the executable (`open`-free check: run the binary directly)
    - Record the findings and any limitations in `docs/ProjectLog.md`; clean up temp files
    - _Requirements: 16.1, 16.6, 16.7, 16.8, 16.12_

- [x] 2. Core models and effect protocols
  - [x] 2.1 Define core data models and errors
    - In `Sources/PhantomTraceCore/Models/`: `MountInfo`, `RawLsofRecord`, `AccessMode`, `LockCategory`, `ProcessRole`, `LockRecord`, `ProcessIdentity`, `ResolutionStage`, `ProposedActionKind`, `ProposedAction`, `SafetyDenial`, `SafetyVerdict`, `ResolutionPlan`, `StageOutcome`, `PhantomTraceError`, `ParseResult`, `ParseWarning`, `DiscoveryState`
    - Include the `partial` indicator on discovery results and the rescan-timed-out flag on `StageOutcome`
    - _Requirements: 1.9, 3.6, 4.5, 5.8, 6.8, 11.4, 14.3_
  - [x] 2.2 Define system-effect protocols
    - In `Sources/PhantomTraceCore/System/`: `ProcessRunning` (argument array, timeout, captured bytes), `SignalSending`, `AppQuitting`, `Unmounting`, `FileSystemProbing`, `ProcessInspecting` (owner, start time, tty and foreground pgid, cwd), `TerminalScripting`, `MountTableProviding`, and an injectable `Sleeping`/clock
    - Document that no protocol accepts a shell command string
    - _Requirements: 15.1, 15.5, 15.6_
  - [x] 2.3 Add shared mock adapters
    - Add the `PhantomTraceTestSupport` target to `Package.swift` and implement scripted mocks for every protocol from 2.2 (recording calls, configurable results, failures, and timeouts)
    - Wire the target into both test targets
    - _Requirements: 15.5_

- [x] 3. Mount and path resolution
  - [x] 3.1 Implement `MountResolver`
    - In `Sources/PhantomTraceCore/Mounts/`: canonicalize via `MountTableProviding`/`FileSystemProbing` (symlinks, firmlinks), whole-component longest-prefix matching, exact mount-point match, attached `.dmg` lookup (first volume in mount-table order), volume-name fallback to last path component
    - Return `notAMountPoint` for missing path, no owning mount, and unattached `.dmg`; return `protectedVolume` for `/`, `/System/Volumes/*`, `/private/var/vm`; return an error and treat as protected when status cannot be determined
    - Ensure no scan or mutation happens on error, and results arrive within 500 ms
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8, 1.9, 1.10, 2.1, 2.2, 2.3, 2.5_
  - [x] 3.2 Write property test for mount resolution
    - **Property 9: Mount resolution**
    - **Validates: Requirements 1.1, 1.2, 1.3, 1.9**
  - [x] 3.3 Write property test for protected volume refusal
    - **Property 10: Protected volume refusal**
    - **Validates: Requirements 2.1**
  - [x] 3.4 Write unit tests for the resolver
    - Cover `/Volumes/A` vs `/Volumes/AB/file`, nonexistent path, `.dmg` attached and unattached, multi-volume image, empty volume name, unverifiable status
    - _Requirements: 1.2, 1.4, 1.5, 1.6, 1.7, 1.8, 1.10, 2.2, 2.5_

- [x] 4. lsof parser and printer
  - [x] 4.1 Implement `LsofParser`
    - In `Sources/PhantomTraceCore/Discovery/`: byte-level state machine over `lsof -F` output with NUL/LF terminators, octal/hex/`\\` unescape, malformed-escape warning (keep bytes literally), bad-pid handling (discard the process set, resume at the next valid pid), truncated-tail warning, unknown tags ignored, lossy display path from `pathBytes`
    - Emit only pid 1...4,294,967,295 with non-empty `pathBytes`; support input up to 104,857,600 bytes without throwing; deterministic output
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 4.7, 4.8, 4.9, 4.10, 4.14_
  - [x] 4.2 Implement `LsofPrinter`
    - Serialize `RawLsofRecord` sets to `lsof -F` bytes that the parser accepts with zero warnings (escape backslash, NUL, newline, and non-printable bytes as needed)
    - _Requirements: 4.11, 4.12_
  - [x] 4.3 Write property test for parser totality
    - **Property 1: Parser totality**
    - **Validates: Requirements 4.1**
  - [x] 4.4 Write property test for parser round-trip
    - **Property 2: Parser round-trip**
    - **Validates: Requirements 4.4, 4.9, 4.11, 4.12**
  - [x] 4.5 Write property test for byte fidelity
    - **Property 3: Byte fidelity**
    - **Validates: Requirements 4.2, 4.3**
  - [x] 4.6 Write property test for record validity and determinism
    - **Property 4: Record validity and determinism**
    - **Validates: Requirements 4.5, 4.10**
  - [x] 4.7 Write property test for truncation safety
    - **Property 5: Truncation safety**
    - **Validates: Requirements 4.7, 4.13**
  - [x] 4.8 Write property test for unknown-field tolerance
    - **Property 6: Unknown-field tolerance**
    - **Validates: Requirements 4.8**
  - [x] 4.9 Write fixture-driven parser unit tests
    - Add captured outputs to `Tests/Fixtures` (spaces, newlines, Unicode, `\x20` escapes, non-UTF8, bad pid, malformed escape, truncated tail) and assert records and warnings
    - _Requirements: 4.3, 4.4, 4.6, 4.7, 4.9, 4.14, 15.2_

- [x] 5. Lock classification
  - [x] 5.1 Implement `LockClassifier`
    - `cwd` vs `openFileHandle` by fd; role rules: Daemon_Allowlist wins over Shell_Set, `idleShell` only when the terminal's foreground pgid equals the shell's pgid, otherwise `cliTool` (has controlling terminal), `userApplication` (no terminal, executable in an app bundle), else `unknown`
    - Undeterminable foreground pgid never yields `idleShell`; start time recorded when obtainable, absent otherwise (record kept)
    - Return `nil` when the path is not under the mount point or sits under a symlink resolving outside the volume (via `FileSystemProbing`)
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 5.6, 5.7, 5.8, 5.9, 5.10, 5.11_
  - [x] 5.2 Write property test for classification consistency
    - **Property 7: Classification consistency**
    - **Validates: Requirements 5.1, 5.2, 5.3, 5.6, 5.8**
  - [x] 5.3 Write property test for symlink containment
    - **Property 8: Symlink containment**
    - **Validates: Requirements 5.7**
  - [x] 5.4 Write unit tests for role assignment
    - Each allowlist entry, each shell variant, idle vs foreground-job shells, undeterminable pgid, missing start time
    - _Requirements: 5.3, 5.4, 5.5, 5.9, 5.10, 5.11_

- [x] 6. Safety policy
  - [x] 6.1 Implement `SafetyPolicy` and attempt history
    - In `Sources/PhantomTraceCore/Resolution/`: deny Protected_Process (PID 0, 1, own PID, `launchd`, `kernel_task`, `WindowServer`, `loginwindow`, `Finder`), other-user processes without authorization, `sendSIGKILL` without a recorded graceful attempt (except user-confirmed `systemDaemon`), and any undetermined state after 1000 ms; otherwise allow
    - Return typed denial reasons (protected process, missing authorization, escalation required, undetermined safety state)
    - Make it the only approval path used by the pipeline
    - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 6.7_
  - [x] 6.2 Write property test for the safety deny-list
    - **Property 11: Safety deny-list**
    - **Validates: Requirements 6.1, 6.2, 6.5**
  - [x] 6.3 Write property test for escalation order in the policy
    - **Property 12: Escalation order**
    - **Validates: Requirements 6.3, 6.4, 8.6, 9.1**
  - [x] 6.4 Write table-driven unit tests for the policy
    - Each protected name, own pid, other-user process, daemon confirmation, 1000 ms timeout path
    - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.6_

- [x] 7. Discovery engine and state machine
  - [x] 7.1 Implement `LockDiscoveryEngine`
    - Run `/usr/sbin/lsof -F pcLnftau0 -w +f -- <mountpoint>` through `ProcessRunning` (15 s timeout), parse, classify, merge by (pid, path), exclude own PID, stable ordering
    - On truncation or timeout: terminate lsof, run `lsof +D` and `fuser -c` (15 s each), merge, set partial = true; return `lsofTimedOut` when the fallback yields nothing usable; return `lsofUnavailable` when lsof is missing
    - Run off the main actor, deliver asynchronously (`async`/`AsyncStream`), first results within 2 s for the specified volume size
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 3.8, 3.9, 3.10, 15.1, 15.6, 15.7, 15.8_
  - [x] 7.2 Implement the discovery state machine reducer
    - Pure reducer over `DiscoveryState` (Idle, Resolving, Scanning, Parsed, Classified, Clean, Blocked, ResolvingStage, Unmounting, Unmounted, Failed, Partial) following the design diagram
    - On Failed, no signal or file change is possible; carry Parse_Warnings for the Failure_Banner
    - _Requirements: 3.6, 10.3, 10.6, 14.1, 14.4_
  - [x] 7.3 Write property test for discovery idempotence and merging
    - **Property 17: Discovery idempotence and merging**
    - **Validates: Requirements 3.3, 3.4, 3.5**
  - [x] 7.4 Write unit tests for discovery
    - Fallback path, `lsofTimedOut`, `lsofUnavailable`, argument array contains the mount point verbatim after `--`, empty-after-exclusion result, state transitions
    - _Requirements: 3.4, 3.6, 3.7, 3.8, 15.1, 15.8_

- [x] 8. Resolution pipeline (stages 1 to 4)
  - [x] 8.1 Implement plan building for stages 1 to 3
    - Egress: one `resetShellCwd` per cwd lock held by an `idleShell`. Graceful: one `quitApplication` per distinct GUI pid, one `sendSIGTERM` per distinct non-GUI non-protected pid, protected daemons excluded, zero actions reported as "no actions" with no grace wait. Banish: `sendSIGKILL` only for pids in a fresh scan (at most 5 s old) with a recorded graceful attempt, otherwise zero actions and a "no eligible processes" result
    - Route every action through `SafetyPolicy`; denied actions go to `skipped` with the reason; other-user locks excluded from targets
    - _Requirements: 7.1, 8.1, 8.2, 8.3, 8.4, 9.1, 9.2, 11.5, 11.7, 13.12_
  - [x] 8.2 Implement stage execution
    - Fresh scan at stage start (30 s limit, abort without a plan on failure); execute only the user-selected stage; verify `(pid, startTime)` identity before each signal and record `processIdentityChanged` on mismatch while continuing
    - Record exactly one graceful attempt per `quitApplication`/`sendSIGTERM` (including failed deliveries); grace wait default 5 s (configurable 1 to 60 s); 500 ms settle then post-stage rescan with a 30 s timeout producing a rescan-timed-out outcome
    - Banish: show target list (name and pid) before execution, send zero `sendSIGKILL` until explicit confirmation, re-verify pid and process name at confirmation and skip changed targets; record `EPERM` as `permissionDenied(pid:)`, continue, and never escalate privilege silently
    - _Requirements: 6.8, 6.9, 8.5, 8.6, 8.7, 9.3, 9.4, 9.5, 9.6, 11.1, 11.2, 11.3, 11.4, 11.6, 11.8, 14.3_
  - [x] 8.3 Implement Egress Shells action performer
    - Send the fixed literal ` cd ~` plus newline once via `TerminalScripting` only when the shell has a scriptable terminal and no foreground job; re-inspect within 5 s and mark succeeded only if the shell is alive with cwd off the volume
    - Mark manual (with the `cd ~` instruction for the pid) when not scriptable, no terminal, or foreground job; mark failed on send failure with no retry; never include process data or paths in the injected text
    - _Requirements: 7.2, 7.3, 7.4, 7.5, 7.6, 7.7_
  - [x] 8.4 Implement Clean Handoff (stage 4)
    - Fresh pre-unmount scan within 10 s; unmount only with zero locks and user confirmation; locks present or `kDAReturnBusy`/`EBUSY` return to Blocked with a rescan and newly discovered locks; scan failure or timeout means no unmount call and an error
    - Non-forced by default, force only after the advanced confirmation; `diskutil` fallback exactly once for non-busy DiskArbitration failures; `unmountFailed(code:)` when both fail
    - _Requirements: 10.1, 10.2, 10.3, 10.4, 10.5, 10.6, 10.7, 10.8, 10.9_
  - [x] 8.5 Write property test for the identity guard
    - **Property 13: Identity guard**
    - **Validates: Requirements 6.8, 6.9**
  - [x] 8.6 Write property test for stage plan construction
    - **Property 14: Stage plan construction**
    - **Validates: Requirements 7.1, 8.1, 8.2, 8.3, 11.7**
  - [x] 8.7 Write property test for unmount gating
    - **Property 15: Unmount gating**
    - **Validates: Requirements 10.1, 10.2, 10.3**
  - [x] 8.8 Write property test for fresh state per stage
    - **Property 16: Fresh state per stage**
    - **Validates: Requirements 11.1, 11.2**
  - [x] 8.9 Write unit tests for the pipeline
    - Scripted mock systems: attempt recording on delivery failure, grace period bounds, zero-action stages, banish confirmation gating, rescan timeout outcome, `EPERM` handling, egress literal text and manual/failed paths, diskutil fallback and `unmountFailed`
    - _Requirements: 7.2, 7.5, 7.6, 7.7, 8.4, 8.5, 8.7, 9.2, 9.5, 11.4, 14.3, 10.5, 10.7_

- [x] 9. Checkpoint - Core complete
  - Ensure all tests pass, ask the user if questions arise.

- [x] 10. Live system adapters
  - [x] 10.1 Implement `LiveProcessRunner`
    - Foundation `Process` with executable path plus argument array, never a shell; 10 s default timeout with per-call override (lsof 15 s); terminate on timeout, discard partial output, report a timeout error naming the command; stay responsive
    - _Requirements: 15.1, 15.6, 15.7_
  - [x] 10.2 Implement live mount table, `.dmg` mapping, and file system probe
    - `getmntinfo`/`statfs`-based `MountTableProviding`; `hdiutil info -plist` parsing for attached images; `realpath`-based probe with symlink and firmlink resolution
    - _Requirements: 1.1, 1.4, 1.5, 15.1_
  - [x] 10.3 Implement live signal sender and process inspector
    - `kill(2)` wrapper mapping `EPERM` and `ESRCH`; process start time, owner, tty, and foreground pgid via `proc_pidinfo`/`sysctl`; executable-in-app-bundle check
    - _Requirements: 5.4, 5.5, 5.9, 6.8, 14.3_
  - [x] 10.4 Implement `LiveUnmounter`
    - `DADiskCreateFromVolumePath` + `DADiskUnmount` with `kDADiskUnmountOptionDefault` (force option only when requested); map `kDAReturnBusy` to busy; exactly one `/usr/sbin/diskutil unmount` fallback via argument array
    - _Requirements: 10.2, 10.5, 10.6, 10.7, 10.8, 10.9, 15.1_
  - [x] 10.5 Implement live terminal scripting
    - Terminal.app and iTerm2 detection by tty; send text via `/usr/bin/osascript` with the script passed as an argument array and only the fixed literal text interpolated; report not-scriptable instead of failing
    - _Requirements: 7.2, 7.5, 7.7, 15.1_
  - [x] 10.6 Write property test for argument-array fidelity
    - **Property 21: Argument-array fidelity**
    - **Validates: Requirements 15.1**
  - [x] 10.7 Write local integration test with a temporary disk image
    - `hdiutil create -size 10m -fs APFS`, attach, hold a file open with `cat` and a shell with cwd inside, then discover and unmount via core APIs; skip automatically when `hdiutil` is unavailable; always detach and clean up
    - _Requirements: 3.1, 3.2, 10.2, 15.1_

- [x] 11. CLI and URL handling
  - [x] 11.1 Implement inspect URL parsing in Core
    - Parse `phantomtrace://inspect?path=<percent-encoded>`, percent-decode, canonicalize (symlinks, `.`, `..`, redundant separators); reject malformed URLs, missing or empty `path`, paths over 1024 characters, and nonexistent canonical paths with a reason
    - _Requirements: 12.1, 12.3, 12.4_
  - [x] 11.2 Implement the `phantomtrace` CLI
    - In `Sources/phantomtrace/main.swift`: resolve the volume, run discovery, print Lock_Records to standard output, exit 0; for no path, an invalid path, or an unresolvable path print the reason to standard error, print no records, and exit non-zero
    - _Requirements: 12.5, 12.6, 12.7_
  - [x] 11.3 Write property test for URL round-trip
    - **Property 18: Quick Action URL round-trip**
    - **Validates: Requirements 12.1, 12.3**
  - [x] 11.4 Write unit tests for URL rejection and CLI behavior
    - Malformed URL, missing/empty/oversized path, nonexistent path, CLI success and error exit codes using mock adapters
    - _Requirements: 12.4, 12.5, 12.6, 12.7_

- [x] 12. Window-state model and selection logic (pure, in Core)
  - [x] 12.1 Implement `WindowState`, `GhostState`, `PhantomChoice`, `WindowModel`, `selectWindow`, and `ghostFor`
    - In `Sources/PhantomTraceCore/Presentation/`: Clean/Unmounting/Unmounted select `volumeReleased`; Blocked selects `cannotPutAway` until the Proceeded_Flag is set or the current window is `phantomTrace`; failed or partial scans select `phantomTrace`; Scanning keeps window and ghost unchanged and sets `isScanning`; a missing mount selects `volumeReleased` with `volumeStillMounted = false` from any window; ghost derived only from window
    - _Requirements: 18.1, 18.2, 18.3, 18.4, 18.5, 18.8, 18.9_
  - [x] 12.2 Implement path middle truncation
    - Pure function taking a path and a width measure (injected) and keeping leading and trailing components visible; returns the path unchanged when it fits
    - _Requirements: 13.2_
  - [x] 12.3 Implement `DiagnosticCoordinator` (view-model logic)
    - Orchestrates resolver, discovery, state machine, pipeline, and window selection; exposes `WindowModel` updates through `AsyncStream`; sets the Proceeded_Flag on proceed from `cannotPutAway`
    - Implements Proceed behavior: with `handleMyself` perform a fresh rescan only and send no signal (PROVISIONAL, Req 18.16); with a stage run the plan preview, confirmation for Banish, then rescan; rescan with locks stays in `phantomTrace`, zero locks goes to `volumeReleased`; Eject runs Clean Handoff; busy unmount shows `phantomTrace` with red ghost
    - Provisional rules, each isolated and commented: no content during Idle/Resolving/resolve-Failed (18.6); first-scan overlay only after 500 ms (18.7); no control returns from `phantomTrace` to `cannotPutAway` (18.15); Eject plus Finder note while mounted and message only after unmount (18.21, 18.23); failed/partial scan shows `phantomTrace` with Failure_Banner, enabled Rescan, and Proceed and stage options disabled (18.26)
    - Disable Proceed until a choice is selected, disable inapplicable stage options, disable all options with no lock details, mark other-user locks read-only and excluded from targets; clear banner and warnings when a rescan starts
    - _Requirements: 2.4, 2.5, 13.4, 13.5, 13.12, 13.13, 14.1, 14.2, 14.4, 14.5, 18.6, 18.7, 18.12, 18.14, 18.15, 18.16, 18.17, 18.18, 18.19, 18.21, 18.22, 18.23, 18.24, 18.25, 18.26_
  - [x] 12.4 Write property test for window state selection
    - **Property 22: Window state selection**
    - **Validates: Requirements 10.3, 10.6, 13.6, 13.7, 13.8, 18.1, 18.2, 18.3, 18.4**
  - [x] 12.5 Write property test for ghost state mapping
    - **Property 20: Ghost state mapping**
    - **Validates: Requirements 13.6, 13.7, 13.8, 18.5, 18.8**
  - [x] 12.6 Write property test for middle truncation
    - **Property 19: Middle truncation**
    - **Validates: Requirements 13.2**
  - [x] 12.7 Write unit tests for the coordinator
    - Window flow with mock adapters: blocked to proceed to released, rescan with locks stays, busy unmount returns to `phantomTrace`, failed scan banner and disabled controls, handle-myself sends no signal, volume vanishing, provisional paths, 50-row-limit banners (100 warnings, 500 failed actions) with omitted counts
    - _Requirements: 14.1, 14.5, 18.9, 18.12, 18.15, 18.16, 18.18, 18.19, 18.25, 18.26_

- [x] 13. Checkpoint - Core, adapters, CLI, and window model complete
  - Ensure all tests pass, ask the user if questions arise.

- [x] 14. Asset export (1x and 2x sprites)
  - [x] 14.1 Write the sprite export script
    - `Scripts/export-sprites.py` (Pillow/NumPy pinned in `Scripts/requirements.txt`): read `docs/LookAndFeel/use/` only, write cropped `name.png` and `name@2x.png` in kebab-case for `window-frame`, `shackled-volume-and-padlocks`, `crt-diagnostic-portal`, `shattered-chains-and-portullis`, `ghost-looking-left-yellow`, `ghost-looking-left-red`, `ghost-looking-left-green`; never touch `docs/LookAndFeel/original/`; not shipped in the app bundle
    - Compute and write the window-frame 9-slice insets to `window-frame.insets.json` beside the sprites
    - _Requirements: 17.3, 17.6, 17.9, 17.10, 17.13_
  - [x] 14.2 Generate sprites and verify them
    - Run the script to produce the sprite set under `Sources/PhantomTraceUI/Resources/Sprites/`; add a verification script (or extend `Scripts/verify-scaffold.sh`) that checks all 14 files and the insets file exist, 2x dimensions are double 1x, and `docs/LookAndFeel/original/` is unchanged
    - Ensure no Kiro logo, Kiro ghost artwork, or Apple font file is present
    - _Requirements: 17.3, 17.6, 17.9, 17.15, 17.17_

- [x] 15. Programmatic AppKit app
  - [x] 15.1 Create `PhantomTraceUI` and `PhantomTraceApp` targets and resource loading
    - Update `Package.swift`: library `PhantomTraceUI` (depends on Core) and executable `PhantomTraceApp`, plus `PhantomTraceUITests`; no `.xcassets`, no `.xib`, no storyboard
    - `SpriteLoader` composes 1x and 2x files into one `NSImage` from `Bundle.main.resourceURL`, logs the missing file name, and returns a text or system-drawn substitute on failure
    - `FontProvider`: register an optional Title_Font with `CTFontManagerRegisterFontsForURL` when present (system font fallback), and Table_Font Monaco then Menlo then system monospaced
    - Minimal `AppDelegate` and `main.swift` that launches without any window until input arrives
    - _Requirements: 16.1, 17.1, 17.2, 17.4, 17.7, 17.8, 17.14, 17.16_
  - [x] 15.2 Build Platinum window chrome and `NinePartImageView`
    - Pinstripe title bar, 1 px bevels, #DDDDDD background, square close box; draw the shared `window-frame` as a 9-slice using the recorded insets (or a content cutout) and place content in the interior rectangle; title plaque text drawn by the app, never baked into art
    - _Requirements: 13.9, 17.5, 17.6, 17.14, 18.10, 18.13, 18.20_
  - [x] 15.3 Compose the three windows
    - `cannotPutAway`: title "CANNOT PUT AWAY", `shackled-volume-and-padlocks`, yellow ghost, spooky message, run-a-Phantom-Trace question, one Proceed button, close box
    - `phantomTrace`: title "PHANTOM TRACE", `crt-diagnostic-portal`, red ghost, lock table, Phantom_Choice, one Proceed button
    - `volumeReleased`: title "VOLUME RELEASED", `shattered-chains-and-portullis`, green ghost, spooky message; Eject button plus Finder-retry note while mounted (PROVISIONAL, Req 18.21) and message plus Finder instruction only after unmount (PROVISIONAL, Req 18.23); progress state and disabled Eject while unmounting
    - Bind to `WindowModel`; swap illustration, ghost, plaque, and content on state change; show nothing for Idle/Resolving/resolve-failed (PROVISIONAL, Req 18.6); provide no control back to `cannotPutAway` (PROVISIONAL, Req 18.15); alert for protected/not-a-mount/unverifiable input with a single dismiss control within 1 s
    - _Requirements: 2.4, 2.5, 18.6, 18.10, 18.11, 18.13, 18.15, 18.20, 18.21, 18.23, 18.24, 18.25_
  - [x] 15.4 Build the lock table
    - Columns Process Name, PID, User, Lock Category, File Path in the Table_Font; middle truncation using 12.2 with full-path tooltip; other-user rows read-only with lock icon and text explanation; empty-table message "no lock details could be retrieved" when Blocked with no records; dim while a stage runs
    - _Requirements: 13.1, 13.2, 13.5, 13.12, 13.13, 17.16_
  - [x] 15.5 Build the Phantom_Choice control and Proceed/Eject buttons
    - "Let PhantomTrace act" with Egress Shells, Graceful Request, Banish Locks in stage order, and "I'll deal with these processes myself"; Clean Handoff not offered; inapplicable stage options disabled and exposed to VoiceOver; Proceed disabled until a choice is selected; progress state on Proceed and all options disabled while a stage runs; Banish target list and explicit confirmation dialog; plan preview with skipped locks and denial reasons; advanced force-unmount confirmation
    - _Requirements: 9.4, 9.5, 11.5, 13.3, 13.4, 13.5, 18.14, 10.8_
  - [x] 15.6 Build the Scanning_Overlay, Failure_Banner, and stage failure list
    - Scanning_Overlay drawn inside the current sheet without changing window or ghost; for the first scan show the frame with overlay only after 500 ms (PROVISIONAL, Req 18.7)
    - Failure_Banner within 500 ms: failed vs partial description, up to 100 Parse_Warnings with omitted count, enabled Rescan button that clears banner and warnings when a new run begins; on failed/partial scans disable Proceed and stage options (PROVISIONAL, Req 18.26)
    - Failed-action list (up to 500, omitted count) with pid and error kind; messages for no eligible Banish processes and scan failures
    - _Requirements: 9.2, 9.3, 14.1, 14.2, 14.5, 18.5, 18.7, 18.26_
  - [x] 15.7 Implement URL handler, Services entry, and drop target
    - `application(_:open:)` for `phantomtrace://` URLs using 11.1 (reject with a visible error and no scan); `NSServices` provider that passes the selected item to the same path; non-menu-bar drop window and Dock icon accepting volumes or folders, resolution begins within 2 s
    - _Requirements: 12.1, 12.2, 12.3, 12.4, 12.10_
  - [x] 15.8 Implement the app-side `AppQuitter` and wire live adapters
    - `NSRunningApplication`-based `AppQuitting` (AppKit stays out of Core); construct live adapters (10.x) and `DiagnosticCoordinator`; run scans off the main actor and never block it more than 100 ms; open zero network connections
    - _Requirements: 3.9, 8.1, 15.3, 15.4, 15.5_
  - [x] 15.9 Add accessibility and Reduce Motion support
    - Non-empty VoiceOver labels for Phantom_Choice and each option, each stage button, Proceed, Eject, Failure_Banner, Rescan, every illustration, and the Ghost_Mascot; Reduce Motion shows every sprite and illustration static with no glow animation; sufficient contrast
    - _Requirements: 13.10, 13.11, 13.14_
  - [x] 15.10 Write unit tests for app-side logic
    - `SpriteLoader` substitute on missing or corrupt file, 1x+2x composition, Table_Font fallback order, Title_Font absence fallback, ghost sprite chosen from `WindowModel`, accessibility labels non-empty
    - _Requirements: 13.6, 13.7, 13.8, 13.11, 17.4, 17.7, 17.8, 17.16_

- [x] 16. Finder Quick Action
  - [x] 16.1 Create the hand-written `.workflow` bundle
    - `Packaging/QuickAction/Why Can't I Eject?.workflow` as plain property list files (`Info.plist`, `document.wflow`) that opens `phantomtrace://inspect?path=<percent-encoded>` for the selected item; no App Intents
    - _Requirements: 12.1, 12.10_
  - [x] 16.2 Write `Scripts/install-quick-action.sh`
    - Copy the workflow to `~/Library/Services` and refresh Services (`/System/Library/CoreServices/pbs -flush`); on failure print the cause to standard error, exit non-zero, and leave any previously installed Quick_Action unchanged (stage to a temp location, replace only on success)
    - _Requirements: 12.8, 12.9, 12.11_
  - [x] 16.3 Write script tests for the installer
    - Shell-level test using a temporary `HOME`: success installs, failure leaves the previous copy intact and exits non-zero
    - _Requirements: 12.9, 12.11_

- [x] 17. Bundling script (SwiftPM and Command Line Tools only)
  - [x] 17.1 Create packaging templates
    - `Packaging/Info.plist.template` with `CFBundleExecutable`, `CFBundleIdentifier`, `LSMinimumSystemVersion` 27.2.1, `CFBundleURLTypes` for `phantomtrace`, and the `NSServices` entry; `Packaging/PhantomTrace.entitlements` with only required entitlements and no App Sandbox (Automation only if terminal scripting ships)
    - _Requirements: 16.3, 16.4, 16.7_
  - [x] 17.2 Write `Scripts/make-app.sh`
    - `swift build` of `PhantomTraceApp` only (no `xcodebuild`, `actool`, Interface Builder); assemble in a temporary location with `Contents/MacOS/PhantomTrace`, `Contents/Info.plist`, `Contents/Resources` (sprites, insets file, and Title_Font plus its license file when present); `codesign --force --options runtime --entitlements ... --sign -` (identity overridable); `codesign --verify --strict`; replace `build/PhantomTrace.app` only after verification passes
    - On any failure print the failed step and cause to standard error, exit non-zero, and leave an existing bundle unchanged; exit 0 on success; do not notarize
    - _Requirements: 16.1, 16.2, 16.3, 16.5, 16.6, 16.8, 16.9, 16.10, 16.11, 16.12, 17.1_
  - [x] 17.3 Write script tests for the bundler
    - Shell-level test of bundle layout, Info.plist keys, signature verification, no Apple font file present, and a forced-failure run that leaves the previous bundle byte-identical
    - _Requirements: 16.2, 16.3, 16.9, 16.10, 17.17_

- [x] 18. Documentation and ProjectLog
  - [x] 18.1 Update project documentation
    - README and `docs/`: build and bundle instructions (Command Line Tools only), Quick Action install, optional manual notarization with `xcrun notarytool submit --wait` and `xcrun stapler staple`, confirmed Window_State to image mapping, spike findings from 1.1, and the provisional behaviors list
    - Update `docs/Assets.md` for every sprite and font added or replaced, in the same change
    - _Requirements: 16.12, 17.11, 17.18_
  - [x] 18.2 Update `docs/ProjectLog.md`
    - Add dated entries (UTC, per the log's heading format, no gendered pronouns) for the implemented milestones, design decisions (UI library split, test-support target), and open provisional items
    - _Requirements: 17.18_

- [x] 19. Final manual submission checks
  - [x] 19.1 Record Assets.md "To confirm" items
    - Fill in provenance, author, and license of the Original_Art in `docs/Assets.md`, using the information the user supplies; leave any unconfirmed field clearly marked
    - _Requirements: 17.12, 17.18_
  - [x] 19.2 Record the ghost side-by-side check
    - Add the result and date of the side-by-side comparison of the Ghost_Mascot against the official Kiro ghost to `docs/Assets.md`; confirm no Kiro logo or ghost artwork is bundled
    - _Requirements: 17.12, 17.15_
  - [x] 19.3 Record the title font choice and app icon
    - If a Title_Font is chosen, place it with its license file in the resources folder and add name, author, version, source, and license to `docs/Assets.md`; otherwise record that the system font fallback is used
    - Add the app icon row to `docs/Assets.md` once an icon exists (no Kiro artwork), and update `make-app.sh` inputs if needed
    - _Requirements: 17.2, 17.8, 17.12, 17.15, 17.18_
  - [x] 19.4 Write the manual QA checklist
    - Add `docs/ManualQA.md` covering bundle signature, URL scheme launch, Quick Action in Finder (workflow vs `NSServices`), drop target, 1x/2x sprites and fonts, all three windows, the provisional behaviors awaiting user confirmation, and the CLI against a test disk image
    - _Requirements: 12.1, 12.2, 12.10, 16.8, 17.3, 18.6, 18.7, 18.15, 18.16, 18.21, 18.23, 18.26_

- [x] 20. Final checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 21. Volume picker and app menu (Requirement 19, design Component 8a)
  - [x] 21.1 Implement `VolumeListEntry` and pure `VolumeLister.list`
    - In `Sources/PhantomTraceCore/Mounts/`: `VolumeListEntry` (canonical `mountPoint`, non-empty `displayName`, `isRemovable`, `isDiskImage`; `Equatable`, `Hashable`, `Sendable`) and `VolumeLister.list(_ mounts: [MountInfo]) -> [VolumeListEntry]` with no I/O
    - Apply the design rules in order: drop `MountResolver.isProtected` mounts (reuse, do not reimplement); drop hidden/system mounts (types `devfs`/`autofs`/`nullfs`/`fdesc`/`procfs`, device nodes not starting with `/dev/`, `com.apple.TimeMachine.localsnapshots` and anything under it, mount points under `/private/var`, dot-prefixed last components); de-duplicate by lexically normalized mount point with the smallest `(volumeName, deviceNode)` winning; map with `displayName` falling back to the last path component; sort by display name (case-insensitive, then case-sensitive, byte-wise NFC) then mount point bytes
    - Unknown or undeterminable attributes mean exclude; no force unwraps or unchecked indexing
    - _Requirements: 19.3, 19.4, 19.5, 19.6, 19.7, 2.1, 2.5_

  - [x] 21.2 Add `MountedVolumeEnumerating`, its live adapter, and a mock
    - In `Sources/PhantomTraceCore/System/`: protocol `MountedVolumeEnumerating: Sendable` with `func enumerate() throws -> [MountInfo]`, in its own file
    - Live adapter in a separate file using `FileManager.mountedVolumeURLs(includingResourceValuesForKeys:options: .skipHiddenVolumes)` with `volumeNameKey`, `volumeIsRemovableKey`, `volumeIsEjectableKey` (`isRemovable` is removable OR ejectable), or the existing mount table provider; any failure throws a `PhantomTraceError` and never traps
    - Add a hand-written, deterministic, call-recording mock to `PhantomTraceTestSupport` that returns a canned list or throws
    - _Requirements: 19.3, 19.9, 19.11_

  - [x]* 21.3 Write property test for volume list exclusion
    - **Property 23: Volume list exclusion**
    - Generators: mount tables with protected paths, hidden types, non-`/dev/` nodes, snapshot directories, `/private/var` and dot-name mounts; at least 500 iterations
    - **Validates: Requirements 19.4, 19.5, 2.1, 2.5**

  - [x]* 21.4 Write property test for volume list completeness
    - **Property 24: Volume list completeness**
    - **Validates: Requirements 19.3, 19.6**

  - [x]* 21.5 Write property test for volume list idempotence
    - **Property 25: Volume list idempotence** (`list(mounts(list(M))) == list(M)` and `list(M + M) == list(M)`)
    - **Validates: Requirements 19.6**

  - [x]* 21.6 Write property test for order independence and determinism
    - **Property 26: Volume list order independence and determinism** (shuffled permutations equal, result sorted by `(displayName, mountPoint.path)`)
    - **Validates: Requirements 19.7**

  - [x]* 21.7 Write property test for de-duplication
    - **Property 27: Volume list de-duplication** (same mount point differing by trailing slash or `.` components)
    - **Validates: Requirements 19.6**

  - [x]* 21.8 Write unit tests for `VolumeLister`
    - Cases: a Flash1GB-like removable volume is listed with `isRemovable == true`; a Time Machine local snapshot mount is excluded; a network share (`smbfs`/`nfs` with a non-`/dev/` node) is handled per the rules; a dot-name mount is excluded; `/`, `/System/Volumes/Data`, `/private/var/vm` excluded; empty `volumeName` falls back to the last path component; disk image flag preserved; empty input yields an empty list
    - Add the enumerator mock cases (success and throwing)
    - _Requirements: 19.3, 19.4, 19.5, 19.6, 19.7, 19.11_

  - [x] 21.9 Build the App main menu in `PhantomTraceUI`
    - Menu builder producing the PhantomTrace, File, and Window menus per the design table with responder-chain selectors and key equivalents (Cmd-H, Opt-Cmd-H, Cmd-Q, Cmd-O, Cmd-W, Cmd-M); set `NSApplication.windowsMenu`; no `.xib`
    - File > Inspect... opens an `NSOpenPanel` (`canChooseFiles` and `canChooseDirectories` true, multiple selection false) and passes the chosen URL to `InspectRequestRouter.handle(url:)`; cancel does nothing; the panel performs no scan
    - File > Inspect Volume submenu rebuilt from `[VolumeListEntry]` (same order as the window list; `representedObject` is the mount point path; tooltip and attributed secondary line; removable marker); empty list shows one disabled "No volumes available to inspect"
    - `validateMenuItem`: Close Window disabled when no window is key; Inspect items disabled only while the router has a request in flight
    - Keep the structure-building logic separate from the panel presentation so it is testable without launching the app; never create an `NSStatusItem`
    - _Requirements: 19.1, 19.2, 19.3, 19.8, 19.10, 19.13, 19.15_

  - [x] 21.10 Add the volume list view to the drop window
    - Platinum-styled list beside the drop target: Monaco rows, 1px beveled frame, platinum selection highlight, square-edged Inspect buttons; each row shows volume name, middle-truncated mount point (full path in tooltip and accessibility value), and a text "Removable"/"Internal" label with a glyph (never color alone)
    - Inspect button, double-click, and Return on a selected row call `InspectRequestRouter.handle(path: entry.mountPoint.path)`; the view never calls adapters or `MountResolver`
    - VoiceOver: one element per row labelled "<name>, <mount point>, <removable|internal>", button label "Inspect <name>"; arrow keys navigate, Tab reaches list and buttons, Space/Return activates; Reduce Motion honored (no animated updates)
    - Empty list shows "No volumes available to inspect" with the drop area and File > Inspect... still operable; enumeration failure keeps the previous list and shows "Couldn't read the list of volumes", cleared by the next successful enumeration; a router rejection shows its reason through `onRejected` and starts no scan
    - _Requirements: 19.3, 19.8, 19.10, 19.11, 19.12, 19.13, 13.2_

  - [x] 21.11 Implement the volume refresh controller
    - In the UI/app layer: observe `NSWorkspace.didMountNotification`, `didUnmountNotification`, and `didRenameVolumeNotification` on `NSWorkspace.shared.notificationCenter`; coalesce with a 500 ms debounce that restarts on each event, using an injected clock/scheduler (no real sleeps in tests)
    - Each refresh runs `MountedVolumeEnumerating.enumerate()` off the main actor, then `VolumeLister.list`, then swaps the list and rebuilds the submenu on the main actor, completing within 1000 ms of the last event; also refresh when the drop window is shown; on failure keep the previous list and report the failure state
    - Provide a testable seam so the debounce logic can be driven by a fake clock and a fake notification source
    - _Requirements: 19.9, 19.11_

  - [x] 21.12 Wire the menu, list, and refresh into `AppDelegate`
    - Set the main menu at launch, create the refresh controller with the live enumerator and clock, feed one list to both the window view and the submenu
    - Launch with no input (no `phantomtrace://` URL, no opened file, no dropped item): show the drop window with the current list within 2000 ms of launch completing and start no scan
    - Cmd-W closes the drop window without quitting and without cancelling a running inspect flow; File > Inspect... or reactivation with no visible window shows it again; Quit, Hide, and Minimize use the standard selectors
    - _Requirements: 19.1, 19.2, 19.3, 19.9, 19.14, 19.15_

  - [x]* 21.13 Write property test for picker selection equals drop
    - **Property 28: Picker selection equals drop**
    - Use a recording router/closure pair; for generated entries, selecting from the window list, the submenu item, and the open panel result each deliver the same `handle(path: e.mountPoint.path)` as a drop, exactly one request per selection, no adapter calls, no scan; at least 500 iterations
    - **Validates: Requirements 19.2, 19.8, 12.1, 12.3**

  - [x]* 21.14 Write unit and UI tests for the menu and picker
    - **Property 29: No status-bar item**: inspect the built `NSMenu` structure (App, File, Window menus, key equivalents, Inspect Volume submenu, empty-state item) and assert no `NSStatusItem` is created by menu and window setup, without launching the app
    - Test refresh debounce with the fake clock (burst yields one refresh; restart on each event), failure message set and cleared, empty-list message, router rejection reporting, Close Window validation
    - **Validates: Requirements 19.1**
    - _Requirements: 19.1, 19.9, 19.10, 19.11, 19.12, 19.13, 19.15_

  - [x] 21.15 Update documentation and ProjectLog
    - README: Status and usage for the volume picker and main menu; `docs/ManualQA.md`: Cmd-Q, Cmd-W, Cmd-O, Inspect Volume submenu, mount/unmount/rename refresh with a throwaway `.dmg`, VoiceOver and keyboard navigation, launch with no input, empty and failure messages; `docs/architecture.md`: summarize Component 8a and link to the design; `docs/ProjectLog.md`: work-log row (valid Kiro surface, "not verified on macOS" where true) plus a `D-NNN` decision entry clarifying that "no menu-bar item" means no `NSStatusItem`, not no main menu
    - _Requirements: 19.1, 19.14, 19.15_

- [x] 22. Final checkpoint - Volume picker and app menu
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for a faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation
- Property tests validate the universal correctness properties from the design (Properties 1 to 29)
- Unit tests validate specific examples and edge cases
- Provisional Requirement 18 criteria are labelled in code and listed in `docs/ManualQA.md` so they can be revised after user confirmation
- Tasks 19.1 to 19.3 need information only the user can supply; record it when available and mark unknowns explicitly

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1", "2.1"] },
    { "id": 1, "tasks": ["2.2", "4.1", "4.2", "11.1", "12.2", "14.1", "16.1", "17.1"] },
    { "id": 2, "tasks": ["2.3", "3.1", "4.3", "4.4", "4.5", "4.6", "4.7", "4.8", "4.9", "5.1", "6.1", "10.1", "10.2", "11.3", "12.1", "12.6", "14.2", "16.2"] },
    { "id": 3, "tasks": ["3.2", "3.3", "3.4", "5.2", "5.3", "5.4", "6.2", "6.3", "6.4", "7.1", "7.2", "8.1", "10.3", "10.4", "10.5", "12.4", "12.5", "16.3"] },
    { "id": 4, "tasks": ["7.3", "7.4", "8.3", "8.4", "10.6", "10.7", "11.2", "12.3"] },
    { "id": 5, "tasks": ["8.2", "11.4", "12.7", "15.1"] },
    { "id": 6, "tasks": ["8.5", "8.6", "8.7", "8.8", "8.9", "15.2", "17.2"] },
    { "id": 7, "tasks": ["15.4", "15.5", "15.6", "15.7", "15.10", "17.3"] },
    { "id": 8, "tasks": ["15.3"] },
    { "id": 9, "tasks": ["15.8", "15.9"] },
    { "id": 10, "tasks": ["18.1", "18.2"] },
    { "id": 11, "tasks": ["19.1", "19.2", "19.3", "19.4"] },
    { "id": 12, "tasks": ["21.1", "21.2"] },
    { "id": 13, "tasks": ["21.3", "21.4", "21.5", "21.6", "21.7", "21.8", "21.9", "21.11"] },
    { "id": 14, "tasks": ["21.10"] },
    { "id": 15, "tasks": ["21.12"] },
    { "id": 16, "tasks": ["21.13", "21.14", "21.15"] }
  ]
}
```
