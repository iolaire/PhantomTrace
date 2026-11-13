# PhantomTrace Hackathon Score Review

Date: 2026-11-13 (UTC). Deadline: 2026-12-04, 2:00 pm PT, about 21 days left.
Category: Resurrection. Method: strict reading of the repo only. Checked on this Mac: `swift build` (pass), `swiftlint --strict` (0 violations in 205 files), `swift test --skip DiskImageIntegration` (258 tests, 32 suites, pass). The disk-image integration test was not run, because it attaches a real image. The app was not launched by me. Screenshots were read directly.

## 1. Verdict

- Stage One: PASS on theme and Kiro use. No disqualifying defect found in the repo. Submission-form blockers remain (no video, no write-up submitted).
- Total: 29 / 50 today (about 36 to 38 with a good video, accessibility pass, and write-up).
- Summary: a well-engineered, safety-minded, nicely themed tool with strong spec/test evidence, but no demo video, no Kiro MCP/custom-agent use, and unfilled accessibility and manual QA records.

## 2. Score table

| Criterion | Score | Reason |
|---|---|---|
| Potential Impact | 7 | Real, common pain (Finder eject error); screenshots show the lock list working on a throwaway image. |
| Technological Implementation | 7 | Spec, 11 steering files, 4 hooks, 25 property test files, one power, real bugs found; no MCP or custom agents, hook evidence owner-reported only. |
| Design | 6 | Distinct, polished Platinum Gothic UI captured in 8 screenshots; VoiceOver and Reduce Motion untested, a few rough spots. |
| Innovation/Idea | 6 | Good resurrection of "What's Keeping Me?" with a guided, safety-gated pipeline; the core idea (lsof plus kill) is not new. |
| Presentation | 3 (capped) | No video exists. README is detailed but long and caveat-heavy. |
| Total | 29 | Sum of the five scores. |

## 3. Disqualification and blocker list (most severe first)

1. No demo video (required submission item; Presentation capped at 3). Evidence: `docs/SubmissionChecklist.md` lines for video unchecked; `docs/demo-script.md` says "has not been recorded".
2. Insufficient-use-of-Kiro risk: low, but the write-up admits no MCP, no custom agents, and no captured hook output (`docs/KiroUsage.md`). Not a blocker, a score limit.
3. Working-app item is unticked: owner-reported manual pass only; `docs/ManualQA.md` boxes unfilled. Judges following the README need `Scripts/make-app.sh`, ad-hoc signed; Gatekeeper behavior on a downloaded copy is not documented. Not verified by me.
4. Ghost mascot resembles Kiro's own ghost (purple aura, friendly white ghost, `docs/screenshots/phantom-trace.png`). Docs claim it is distinct. Low trademark risk because Kiro is the sponsor tool, but worth a sentence. AI-generated art is disclosed in `docs/Assets.md`.
5. Pre-existing work: the 2025 prompt style carry-over is disclosed in the README. Acceptable.

Passed gate items: `.kiro` tracked (`git ls-files .kiro` lists hooks, specs, steering, prompts) and not in `.gitignore`; `LICENSE` is MIT at root; remote is a GitHub repo `iolaire/PhantomTrace` (public status not re-checked by me; the checklist claims an API check on 2026-11-13); first commit 2026-11-10, inside the Submission Period; 30 commits over 4 days; docs in English; zero runtime dependencies in `Package.swift`.

## 4. Per-criterion detail

### Potential Impact: 7
Strengths
- Real problem every Mac user with external drives meets. Evidence: `README.md` "The problem", `docs/screenshots/finder-eject-fails.png`.
- Shows what is holding the volume with pid, user, category, path (`docs/screenshots/phantom-trace.png`: `tail` open file, `zsh` cwd).
- Least-destructive staged pipeline with preview and confirmation (`banish-confirm.png`, Cancel default).
- Finder Quick Action plus CLI plus drop window give several ways in.
Weaknesses
- Only demonstrated on a 20 MB throwaway image and two helper locks, not a real-world case (Spotlight, Photos).
- Ad-hoc signed, not notarized; install friction for non-technical users (Quick Action must be enabled by hand, README).
- Accessibility untested (README Status), which matters for the "accessible" part of the criterion.
- Tested on macOS 27.2.1 only.
Biggest lift: a short video showing a real Finder eject failure resolved end to end.

