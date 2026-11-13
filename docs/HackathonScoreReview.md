# Kiroween 2026 Score Review: PhantomTrace (Resurrection)

Date: 2026-11-13 (UTC). Days left until December 4, 2026, 2:00 pm PT (22:00 UTC): 21.

Method: read the Rules, README, checklist, KiroUsage, demo script, specs, steering, hooks, git history, and two screenshots. Commands run on this Mac (Darwin arm64, macOS 27.2.1): `swift build` (passed), `swiftlint --strict` (0 violations in 205 files), `swift test` (259 tests in 33 suites passed, including `DiskImageIntegrationTests` on its own temp image). I did not launch the app and did not signal any process or unmount any volume. GitHub was checked with unauthenticated requests.

## 1. Verdict

**Stage One: AT RISK.** `https://github.com/iolaire/PhantomTrace` and the GitHub API both return HTTP 404 without authentication, although `origin/main` is up to date locally. A private repo breaks a hard rule. Theme fit and Kiro use would otherwise pass.

**Score: 27 / 50.** Strong engineering and a real Kiro process trail. A judge cannot see it yet: no video, a repo that is not publicly reachable, and screenshots that are not committed.

## 2. Score table

| Criterion | Score | Reason |
|---|---|---|
| Potential Impact | 6 | Real, common annoyance and a safe fix path, but the audience is narrow and only the owner has run it. |
| Technological Implementation | 7 | Specs, 11 steering files, 4 hooks, 22 property suites, and a good safety design. Hook, MCP, and agent evidence is missing. |
| Design | 6 | Cohesive Platinum Retro Gothic UI shown in screenshots. VoiceOver and Reduce Motion are untested, and some controls look unfinished. |
| Innovation/Idea | 5 | A faithful resurrection of "What's Keeping Me?" with a graduated, safe pipeline. Not a new concept. |
| Presentation | 3 | No video (cap 3). The written pitch is clear, and the plan is only a plan. |
| **Total** | **27 / 50** | |

## 3. Disqualification and blocker list (most severe first)

1. **Repo not publicly reachable.** Both `https://github.com/iolaire/PhantomTrace` and the API URL return 404 unauthenticated. The Rules require a public GitHub repo. Fix: make it public, then confirm the About panel shows "MIT License".
2. **No demo video.** It is required for submission, and `README.md` and `docs/demo-script.md` both say it does not exist. A missing video is an incomplete submission.
3. **Uncommitted work.** `git status` shows `docs/screenshots/*` (8 PNGs) and `docs/CliCapture.md` untracked, and README, checklist, and log edits unstaged. The README links to screenshots that a judge cloning `main` would not see. Commit and push them.
4. **Checklist hard-requirement boxes are unticked.** Several are factually done: `LICENSE` is MIT, the repo holds source, and history starts inside the period. Judges may read the file as it stands.
5. **"Kiro-inspired" ghost mascot.** `docs/Assets.md` says the ghost is Kiro-inspired and was checked as distinct. It is a small trademark-adjacent risk. The AI-generated art is disclosed, which is good, but its licensing rests on the owner's statement and not on a verified license.
6. Not blockers: the first commit is 2026-11-10 (inside the Submission Period), `.gitignore` has no `.kiro` entry, `git ls-files .kiro` lists hooks, specs, steering, and a prompt, and the README discloses the carried-over West of House prompt style.

## 4. Per-criterion detail

### Stage One gate

