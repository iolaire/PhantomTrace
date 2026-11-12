# Kiroween 2026 Score Review: PhantomTrace (Resurrection)

Date: 2026-11-12. Days left until December 4, 2026, 2:00 pm PT: 22.

Method: independent re-score from the repository. Owner statements in the docs (manual QA pass, asset provenance) are treated as unverified. Commands run on this Mac: `swift build`, `swift test`, `swiftlint --strict`, `git log`, and two unauthenticated GET requests to github.com.

## 1. Verdict

**Stage One: AT RISK (likely fail as things stand).** The GitHub repository returns 404 to an unauthenticated request, so it is private or not reachable. A public repo is a hard rule. Everything else in Stage One passes.

**Score: 25 / 50.** Strong engineering and Kiro process evidence, but nothing a judge can see: no video, no screenshots, no public repo, no release build.

One line: a well-engineered, safety-minded tool whose submission artifacts (public repo, video, screenshots, Kiro write-up) do not exist yet.

## 2. Score table

| Criterion | Score | Reason |
|---|---|---|
| Potential Impact | 6 | Real, relatable problem; but only macOS 27.2.1 is supported, nothing is demonstrated publicly, and the working flow is owner-reported only. |
| Technological Implementation | 7 | Real specs, 11 steering files, 4 hooks, 24 property test files at 500 iterations, two documented bugs. No custom agents, MCP use, or powers evidenced; hooks unconfirmed live. |
| Design | 5 | Coherent Platinum look, 15 sprite files, icon, custom dialogs, accessibility labels in code. No screenshot exists; VoiceOver and Reduce Motion untested. |
| Innovation/Idea | 5 | Good Resurrection framing and a graduated, opt-in pipeline. The core function (find what holds a volume open) is what `lsof` and "What's Keeping Me?" already do. |
| Presentation | 2 | No video (cap 3). Written pitch in README is clear but has no images. |
| **Total** | **25 / 50** | |

## 3. Disqualification and blocker list (most severe first)

1. **Repo not publicly reachable.** `curl https://github.com/iolaire/PhantomTrace` returned 404, and `api.github.com/repos/iolaire/PhantomTrace` returned "Not Found". Remote is `origin https://github.com/iolaire/PhantomTrace.git`. Either the repo is private or the name is wrong. The Rules require a public repo with a detectable license. License detection is therefore also unverified (`LICENSE` is MIT at the root).
2. **No demo video.** No YouTube link anywhere in the repo. Presentation capped at 3 (scored 2); Best Demo impossible.
3. **No screenshots.** `docs/screenshots/` holds only `.gitkeep`. The README says so itself.
4. **Judges likely cannot run it.** Support is macOS 27.2.1 only; there is no prebuilt release, the app is ad-hoc signed and not notarized, and it needs a local `swift build` plus `Scripts/make-app.sh`. A judge on any other macOS version cannot test it, so the video carries all the weight.
5. **Kiro write-up is a draft.** `docs/KiroUsage.md` still has "Evidence to add" lines and "record any" placeholders for custom agents, MCP, and powers.
6. **Manual QA unrecorded.** `docs/ManualQA.md` has 0 ticked and 107 unticked boxes. The working-app claim rests on one owner statement.
7. **Weak history evidence.** Commit `c441700` adds 235 files and 18,043 lines at once. 23 commits over three days (Nov 10 to 12). The first commit is 2026-11-10, inside the Submission Period, so that gate passes.

## 4. Stage One detail

**A. Disqualification risks**

