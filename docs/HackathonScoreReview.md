# Kiroween 2026 Score Review: PhantomTrace (Resurrection)

Date: 2026-11-13 (UTC). Days left until December 4, 2026, 2:00 pm PT (22:00 UTC): 21.

Method: independent re-score from the repository at HEAD `033a629`. Owner statements in the docs (manual QA pass, asset provenance, hooks and power use) are treated as unverified. Commands run on this Mac: `swift build` (exit 0), `swiftlint --strict` (0 violations in 205 files), `swift test` (three runs, 111 + 90 + 259 tests, all passed; the third includes the local `DiskImageIntegrationTests` on its own temp image, and `hdiutil info` showed no leftover images afterwards). No process was signaled and no real volume was unmounted by me. GitHub was checked with unauthenticated web requests.

## 1. Verdict

**Stage One: AT RISK (likely fail as things stand).** `https://github.com/iolaire/PhantomTrace` and `https://api.github.com/repos/iolaire/PhantomTrace` both return HTTP 404 to an unauthenticated request. A public repo is a hard rule, so the repo is private or not reachable. Theme fit and Kiro use would otherwise pass.

**Score: 25 / 50.** Strong engineering and a real Kiro process trail, but nothing a judge can see yet: no video, no screenshots, no confirmed public repo, no release build.

One line: a well-engineered, safety-minded tool whose judge-facing artifacts (public repo, video, screenshots, finished Kiro write-up) do not exist yet.

## 2. Score table

| Criterion | Score | Reason |
|---|---|---|
| Potential Impact | 6 | Real, relatable problem and a safe pipeline; one macOS build only, and the working flow is owner-reported, not shown publicly. |
| Technological Implementation | 7 | Real specs, 11 steering files, 4 hooks, 24 property suites at 500 iterations, two documented bugs, one logged power audit. No custom agents or MCP use; hook firing unproven. |
| Design | 5 | Coherent Platinum look with sprites, icon, custom dialogs and accessibility labels in code; no screenshot, VoiceOver and Reduce Motion untested. |
| Innovation/Idea | 5 | Good Resurrection framing and a graduated opt-in pipeline; the core function overlaps `lsof` and "What's Keeping Me?". |
| Presentation | 2 | No video (cap 3). README is a clear written pitch but has no images. |
| **Total** | **25 / 50** | |

## 3. Disqualification and blocker list (most severe first)

1. **Repo not publicly reachable.** Both GitHub URLs above returned 404. Remote is `origin https://github.com/iolaire/PhantomTrace.git`. Public visibility and license detection in the About box cannot be confirmed. `docs/SubmissionChecklist.md` leaves this item unticked.
2. **No demo video.** No YouTube link in the repo. Presentation capped at 3 (scored 2). Best Demo impossible. `docs/demo-script.md` is a plan only.
3. **No screenshots.** `docs/screenshots/` is empty (only a placeholder). The README says "No screenshots or demo video exist yet."
4. **Judges are unlikely to be able to run it.** One macOS build is supported (27.2.1), there is no prebuilt release, the app is ad-hoc signed and not notarized, and the Quick Action must be enabled by hand in Finder (README, "Finder Quick Action"). An AI or time-limited judge will not get past this.
5. **Kiro write-up is incomplete.** `docs/KiroUsage.md` still says "record any created" (custom agents), "record any servers used" (MCP), and has "Evidence to add" lines (captured hook output, with/without steering comparison, surface differences, vibe coding comparison).
6. **Manual QA unrecorded.** `docs/ManualQA.md` has 0 ticked and 107 unticked boxes. The working-app claim rests on one owner statement.
7. **Thin history evidence.** 26 commits, all dated 2026-11-10 to 2026-11-12 (three days of a 36-day window). Commit `c441700` adds 235 files and 18,043 lines at once. The first commit (2026-11-10) is inside the Submission Period, so it is not a disqualifier, but the history shows little of the iterative building that the log claims.

## 4. Stage One detail

**A. Disqualification risks**