### Technological Implementation: 7
Strengths
- Spec-driven: `.kiro/specs/phantomtrace-volume-lock-forensics/` (requirements, design, tasks) mapped to log rows in `docs/ProjectLog.md`.
- 11 steering files that changed code: custom SwiftLint rules from `safety.md` and `tech.md` (KiroUsage, backed by the log).
- Property tests: 25 files in `Tests/PhantomTracePropertyTests`; a real bug found (`/private/var/vm` protected path) with a regression test; a second bug found by the integration test (`0xC000 | EBUSY`). Honest "no bug found" notes.
- Engineering: single `SafetyPolicy` choke point, identity guard `(pid, start time)`, absolute-path subprocesses, total parser, cancellation audit via `swift-expert` power (D-021). About 7.7k lines source, 8.6k lines tests.
Weaknesses
- No MCP use evidenced. A commit message mentions "MCP settings", but no MCP file is tracked in the repo (`git ls-files` shows none). KiroUsage says "record any servers used".
- No custom agents (`.kiro/agents` absent). `.kiro/prompts/score-hackathon.md` exists but is a prompt, not an agent.
- Hook effect is owner-reported; no captured block or lint output (`docs/KiroUsage.md`, "Evidence to add").
- No with/without steering comparison; no spec vs vibe coding comparison; IDE/CLI/Web difference not written up (log shows 105 IDE rows, 12 Web/CLI rows, so the data exists).
- Parser fixtures are generated, not captured from a real lsof run (`docs/KiroUsage.md`).
Biggest lift: add real hook evidence plus a short write-up of IDE vs Web and spec vs vibe, and, if true, one real MCP use.

### Design: 6
Strengths
- Distinct, coherent theme: pinstripe titlebars, woodcut border, ghost, CRT; consistent across `cannot-put-away.png` and `phantom-trace.png`.
- Clear copy and safety cues ("Beware: this force-stops programs", Cancel default).
- Accessibility code exists (`Sources/PhantomTraceUI/AccessibilityText.swift`, 11 accessibility/reduce-motion references).
- Eight real screenshots from the running app (README table), captured on macOS 27.2.1.
Weaknesses
- VoiceOver and Reduce Motion never tested (README). Accessibility counts as unproven.
- Screenshot flaws: "Working Dire" truncated in the lock table; disabled radio options show no reason; large empty area in "Cannot Put Away" window (`cannot-put-away.png`).
- Heavy art makes small text low contrast on the textured border; the window is image-driven and not resizable per docs (not verified).
- The start/drop window screenshot is missing (checklist known gaps).
Biggest lift: fix truncation, run and record a VoiceOver and Reduce Motion pass in `docs/ManualQA.md`, add the drop-window screenshot.

### Innovation/Idea: 6
Strengths
- Revives a specific dead tool ("What's Keeping Me?") for APFS/modern macOS, and fits Resurrection.
- Escalation ladder (cd ~, quit, SIGTERM, SIGKILL, unmount) with rescans and identity checks is a thoughtful design.
- Retro gothic UI as a diagnostic skin is memorable.
Weaknesses
- Functionally close to `lsof` plus Activity Monitor; no new data source.
- Competes with existing paid utilities (for example Sensei, Unlocker-like apps); the README does not compare them.
- Resurrection framing is mostly visual; the technology revived is a utility concept.
Biggest lift: state clearly in the pitch what Finder and lsof cannot do (guided, reversible resolution with safety rules).

### Presentation: 3 (capped, no video)
Strengths
- `docs/demo-script.md` is a tight 170 s plan with a rehearsed setup.
- README has screenshots and honest status.
- Hackathon docs and checklist are well organized.
Weaknesses
- No YouTube video (cap rule).
- README is long, with many caveats before the pitch; a judge sees "no demo video exists yet" in the Status section.
- No pitch text in Devpost form; no blog or social post.
Biggest lift: record and publish the video, then link it at the top of the README.