| Item | Result | Evidence |
|---|---|---|
| Real Kiro use | Pass | 2 specs (2,683 lines), 11 steering files, 4 hooks, 1 prompt in `.kiro/`; `docs/ProjectLog.md` names a surface on each row (93 Kiro IDE, 5 Kiro Web). |
| `.kiro` tracked, not in `.gitignore` | Pass | `git ls-files .kiro` lists 26 files; `.gitignore` entries are `.build/`, `.swiftpm/`, `*.xcodeproj/xcuserdata/`, `DerivedData/`, `.DS_Store`, `.venv/`, `__pycache__/`, `build/`. |
| Public GitHub repo, MIT license detectable | **Fail / unverified** | 404 on unauthenticated requests (see blocker 1). `LICENSE` exists, MIT, "Copyright (c) 2026 iolaire mcfadden". |
| Built in Submission Period | Pass | First commit `b311c6c` 2026-11-10. README discloses no pre-existing code, and discloses the reused 2025 image-prompt style. |
| Source, assets, run instructions in repo | Pass (with caveat) | README Build/Run sections; sprites in `Sources/PhantomTraceUI/Resources/Sprites/`. Caveat: the README's "Run" needs several manual steps and Quick Action enabling. |
| No third-party trademarks or unlicensed assets | Pass with risk | `docs/Assets.md`: AI-generated (Gemini) art, system fonts only. The "Kiro-inspired" ghost is owner-checked only; I could not compare it with Kiro art. Terms statements are owner-supplied. |
| English | Pass | All docs are in English. |

**B. Functionality**

| Item | Result |
|---|---|
| `swift build` | Pass (ran; linker warnings about missing CLT search paths only). |
| `swift test` | Pass (ran; 111 + 90 + 255 tests, 0 failures; includes the local disk-image integration test, which uses its own temporary image). |
| `swiftlint --strict` | Pass with `DYLD_FRAMEWORK_PATH=/Library/Developer/CommandLineTools/usr/lib` (0 violations in 204 files). Bare `swiftlint` does not run on this machine, as the README admits. |
| Runs per README on macOS 27.2.1 | Not verified by me. I did not launch the GUI or attach the Quick Action. Owner reports a pass on 2026-11-12. |

**C. Theme and tools fit**

- Resurrection: reasonable fit (modern take on System 7 / "What's Keeping Me?" style tools). Pass.
- Kiro use: reasonable and real. Pass.

## 5. Per-criterion detail

### Potential Impact: 6

Strengths
- Real, common pain: Finder's unhelpful eject error (`README.md`, `docs/ProjectOverview.md`).
- Output names process, pid, user, and file; opt-in, least-destructive-first pipeline (`Sources/PhantomTraceCore/Resolution/`).
- Safety rules enforced in one place: `SafetyPolicy`, protected volumes, identity guard (`.kiro/steering/safety.md`, `Tests/PhantomTracePropertyTests/SafetyPolicy*`).
- Read-only CLI exists for scripting (`Sources/phantomtrace/main.swift`).

Weaknesses
- Supports one macOS build only (`.kiro/steering/product.md`); a judge cannot run it on another version.
- No public demonstration; the end-to-end flow is documented only by an owner statement (`docs/ManualQA.md` has no ticked boxes).
- Needs Quick Action enabling in System Settings before it appears (README, "Finder Quick Action"); this is friction for the stated non-technical audience.
- VoiceOver untested, so accessibility is unproven (README Status).

Single change with most gain: publish a short, public video of the real flow, so the impact is visible.

### Technological Implementation: 7

Strengths
- Spec-driven: master spec (design 1,272 lines, requirements 431, tasks 482, 125 tasks ticked, 0 open) and a scaffolding spec; log rows cite task and requirement numbers.
- Steering is specific and enforceable: 11 files, with the layering and safety rules reflected in code (Core has no AppKit; `PhantomTraceUI` is separate).
- Property-based testing with a real payoff: `ProtectedVolumeRefusalPropertyTests` found `/private/var/vm` being rewritten by `standardizedFileURL` (`docs/KiroUsage.md`). 24 property test files, 23 with 500 iterations set.
- Honest evidence that mocks hid a bug: `0xC000 | EBUSY` found by `DiskImageIntegrationTests` (`LiveUnmounter.swift`).