- A, Kiro use: pass. `.kiro/specs` (2 specs; master `tasks.md` has 125 checked tasks and no open ones), `.kiro/steering` (11), `.kiro/hooks` (4).
- A, `.kiro` tracked and not ignored: pass.
- A, public repo: **fail / unverifiable** (404).
- A, license: `LICENSE` is MIT. GitHub detection cannot be checked while the repo is private.
- A, created in period: pass. 27 commits, 2026-11-10 to 2026-11-12, with PRs #1 to #4.
- A, assets and English: pass, with the Gemini art caveat in section 3.
- B, build, test, lint: `swift build` passed, `swift test` passed (259), `swiftlint --strict` clean. All three were run today.
- B, install from README alone: not verified by me. The README documents `Scripts/make-app.sh`. The owner reports a manual pass, but `docs/ManualQA.md` is not filled in.
- C, theme fit: pass. Reviving a "What's Keeping Me?"-style inspector is a plausible Resurrection entry.
- C, Kiro fit: pass.

### 1. Potential Impact: 6

Strengths:
- A real, widely felt problem: Finder's unhelpful eject dialog. `docs/screenshots/finder-eject-fails.png` shows it.
- Inform first, act second. Every action is opt-in and previewed (`.kiro/steering/safety.md`, `docs/screenshots/plan-preview.png`).
- Entry points fit the problem: a Finder Quick Action, a drop window, and a read-only CLI (`Sources/phantomtrace`).
- The lock list is clear: name, PID, user, category, and path (`phantom-trace.png`).

Weaknesses:
- Only macOS 27.2.1 is supported, with no release download. The build needs Command Line Tools and an ad-hoc signed bundle (`Scripts/make-app.sh`). The Quick Action must be enabled by hand.
- Only the owner has run it. `docs/ManualQA.md` is empty, and the README says the pass is "owner-reported".
- Tools like `lsof` and Activity Monitor already cover the technical user. The non-technical user is the stated audience, and there is no evidence one has tried it.
- The `ResolutionPipeline` gaps listed in `docs/architecture.md` (daemon confirmation, manual egress outcomes) are open.

Biggest lift: record a clean end-to-end video and fill in the ManualQA pass record (about +1).

### 2. Technological Implementation: 7

Strengths:
- Spec-driven: `.kiro/specs/phantomtrace-volume-lock-forensics` (431 lines of requirements, a design, a 482-line task list), with log rows citing requirement numbers. Provisional behavior is labelled `// PROVISIONAL (Req 18.x)`.
- Property-based testing with real findings: the `/private/var/vm` bug (`ProtectedVolumeRefusalPropertyTests`, regression in `MountResolverProtectionTests`). The `0xC000 | EBUSY` bug found by the integration test is honestly attributed to the integration test, not a property test. 22 property suites exist in `Tests/PhantomTracePropertyTests`.
- Safety architecture: a single `SafetyPolicy` choke point, identity guard on `(pid, start time)`, argument-array subprocesses, and a total `LsofParser`. Network and `print` bans are enforced by custom lint rules. Hand-written mocks.
- Process trail: `docs/ProjectLog.md` has one row per change, with a Kiro surface of IDE (105), Web (16), CLI (3), and Crew (1). The `swift-expert` power was used in a concurrency audit (D-021), and the fixes have tests (`ResolutionPipelineCancellationTests`).

Weaknesses:
- No hook evidence. `KiroUsage.md` admits no hook output was captured and no hook catch is claimed. Hook activity is owner-reported only.
- No custom agents and no MCP in the repo. `.kiro/settings` is absent, and the `mcp.json` is in the user home directory, not the repo. The write-up has "record any created" placeholders.
- No with/without steering comparison and no spec vs vibe-coding comparison. The surface comparison is missing as well. The Rules ask for these explicitly.
- The parser fixtures are generated, not captured from real `lsof` (stated in `KiroUsage.md`). The history is short (3 days, 27 commits, many large mixed commits such as `c441700`), which is thin "steady commit" evidence.

Biggest lift: add real evidence to `KiroUsage.md`: a captured hook block or lint message, a with/without steering example, and a short Web/IDE/CLI comparison (about +1).

### 3. Design: 6