## 5. Submission completeness

| Item | Status |
|---|---|
| Text description | Missing (source text exists in `docs/ProjectOverview.md`) |
| Working-app URL and test instructions | Partial: GitHub URL plus README Build/Run; not entered in Devpost (unverifiable) |
| YouTube link | Missing |
| GitHub URL | Done (repo exists) |
| Category and bonus selections | Unverifiable (checklist unchecked) |
| Kiro write-up: specs | Done (`docs/KiroUsage.md`), no vibe-coding comparison |
| Steering | Done, no with/without comparison |
| Hooks | Done, owner-reported only |
| Property-based testing | Done, strongest area |
| Powers | Partial: `swift-expert` used twice, one strong |
| IDE/CLI/Web/Crew differences | Missing (log has the data) |
| Custom agents | Not used |
| MCP | Not used (no evidence) |

## Bonus prizes

| Prize | Readiness | Note |
|---|---|---|
| Best Demo | Not started | Needs video plus top 10% overall. |
| Bonus Blog Prize | Not started | Needs a public third-party post mentioning Kiroween 2026. Cheapest win. |
| Social Blitz | Not started | Post must start with `#KiroweenHackathon26`. |
| Best Ghost of Kiroween Past | Possibly relevant | README says the owner entered 2025 (West of House); must confirm registration in the form. Unverifiable here. |
| Best Kiro Crew App, Best Startup, Best Student | Not relevant | No evidence of a Crew app, startup, or student status. |

## 6. Prioritized action plan (21 days)

| # | Action | Gain | Effort (h) | Criterion |
|---|---|---|---|---|
| 1 | Record and publish a public YouTube demo under 3 minutes per `demo-script.md`, link it atop README | +4 | 3 | Presentation |
| 2 | Write the Devpost text and Kiro write-up (IDE vs Web from log, spec vs vibe, hook and steering evidence) | +1 to +2 | 2 | Tech, Presentation |
| 3 | Blog post and `#KiroweenHackathon26` post, submit both URLs | prizes | 2 | Bonus |
| 4 | Capture a real hook block or lint message and add it to KiroUsage | +0.5 to +1 | 0.5 | Tech |
| 5 | VoiceOver and Reduce Motion pass, fill `docs/ManualQA.md`, tick the working-app item | +1 | 1.5 | Design, Impact |
| 6 | Fix "Working Dire" truncation and add the drop-window screenshot | +0.5 | 1 | Design |
| 7 | Move the pitch above the status caveats in README; add a comparison with `lsof` and similar tools | +0.5 | 0.5 | Presentation, Innovation |
| 8 | Add one real MCP or custom agent use only if it helps the project; do not fake it | +0.5 | 2 | Tech |
| 9 | Run full `swift test` plus `Scripts/lint-and-test.sh` and record it | +0 (risk) | 0.3 | Functionality |

## 7. Honesty check

Claims not fully supported:
- README "Built with Kiro" says fuzz tests cover "`lsof`/`fuser` output parser". Only `LockDiscoveryEngine.swift` mentions fuser; the parser tests are lsof-focused. Overstated.
- Checklist says "259 tests"; my run found 258 with the integration suite skipped. Probably consistent, but I did not verify the 259.
- Checklist and README say hooks were active; there is no captured output (the docs say so themselves).
- A commit message claims "add MCP settings", but no MCP file is tracked.
- Public repo and MIT detection are checklist claims; I verified only the local LICENSE and the remote URL.
- Manual end-to-end pass is owner-reported, not recorded in `ManualQA.md`.
- Design assets are claimed to be distinct from Kiro's ghost; judged by the owner only.
- Fixtures are described as lsof samples but are generated, as KiroUsage admits.

Caps applied:
- Presentation capped at 3: no video.
- Design held at 6: accessibility unverified; screenshots exist, so the "never launched" cap of 4 did not apply.
- Technological Implementation held at 7: no MCP, no custom agents, hook evidence owner-reported.
- Impact held at 7: only a throwaway-image demo, not verified by me on a live app.