Weaknesses
- No custom agents (no `.kiro/agents`), no project-level MCP use (`.kiro/settings` is not tracked; only user-level servers exist, none shown to be used), no powers beyond one passing log mention of swift-expert.
- Hooks are not confirmed live (`docs/SubmissionChecklist.md`, Known gaps). All three commit hooks match `execute_bash` and only see agent-run commits.
- No comparison with vibe coding and no IDE/CLI/Web differences written (`docs/KiroUsage.md`).
- `Tests/Fixtures` are tiny (56 to 190 bytes) and generated, not captured from `lsof`, while `testing.md` says "real captured" output.

Single change with most gain: finish `docs/KiroUsage.md` with real evidence (a steering rule that changed output, what a hook caught, specs vs vibe coding) and say plainly what was not used.

### Design: 5

Strengths
- Consistent look: nine-part window chrome, close box, choice controls, dialogs (`Sources/PhantomTraceUI/`).
- 7 sprites at 1x and 2x, app icon (`Packaging/AppIcon.icns`), with provenance in `docs/Assets.md`.
- Accessibility text and labels exist in code (`AccessibilityText.swift`); copy is specific (`StageMessages.swift`).
- Three-window flow with forward and back (README Status, owner-reported).

Weaknesses
- No screenshot in the repo (`docs/screenshots/` empty). The UI cannot be evaluated by a judge who does not run it.
- VoiceOver and Reduce Motion are untested (README Status).
- Sprites and icon are "not yet seen in a running app" per `docs/Assets.md`, which conflicts with the later owner report.
- The look is AI-generated art with a fixed system-font fallback; Chicago/Monaco typography claimed in the README is not bundled and not confirmed.

Single change: capture and commit screenshots of the three states (haunted, plan preview, released) and put them in the README.

### Innovation/Idea: 5

Strengths
- Clear Resurrection angle with period-accurate chrome (`docs/ProjectOverview.md`).
- Graduated stages (Egress Shells, Graceful Request, Banish Locks, Clean Handoff) with fresh rescans, rather than just a process list.
- Finder Quick Action entry point (`Packaging/QuickAction/`).

Weaknesses
- Core detection is a wrapper around `lsof`; no new detection technique.
- Overlaps with Activity Monitor, `lsof`, and the macOS "Force Quit/Eject" tools; the repo does not compare against them.
- The ghost mascot and retro frame are presentation, not new capability.

Single change: show one case that existing tools cannot handle (for example the two-stage `agy` then `zsh` release) clearly in the video and README.

### Presentation: 2

Strengths
- README states problem, audience, and flow clearly.
- `docs/demo-script.md` is a sound 170-second plan.

Weaknesses
- No video exists (cap 3). The script is a plan only.
- No screenshots in README or docs.
- No Devpost text, blog, or social post found (`grep` for YouTube, Medium, dev.to, `#KiroweenHackathon26` found nothing outside the rules and prompt files).

Single change: record and publish the video on YouTube.

## 6. Submission completeness

| Item | Status |
|---|---|
| Text description | Partial: README and `docs/ProjectOverview.md` can be reused; no Devpost text drafted. |
| Working-app URL and test instructions | Missing/unverifiable: repo not publicly reachable; build instructions exist; no release binary. |
| YouTube link | Missing. |
| GitHub URL | Unverifiable: returns 404 publicly. |
| Category and bonus selections | Done in docs (Resurrection; Best Demo, Blog, Social Blitz planned), not yet entered. |
| Kiro write-up | Partial draft in `docs/KiroUsage.md`. |

Kiro write-up coverage:

| Area | Status |
|---|---|
| IDE / CLI / Web / Crew | IDE (93 rows) and Web (5 rows) used; CLI, Crew not used; differences not written. |
| Custom agents | Not used. |
| Hooks | 4 written; not confirmed live; no "caught" evidence. |
| Specs vs vibe coding | Specs used; comparison missing. |
| Steering | 11 files; "biggest impact" evidence missing. |
| MCP | Not used for the project (no evidence). |
| Property-based testing | Used; one real bug documented. |
| Powers | Not meaningfully used (one log mention of swift-expert). |

## 7. Bonus prizes