Strengths:
- The screenshots show a cohesive Platinum look: a pinstripe title bar, a skull-and-chain frame, a CRT illustration, and a ghost mascot (`docs/screenshots/phantom-trace.png`, `banish-confirm.png`).
- Calm, specific copy: "Beware: this force-stops programs. Unsaved changes to open files may be lost forever." The banish dialog names the process and PID, with Cancel as the default.
- 60 accessibility label or setter references in `Sources` and an `AccessibilityText` module with tests.
- A coherent three-window flow with a drop target and a volume list.

Weaknesses:
- VoiceOver and Reduce Motion are untested (README). `ReduceMotion` appears once in `Sources`, which is thin support.
- Visible rough edges in the screenshots: the "Lock Category" column shows "Working Dire" (truncated). In the banish dialog the system-blue Cancel button clashes with the platinum theme, and the radio buttons and Proceed look faded.
- The copy is theme-heavy ("Proceed, if you dare", "Retreat to the Shadows"), which can obscure what a button does. This works against the product principle in `product.md`.
- The drop-window screenshot was dropped, and the drop target path is untested.

Biggest lift: fix the clipped column and the off-theme default button, add a drop-window screenshot, and run VoiceOver and Reduce Motion once (about +1).

### 4. Innovation/Idea: 5

Strengths:
- The Resurrection framing is clear and credible: a classic single-purpose inspector brought to modern macOS.
- The four-stage graduated pipeline (Egress Shells, Graceful, Banish, Clean Handoff) with a rescan after each stage is more careful than `lsof | kill`.
- Egress Shells (`cd ~` into idle terminals instead of killing them) is a thoughtful, uncommon touch.
- It maps to DiskArbitration busy codes and `.dmg` attachments, and it has a read-only CLI.

Weaknesses:
- The core capability (find who holds a volume) is what `lsof` and several existing utilities already do. A dedicated GUI is the novelty.
- Egress Shells needs Automation permission, and the demo may fall back to manual instructions.
- No unusual data or tools are combined. The Kiro ghost reference adds nothing technical.

Biggest lift: demo Egress Shells working live on screen. It is the one clearly differentiated feature (about +1).

### 5. Presentation: 3 (cap applied)

Strengths:
- A clear written pitch (problem, audience, how it works) in `README.md`.
- A paced 170-second plan in `docs/demo-script.md`, with a Kiro cutaway and fallbacks.
- Seven annotated screenshots that tell the flow story.

Weaknesses:
- No video, so the score is capped at 3.
- The README has a long status section full of "not verified" notes, which reads as an unfinished project to a skim reader.
- The Devpost description and the Kiro write-up are drafts only.
- The README leads with the mechanism and has no one-line hero image.

Biggest lift: record and publish the YouTube video (under 3 minutes, on a Mac) and put its link at the top of the README (about +3 to +4).

## 5. Submission completeness

| Item | Status |
|---|---|
| Text description | Draft only (`docs/ProjectOverview.md`, README). Devpost form unverifiable. |
| Working app URL and test instructions | Instructions are in the README. No release or URL. Repo is not publicly reachable. |
| YouTube link | Missing. |
| GitHub URL | Exists but returns 404 unauthenticated. |
| Category and bonus selections | Planned in the checklist. Unverifiable on Devpost. |
| Kiro write-up: IDE/CLI/Web/Crew differences | Partly. Surfaces are logged but "how they differed" is not written. |
| Kiro write-up: custom agents | Not used. Say so. |
| Kiro write-up: hooks | Four hooks exist. Owner says they ran. No captured output. |
| Kiro write-up: specs vs vibe coding | Spec evidence present. No comparison. |
| Kiro write-up: steering | 11 files, with log-based evidence. No with/without example. |
| Kiro write-up: MCP | Not used in the repo. Say so. |
| Kiro write-up: property-based testing | Done, with one real bug. |
| Kiro write-up: powers | `swift-expert` used, two logged uses. |

## 6. Bonus prizes