| Item | Result | Evidence |
|---|---|---|
| Real, substantive Kiro use | Pass | `.kiro/specs` (2 specs, master: design 1,272 lines, requirements 431, tasks 482, 125 ticked, 0 open), `.kiro/steering` (11 files), `.kiro/hooks` (4), `.kiro/prompts/score-hackathon.md`; `docs/ProjectLog.md` rows cite task and requirement numbers. |
| `/.kiro` at root, not in `.gitignore` | Pass | `.gitignore` has no `.kiro` entry; `git ls-files .kiro` lists 25 files. |
| Public GitHub repo with detectable MIT `LICENSE` | **Fail / unverifiable** | `LICENSE` exists and starts "MIT License", but GitHub returns 404 to anonymous requests. |
| Created in the Submission Period | Pass | First commit `b311c6c` 2026-11-10. README states "Pre-existing code: none" and discloses the 2025 West of House image-prompt carry-over. |
| Source, assets, run instructions in repo | Pass | `Sources/`, `Packaging/`, sprites under `Sources/PhantomTraceUI/Resources/Sprites`, README Build and Run sections. |
| No unlicensed assets or trademarks | Pass with risk | `docs/Assets.md` records Gemini-generated art and system fonts loaded by name (nothing bundled). The ghost is "Kiro-inspired"; the owner compared it by eye and judged it distinct. This is unverified and a visual-similarity risk. |
| English only | Pass | All reviewed docs and UI strings are English. |

**B. Functionality**

| Item | Result | Evidence |
|---|---|---|
| Install and run on macOS 27.2.1 from the README | Partly verified | `swift build` passed here. I did not launch the app or run `Scripts/make-app.sh`. Quick Action, window flow and stages are owner-reported only (README Status). |
| `swift build` | Verified, passed | Exit 0 (linker warnings about missing Command Line Tools search paths only). |
| `swift test` | Verified, passed | 111, 90 and 259 tests passed. |
| `swiftlint --strict` | Verified, passed | 0 violations in 205 files, with `DYLD_FRAMEWORK_PATH` set. |

**C. Theme and tools fit**

- Resurrection: reasonable fit (System 7 / Mac OS 9 inspector style, "What's Keeping Me?" for modern macOS). Pass.
- Kiro use: reasonable and real. Pass.

## 5. Per-criterion detail

### Potential Impact: 6

Strengths
- Real, common pain: Finder's unhelpful eject error (`README.md`, `docs/ProjectOverview.md`).
- Output names process, pid, user and file; opt-in, least-destructive-first pipeline (`Sources/PhantomTraceCore/Resolution/`).
- Safety enforced at one choke point: `SafetyPolicy`, protected volumes, identity guard (`.kiro/steering/safety.md`, `Tests/PhantomTracePropertyTests/SafetyPolicy*`).
- A read-only CLI exists for scripting (`Sources/phantomtrace/main.swift`).

Weaknesses
- One macOS build only (`.kiro/steering/product.md`); a judge on any other version cannot run it.
- No public demonstration; the end-to-end flow is documented only by an owner statement (`docs/ManualQA.md` unticked).
- The Quick Action stays hidden until enabled by hand (README); friction for the stated non-technical audience.
- VoiceOver untested, so the accessibility claim is unproven (README Status).

Single change with most gain: publish a short public video of the real flow so the impact is visible.

### Technological Implementation: 7

Strengths
- Spec-driven: master spec with requirements, design and tasks, all 125 tasks ticked; log rows cite requirement numbers (`docs/ProjectLog.md`).
- Steering is specific and some of it is enforced: custom SwiftLint rules ban `print(` in Core and networking APIs in `Sources` (`.swiftlint.yml`, ProjectLog 2026-11-12 code-quality row). Core has no AppKit; `PhantomTraceUI` is separate.
- Property tests found a real bug: `ProtectedVolumeRefusalPropertyTests` caught `/private/var/vm` being rewritten by `standardizedFileURL` (`docs/KiroUsage.md`; regression test `MountResolverProtectionTests.swift` exists). 24 of 25 property files set `iterations = 500`.
- Integration test found a bug the mocks hid: `0xC000 | EBUSY` mishandled in `LiveUnmounter` (`DiskImageIntegrationTests.swift`, `LiveUnmounterTests.swift`).
- `swift-expert` power has a logged, concrete use: the D-021 concurrency audit (swallowed cancellation, `cancelled` error cases, async mount lookup, `ResolutionPipelineCancellationTests`) in `docs/ProjectLog.md` and `docs/KiroUsage.md`. The power is installed at `~/.kiro/powers/installed/swift-expert`.
- Hook design shows thought: D-006 (why four hooks, what was rejected) and D-008 (agent-only hooks miss hand commits, so tracked git hooks were added).

