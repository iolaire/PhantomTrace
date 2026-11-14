# PhantomTrace Hackathon Score Review

Date: 2026-11-14 (UTC). Deadline: 2026-12-04, 2:00 pm PT (22:00 UTC). About 20 days left.
Category: Resurrection. Method: strict reading of the repo. Run on this Mac (macOS, local): `swift build` (pass), `swiftlint --strict` (0 violations, 207 files), `swift test` (264 tests in 34 suites, pass; includes the local disk-image integration test). I did not launch the app or run the video; Design and Presentation rest on screenshots and file inspection.

## 1. Verdict

- Stage One: PASS on theme and Kiro use. No disqualifying defect found in the repo. Submission-form items (YouTube video, Devpost text, write-up) are not done, and the video is the one thing that can still sink the entry.
- Total: 28 / 50 today. Realistic ceiling with a good public video, accessibility pass, and write-up: about 36 to 38.
- Summary: a carefully engineered, safety-first tool with real spec, steering, hook, and property-test evidence and a coherent themed UI, but no public video, a modest "resurrection" idea, no MCP or custom agents, and untested accessibility.

## 2. Score table

| Criterion | Score | Reason |
|---|---|---|
| Potential Impact | 6 | Real, common annoyance and a working fix, but a niche audience and only owner-tested on one Mac. |
| Technological Implementation | 7 | Spec, 11 steering files, 4 hooks, power, 21+ property tests, strong safety design; no MCP, no custom agents, hook evidence is owner-reported only. |
| Design | 7 | Cohesive Platinum Retro Gothic UI shown in 8 real captures; VoiceOver and Reduce Motion unverified, a few visible rough spots. |
| Innovation/Idea | 5 | Faithful revival of "What's Keeping Me?" with a graduated, safe pipeline; the concept overlaps with existing tools and the theme is a re-skin. |
| Presentation | 3 | Capped: no public YouTube video. A 103 s local draft with placeholder machine voice exists but is gitignored and unpublished. |
| Total | 28 / 50 | |

## 3. Disqualification and blocker list (by severity)

1. No demo video on YouTube (Rules: required). Local drafts `demo/out/phantomtrace-demo.mp4` (102.8 s) and `phantomtrace-demo-alex.mp4` (96.7 s) exist, are gitignored (`demo/.gitignore: out/`), use placeholder voice, and are not uploaded. Blocker for Presentation and for submitting.
2. Devpost submission fields not done (description, test instructions, YouTube link, category/bonus, Kiro write-up). `docs/SubmissionChecklist.md` lines for these are unticked. Unverifiable from the repo.
3. "Working app" is still unticked in the checklist; only owner-reported manual pass plus a Kiro-driven pass on 2026-11-13. Judges need a build path that works from the README alone. `Scripts/make-app.sh` builds an ad-hoc signed, non-notarized app; Gatekeeper behavior on a judge's Mac is untested.
4. Low risk: the ghost mascot is described as "Kiro-inspired" (`docs/Assets.md`). It is a Gemini-generated image, with no license stated beyond an owner statement. Probably acceptable, but it is the nearest thing to a trademark/provenance question.
5. Low risk: the README's "carry-over from West of House" disclosure is present and reasonable.

Stage One A/B/C gate:

| Item | Result | Evidence |
|---|---|---|
| Real Kiro use | Pass | `.kiro/specs` (2), `.kiro/steering` (11), `.kiro/hooks` (4), `docs/ProjectLog.md` (about 113 rows with surface) |
| `.kiro` tracked, not ignored | Pass | `.gitignore` has no `.kiro`; `git ls-files .kiro` lists 25 files |
| Public repo + MIT license | Pass (partly claimed) | `LICENSE` is MIT; remote `github.com/iolaire/PhantomTrace`; public status taken from the checklist's 2026-11-13 API check, not re-verified |
| Created in Submission Period | Pass | First commit 2026-11-10; 37 commits over 2026-11-10 to 11-13; about 34.6k lines added |
| Source, assets, run steps in repo | Pass | README Build/Run; `Scripts/make-app.sh`; sprites in `Sources/PhantomTraceUI/Resources` |
| No trademarks / unlicensed assets | Pass with caveat | AI-generated art, provenance in `docs/Assets.md`; system fonts only; demo uses no music (placeholder `say` voice) |
| English only | Pass | Repo docs |
| Builds and runs | Verified here: build, lint, 264 tests pass. App launch not verified by me. | |
| Theme fit | Pass | Resurrects "What's Keeping Me?" / Put Away era tooling |
| Kiro tool fit | Pass | |

## 4. Per-criterion detail