| Prize | Readiness | Note |
|---|---|---|
| Best Demo | Not started | Needs a video, a top-10% overall score, and the top Presentation score. Not realistic at 27/50. |
| Bonus Blog Prize | Not started | No post exists. Needs a public third-party post that mentions Kiroween 2026. It is the cheapest prize to win. |
| Social Blitz | Not started | No post exists. It must start with `#KiroweenHackathon26`. |
| Best Ghost of Kiroween Past | Partly relevant | The README mentions a 2025 entry (West of House). Confirm it was registered for Kiroween 2025 and tick it on the form. The 2026 project is newly created. |
| Best Kiro Crew App | Not relevant | There is no separate Crew app repo. |
| Best Startup, Best Student | Not relevant | No evidence of either. |

## 7. Prioritized action plan (deadline Dec 4, 2:00 pm PT, 21 days left)

| # | Action | Gain | Effort (h) | Criterion |
|---|---|---|---|---|
| 1 | Make the repo public, confirm MIT shows in About, commit and push the screenshots and docs. | Removes the Stage One risk | 0.5 | Gate, Design |
| 2 | Record the under-3-minute demo (setup in `demo-script.md`), upload as public on YouTube, link it atop the README. | +3 to +4 | 3 | Presentation |
| 3 | Fill in `docs/ManualQA.md` and tick the checklist boxes that are true. | +0.5 | 1 | Impact, Presentation |
| 4 | Write a Bonus Blog post (mention Kiroween 2026) and a `#KiroweenHackathon26` post. | Two prizes | 2 | Bonus |
| 5 | Add real Kiro evidence: a captured hook block, a steering with/without example, a surface comparison, and plain "not used" lines for agents and MCP. | +1 | 2 | Technological Implementation |
| 6 | Fix the clipped column and the Cancel button style, retake the drop-window screenshot, run VoiceOver and Reduce Motion once. | +1 | 3 | Design |
| 7 | Cut the README status section to a short "Verified / Not verified" table. | +0.5 | 0.5 | Presentation |
| 8 | Capture a real `lsof -F` fixture from the throwaway image. | +0.3 | 1 | Technological Implementation |
| 9 | Draft and save the Devpost text and the Kiro write-up before Dec 3. | Needed for completeness | 1.5 | Submission |

## 8. Honesty check

Claims not supported by the code or artifacts:
- `README.md` says screenshots were captured and linked. They are untracked, so they are not in the repo.
- `README.md` says the Quick Action "has since been installed and seen in Finder". The sentence says the installer test passes, "but it has since been installed", which reads as contradictory. The evidence is owner-reported only.
- `README.md` "Built with Kiro" says "fuzz tests of the `lsof`/`fuser` output parser". Fixtures are generated and `fuser` is not covered in the tests I read, so "fuzz" is overstated.
- `docs/SubmissionChecklist.md` still lists "Hooks exist ... owner states they were active". No output was captured, so I give no credit beyond the existence of the files.
- `docs/KiroUsage.md` opens with "This document is the draft ... fill each Evidence line". It is still in draft wording.
- `docs/KiroUsage.md` "Property tests exist for the spec's properties" lists about 21 properties. I counted 22 suites, which is consistent, and did not check each against the spec.
- The ManualQA pass record is empty, so the claim of a full manual pass rests on the owner's statement.
- `docs/Assets.md` provenance (Gemini model, date, license) is the owner's statement and unverifiable.

Scores capped or discounted for missing evidence:
- Presentation capped at 3 (no video).
- Design held at 6 (VoiceOver and Reduce Motion untested, visible UI rough edges). The "never launched" cap does not apply because screenshots exist, though I did not launch the app myself.
- Technological Implementation held at 7 (no hook capture, no MCP, no custom agents, no with/without steering evidence).
- Potential Impact held at 6 (no third-party user or test evidence).
- I did not run the app or `make-app.sh`, so install-from-README is not verified by me.