Weaknesses
- No custom agents (no `.kiro/agents`), no project-level MCP (`.kiro/settings` is not tracked), no Kiro Crew, CLI or Web differences written up. Kiro Web appears in two early log rows only.
- No hook output was ever captured; hook firing is owner-reported (`docs/KiroUsage.md`, `docs/SubmissionChecklist.md`). All commit hooks match `execute_bash` and see only agent-run commits.
- No vibe-coding comparison and no with/without-steering example (`docs/KiroUsage.md`, "Evidence to add").
- `Tests/Fixtures` total about 2 KB and are generated, not captured from real `lsof`, while `testing.md` asks for captured output. The cancel-with-grace change in `LiveProcessRunner` and the 60 s unmount timeout are untested (ProjectLog D-021 row).

Single change with most gain: finish `docs/KiroUsage.md` with captured hook output and a with/without-steering example, and say plainly which Kiro features were not used.

### Design: 5

Strengths
- Consistent look: nine-part window chrome, close box, choice controls, art-framed `PhantomDialog` (`Sources/PhantomTraceUI/`).
- Seven sprites at 1x and 2x plus an app icon (`Packaging/AppIcon.icns`), with provenance in `docs/Assets.md`.
- Accessibility text exists in code (`AccessibilityText.swift`, accessibility labels in 13 source files) and Reduce Motion is read from `NSWorkspace` (`LockWindowContentView.swift:109`).
- Specific copy and a three-window flow with forward and back (README Status, owner-reported).

Weaknesses
- No screenshot in the repo (`docs/screenshots/` empty), so a judge who does not run it sees nothing. The UI was launched by the owner but never captured, which keeps this near the cap.
- VoiceOver and Reduce Motion are untested (README Status).
- `docs/Assets.md` still lists Monaco and the system font as "Planned"; typography claims (Chicago/Monaco) are not bundled or confirmed on screen.
- Art is AI-generated and Kiro-inspired, which weakens originality of the visual identity and adds a similarity risk.

Single change with most gain: capture three screenshots (cannot put away, phantom trace, volume released) into `docs/screenshots/` and embed them in the README.

### Innovation/Idea: 5

Strengths
- Resurrection framing is clear: a single-purpose System 7 style inspector for the Finder eject dialog.
- Graduated, opt-in pipeline (Egress Shells, Graceful Request, Banish Locks, Clean Handoff) with fresh scan before and rescan after each stage, instead of a "kill everything" button.
- Terminal `cd ~` egress without killing the session is a distinctive touch (`Sources/PhantomTraceCore/Resolution/`).

Weaknesses
- The core function (find what holds a volume open) is what `lsof`, Activity Monitor and "What's Keeping Me?" already do; the novelty is the guided fix and the theme.
- No unusual data source or technology combination; it wraps `lsof`, DiskArbitration and `diskutil`.
- The Quick Action trigger is a standard Finder feature.

Single change with most gain: state in the pitch the one thing nothing else does (for example the idle-shell `cd ~` fix), and show it working in the video.

### Presentation: 2

Strengths
- README gives a clear problem, audience and flow in plain language.
- `docs/demo-script.md` is a tight, timed plan under 180 seconds with a Kiro cutaway.
- `docs/ProjectOverview.md` and `docs/architecture.md` explain the design.

Weaknesses
- No video; capped at 3 and scored lower because no pitch is visible anywhere (`docs/demo-script.md`: "the video has not been recorded").
- No images in the README or docs/screenshots.
- `docs/demo-script.md` setup still says "Install the Quick Action (`Scripts/install-quick-action.sh`, once it exists)"; the script exists, so the plan is stale.
- Devpost text, YouTube link and blog/social posts do not exist in the repo.

Single change with most gain: record and publish the under-3-minute YouTube video from the existing script.

## 6. Submission completeness

| Item | Status |
|---|---|
| Text description | Missing for Devpost; the README and `docs/ProjectOverview.md` are usable source text. |
| Working-app URL and test instructions | Partial. README Build and Run exist; no release build; repo not reachable anonymously. |
| YouTube link | Missing. |
| GitHub URL | Unverifiable (404 anonymously). |
| Category and bonus selections | Planned in `docs/SubmissionChecklist.md`, not submitted. |
| Kiro write-up: IDE/CLI/Web/Crew differences | Not covered ("Evidence to add"). Log shows IDE for nearly all rows, Web for two. |
| Kiro write-up: custom agents | Not used; stated as a placeholder in `docs/KiroUsage.md`. |
| Kiro write-up: hooks | Covered (four hooks, design rationale); no captured firing. |
| Kiro write-up: specs vs vibe coding | Specs covered; comparison missing. |
| Kiro write-up: steering | Covered with log-backed examples; no with/without comparison. |
| Kiro write-up: MCP | Not used; placeholder text remains. |
| Kiro write-up: property-based testing | Covered with one real bug found. |
| Kiro write-up: powers | Covered: `swift-expert`, two logged uses (D-021 audit; general Swift Testing guidance). |