### Potential Impact: 6
Strengths
- Real, recognizable problem: Finder's "disk wasn't ejected" dialog (`docs/screenshots/finder-eject-fails.png`).
- Goes beyond diagnosis to a staged fix with rescan after each stage (`Sources/PhantomTraceCore/Resolution/ResolutionPipeline.swift`).
- Entry points fit real habits: Finder Quick Action, drop window, CLI (`Packaging/QuickAction`, `Sources/phantomtrace`).
- Local-only, zero runtime dependencies, so it is easy to trust.

Weaknesses
- Narrow audience; `lsof` and `diskutil` already solve it for developers, and the dialog's blame is the only gap.
- Tested on one machine and one macOS build; manual QA is partial (34 ticked, 73 unticked in `docs/ManualQA.md`).
- Egress Shells appears greyed out in `docs/screenshots/phantom-trace.png` even though an idle `zsh` is listed, which suggests a non-obvious state a new user would hit. Not verified in the running app.
- "Working Dire" column truncation in the same screenshot.

Single change: a public video that shows the unpluggable-drive story end to end on a real Mac, so judges see the problem solved.

### Technological Implementation: 7
Strengths
- Spec-driven: master spec with requirements, design, tasks (`.kiro/specs/phantomtrace-volume-lock-forensics/`), and log rows that cite task and requirement numbers.
- Steering turned into enforcement: custom SwiftLint rules banning `print` in Core and networking APIs (`docs/KiroUsage.md`, `docs/ProjectLog.md`).
- Property-based tests found a real safety bug (`/private/var/vm` protected-path normalization, `ProtectedVolumeRefusalPropertyTests`); an integration test found the `0xC000 | EBUSY` status bug. Both are credible and named with regression tests.
- Engineering quality: single `SafetyPolicy` choke point, identity guard `(pid, start time)`, subprocess arrays with timeouts, protocol-mocked system effects, 264 passing tests, lint clean.
- `swift-expert` power used for a concurrency audit (D-021) with concrete fixes.

Weaknesses
- No MCP use and no custom agents. Checked `.kiro`: no `agents`, no `settings/mcp.json`. A commit message says "add MCP settings", but no such file is tracked.
- Hook evidence is owner-stated only; no captured block or lint output (`docs/KiroUsage.md` says so).
- No with/without steering comparison and no vibe-coding comparison; surface differences (IDE vs Crew vs Web) are not described, only labelled per row.
- Fixtures are generated, not real `lsof` captures (`docs/KiroUsage.md`).

Single change: add one captured hook block or lint message and a real before/after steering example to `docs/KiroUsage.md`, and state plainly that MCP and custom agents were not used (or use one).

### Design: 7
Strengths
- Distinct, coherent look: platinum chrome, gothic border, ghost state colors (red lantern while locked, green when released) in `docs/screenshots/phantom-trace.png` and `volume-released.png`.
- Full flow captured: cannot put away, trace, plan preview, banish confirm (Cancel default), released.
- Safety-aware UI copy: names pid, user, category, path; red warning on Banish Locks.
- 69 accessibility-related references in `Sources`, with `AccessibilityText.swift` carrying a reduce-motion flag.

Weaknesses
- VoiceOver and Reduce Motion are untested (`docs/ManualQA.md` lines 101, 112, 184 to 197 unticked; README says so). Cap: accessibility cannot be credited.
- Large empty areas in the Volume Released window; "Working Dire" truncation; low-contrast disabled radio and button text in `phantom-trace.png`.
- Drop window screenshot absent (`docs/SubmissionChecklist.md` known gaps).
- Ghost art is AI-generated and the Kiro likeness is intentional; originality of art is arguable.

Single change: run the VoiceOver and Reduce Motion sections of `docs/ManualQA.md`, fix what breaks, and record it.

### Innovation/Idea: 5
Strengths
- Graduated, opt-in pipeline (cd ~, quit, SIGTERM, SIGKILL, unmount) is a thoughtful design that existing tools do not offer in one place.
- Finder Quick Action plus URL scheme is a clean integration.
- Theme-to-purpose match: System 7 inspector aesthetic for a System 7 style tool.

Weaknesses
- Core mechanism is `lsof` with a UI; "What's Keeping Me?" and several Mac utilities already do the diagnosis.
- The "modern idea" is mostly safety policy and packaging, not a new technique.
- No unusual data sources or technology combination.

Single change: name one thing no existing tool does (for example, per-process safe action previews with identity guard) and make it the centre of the pitch and demo.

### Presentation: 3 (capped)
Strengths
- Remotion kit with `scenes.json`, five real recorded clips, and a 97 to 103 s draft (`demo/`), well under three minutes.
- Clear written pitch in README and `docs/ProjectOverview.md`; honest status section.
- Demo is reproducible (`Scripts/demo/setup-demo.sh`).

Weaknesses
- No YouTube video; cap applies. Draft uses placeholder `say` voice and is not committed.
- `docs/demo-script.md` is a plan only.
- Kiro cutaway is planned, not shown.
- No Devpost text exists in the repo.