| Prize | Readiness | Notes |
|---|---|---|
| Best Demo | Not started | Needs the video, plus top 10% overall and top Presentation. Not reachable at the current score. |
| Bonus Blog Prize | Not started | No post exists. Must be third-party, published by Dec 4, and mention Kiroween 2026. Cheapest bonus to win. |
| Social Blitz | Not started | No post exists. Must start with `#KiroweenHackathon26`. |
| Best Ghost of Kiroween Past | Possibly relevant | README mentions a 2025 entry (West of House). Rules require 2025 registration and a new project; the registration is not documented. |
| Best Kiro Crew App, Best Startup, Best Student | Not relevant | No Crew app, startup, or student details found. |

## 8. Prioritized action plan (22 days left)

Ordered by gain per hour, blockers first.

| # | Action | Gain | Hours | Criterion |
|---|---|---|---|---|
| 1 | Make the GitHub repo public and confirm the license shows in About (check in a logged-out browser) | Avoids disqualification | 0.25 | Stage One |
| 2 | Capture 4 to 6 screenshots, commit to `docs/screenshots/`, embed in README | +1.5 | 1 | Design, Presentation |
| 3 | Record, edit, and upload the under-3-minute video (public on YouTube), following `docs/demo-script.md` | +4 to +5 | 4 | Presentation, Impact |
| 4 | Finish `docs/KiroUsage.md`: real evidence, specs vs vibe coding, plain "not used" for agents, MCP, powers | +1 | 2 | Technological Implementation |
| 5 | Publish a blog post (third-party site) that mentions Kiroween 2026; post `#KiroweenHackathon26` social post | Two bonus prizes | 2 | Bonus |
| 6 | Run `docs/ManualQA.md`, tick boxes, test VoiceOver and Reduce Motion | +1 | 3 | Design, Impact |
| 7 | Use Kiro features not yet used with a real purpose (a custom agent, a project MCP server, hooks confirmed live) and log the result | +1 | 4 | Technological Implementation |
| 8 | Add a GitHub release with a signed (ideally notarized) app zip so judges can run it without building | +0.5 to +1 | 3 | Impact |
| 9 | Replace generated fixtures with captured `lsof -F` output, or correct `testing.md` | +0.25 | 1 | Technological Implementation |
| 10 | Draft the Devpost text and test instructions | Needed for submission | 1 | Presentation |

## 9. Honesty check

Claims the repo does not support, or only partly supports:

- `docs/SubmissionChecklist.md` and `docs/HackathonScoreReview.md` (previous version) assumed a public repo; the public URL returns 404.
- `README.md` "Built with Kiro" lists agent hooks as enforcing lint and tests; `docs/SubmissionChecklist.md` says they are not confirmed live in Kiro.
- `README.md` "Manual end-to-end pass" is owner-reported; `docs/ManualQA.md` has 0 of 107 boxes ticked.
- `docs/Assets.md` says sprites and icon are "not yet seen in a running app" and "not yet seen in Finder/Dock"; the README says the full window flow was used. The two are out of date relative to each other.
- `.kiro/steering/testing.md` says fixtures are "real captured `lsof -F` output"; `docs/KiroUsage.md` says they are generated. The files are 56 to 190 bytes.
- `README.md` describes Monaco/Chicago typography in the visual direction; `docs/Assets.md` says no font is bundled and Chicago is not used (system font fallback).
- `README.md` mentions `fuser` fuzzing under property-based testing; `fuser` use was not verified by me.
- `docs/ProjectLog.md` rows with "not verified" status vs README "Verified" claims: I confirmed build, tests, and lint myself; I did not confirm GUI claims.

Scores capped or reduced for missing or unverifiable evidence:

- Presentation capped at 3 (scored 2): no video.
- Design held at 5: no screenshots; GUI not launched by me.
- Impact held at 6: working flow not independently verified; narrow platform.
- Technological Implementation held at 7: no evidence for custom agents, MCP, powers, live hooks, or tool-surface comparisons.
- Stage One public-repo item marked fail/unverified because of the 404.