## 7. Bonus prizes

| Prize | Readiness | Notes |
|---|---|---|
| Best Demo | Not started | Needs a video, top 10% overall and top Presentation score. |
| Bonus Blog Prize | Not started | No post. Must be a third-party public post, written for Kiroween 2026, published in the Submission Period. |
| Social Blitz | Not started | No post. Must start with `#KiroweenHackathon26`, with the Kiro favorite and how it changed development. |
| Best Ghost of Kiroween Past | Unverifiable | Only if the owner registered for Kiroween 2025 (West of House is mentioned). Needs a check in the form. |
| Best Kiro Crew App | Not relevant | No Kiro Crew app. |
| Best Startup, Best Student | Not relevant | No evidence of either. |

## 8. Prioritized action plan (21 days left)

Ordered by gain per hour, blockers first.

| # | Action | Gain | Hours | Criterion |
|---|---|---|---|---|
| 1 | Make the GitHub repo public, confirm `LICENSE` shows in About, test with a logged-out browser | Removes likely disqualification | 0.25 | Stage One |
| 2 | Record and publish the under-3-minute YouTube demo from `docs/demo-script.md` (fix the stale setup line first) | +4 to +5 | 3 | Presentation, Impact |
| 3 | Capture three screenshots into `docs/screenshots/` and embed them in the README | +2 | 0.5 | Design, Presentation |
| 4 | Capture one hook block or lint message and add it to `docs/KiroUsage.md`; fill the with/without-steering, vibe-coding and surface-difference lines; state plainly that custom agents and MCP were not used | +1 | 1.5 | Technological Implementation |
| 5 | Fill in `docs/ManualQA.md` (VoiceOver, Reduce Motion, drop target) and tick the checklist items that are done | +1 | 1.5 | Design, Impact |
| 6 | Attach a release zip of `build/PhantomTrace.app` (or a one-line `make-app.sh` instruction at the top of the README) so a judge can try it quickly | +1 | 1 | Impact, Functionality |
| 7 | Post `#KiroweenHackathon26` and a short blog post (third-party site) with links to the repo and video | Bonus prizes | 2 | Bonuses |
| 8 | Commit in smaller steps from now on so the history shows the work | Credibility | 0 | Stage One |
| 9 | Add one custom agent or MCP server only if it genuinely helps; do not add one just to claim it | +0.5 | 2 | Technological Implementation |

## 9. Honesty check

Claims the code or repo does not fully support:

- `README.md` Build section says `Scripts/lint-and-test.sh` "does not set it for you" (the `DYLD_FRAMEWORK_PATH` fix). `Scripts/lint-and-test.sh:6` does export it. The README is out of date.
- `docs/demo-script.md` setup: "Install the Quick Action (`Scripts/install-quick-action.sh`, once it exists)". The script exists.
- `docs/Assets.md` lists Monaco and the system font as "Planned" and the sprites as "not yet seen in a running app", while the README reports the app launched and the owner reports working windows. These disagree.
- README "Visual direction" says Monaco/Chicago typography; Chicago is not bundled or referenced as a runtime font, and no screenshot shows the result.
- `docs/KiroUsage.md` says hooks were "active in Kiro IDE" (owner statement). No hook output exists, so this is unverified.
- `.kiro/steering/testing.md` says fixtures are real captured `lsof -F` output; `docs/KiroUsage.md` correctly says they are generated, but the steering file is still wrong about it.
- `docs/SubmissionChecklist.md` leaves most hard-requirement boxes unticked even though several (for example Kiro use, `.kiro` not ignored, creation date) are supported by evidence. This is conservative, not misleading.
- The working app, Quick Action in Finder, two-stage quit and force-quit are owner-reported only; I did not launch the app.

Scores capped or held down for missing evidence:

- Presentation: capped at 3 for no video, scored 2 for no visible pitch at all.
- Design: held at 5 because there is no screenshot and VoiceOver and Reduce Motion are untested.
- Impact: held at 6 because the working flow is owner-reported and public access is unconfirmed.
- Technological Implementation: held at 7 for no captured hook output, no custom agents or MCP, and no vibe-coding comparison.
- Stage One: marked at risk because the repo is not reachable anonymously.