Single change: record the voice-over, render, and upload the video as public today, then link it in the README and checklist.

## 5. Submission completeness

| Item | Status |
|---|---|
| Text description | Missing (draft source exists: `docs/ProjectOverview.md`) |
| Working-app URL and test instructions | Partial: GitHub URL plus README Build/Run; no release or prebuilt app |
| YouTube link | Missing |
| GitHub URL | Done (`https://github.com/iolaire/PhantomTrace`) |
| Category and bonus selections | Unverifiable (form not filled) |
| Kiro write-up: IDE/CLI/Web/Crew differences | Weak: surfaces labelled per row, differences not written |
| Kiro write-up: custom agents | Not used |
| Kiro write-up: hooks | Partial: 4 hooks, owner-reported, no captured output |
| Kiro write-up: specs vs vibe coding | Partial: spec evidence yes, comparison no |
| Kiro write-up: steering | Done with some evidence (lint rules, test rules) |
| Kiro write-up: MCP | Not used |
| Kiro write-up: property-based testing | Done, with one real bug |
| Kiro write-up: powers | Done: `swift-expert`, two logged uses |

## 6. Bonus prizes

| Prize | Readiness | Notes |
|---|---|---|
| Best Demo | Not started | Needs top 10% overall and top Presentation; unlikely without a polished voiced video |
| Bonus Blog Prize | Not started | No post exists; must be public third-party and mention Kiroween 2026 |
| Social Blitz | Not started | Post must start with `#KiroweenHackathon26`; link needed |
| Best Ghost of Kiroween Past | Possibly relevant | Owner says they entered 2025 (West of House); must be confirmed on the form |
| Best Kiro Crew App | Not relevant | The app is not a Crew app; Crew was only used for demo-kit work |
| Best Startup / Best Student | Not relevant | No evidence |

## 7. Prioritized action plan (20 days left)

| # | Action | Gain | Hours | Criterion |
|---|---|---|---|---|
| 1 | Record own voice-over, render, upload public to YouTube, link in README/checklist | +3 to +4 | 2 to 3 | Presentation |
| 2 | Post `#KiroweenHackathon26` social post, add link | Bonus eligibility | 0.5 | Bonus |
| 3 | Capture one hook block/lint message and one steering before/after in `docs/KiroUsage.md`; state plainly MCP and custom agents were not used | +0.5 to +1 | 1 | Tech |
| 4 | Finish Devpost text and Kiro write-up from `docs/KiroUsage.md`; tick checklist | Required | 1.5 | Submission |
| 5 | Run VoiceOver and Reduce Motion QA, fix issues, record in `docs/ManualQA.md` | +0.5 to +1 | 2 | Design |
| 6 | Add a 10 s Kiro cutaway (specs, steering, hooks, passing property tests) to the video | +0.5 | 1 | Presentation, Tech |
| 7 | Try a fresh clone on a second Mac or user account; follow README only; fix gaps (Gatekeeper, Quick Action enable) | Risk reduction | 2 | Impact |
| 8 | Add a small custom agent or MCP server only if it does real work; otherwise skip | +0.5 | 3 to 4 | Tech |
| 9 | Publish a blog post (third-party) mentioning Kiroween 2026 | Bonus eligibility | 2 | Bonus |
| 10 | Retake drop-window screenshot with only the demo image mounted; fix "Working Dire" truncation | +0.3 | 1 | Design |

Submit by 2026-12-03 to leave a day of slack; no edits after the deadline.

## 8. Honesty check

Claims the code or repo does not fully support:
- `README.md` "Built with Kiro" says parser fuzz tests cover `lsof`/`fuser` output. `LockDiscoveryEngine.swift` runs `fuser -c` as a cross-check, but I found no fuser parser. Property tests target the `lsof` parser. Overstated for fuser.
- Commit `1ad77c7` message says "add MCP settings", but no MCP config is tracked and `docs/KiroUsage.md` MCP is empty. Mismatch.
- `docs/SubmissionChecklist.md` cites "259 tests"; the run here shows 264. Out of date, not harmful.
- Hooks "were active during the build" is owner-reported only; no hook output is in the repo.
- `docs/ManualQA.md` pass record is owner-reported for 2026-11-12; individual steps are not ticked (34 of 107 boxes).
- README says the Quick Action "has since been installed and seen in Finder" (owner-reported); I did not verify.
- GitHub public status and MIT detection come from the checklist's 2026-11-13 API check; not re-verified here.
- Art provenance, "no license needed", and "ghost distinct from Kiro" are owner statements (`docs/Assets.md`).

Scores capped for missing evidence:
- Presentation capped at 3: no public video.
- Design held at 7: accessibility untested, app not launched by me.
- Technological Implementation held at 7: no MCP, no custom agents, no captured hook evidence.
- Impact held at 6: single-machine, partial manual QA.
