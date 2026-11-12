# Kiroween 2026 Score Review: PhantomTrace (Resurrection)

Generated with `@score-hackathon` (`.kiro/prompts/score-hackathon.md`). Reviewed on 2026-11-12, with 22 days left until December 4, 2026, 2:00 pm PT. Updated the same day to include the owner's report of a full manual end-to-end test. That report is owner-supplied and was not independently verified.

## 1. Verdict

**Stage One: conditional pass.** There are no hard disqualifiers. Three submission artifacts are missing, though: the demo video, the screenshots, and the Devpost write-up. **Score: 28 / 50** (25 before the owner-reported manual test). The engineering, Kiro usage, and now the working flow are strong. What a judge can actually see is still thin: no video and no screenshots.

| Criterion | Score | Reason |
|---|---|---|
| Potential Impact | 7 | The pain point is real and the owner reports the full flow working, including a two-stage quit. The audience is narrow (macOS only) and the flow isn't shown to judges yet. |
| Technological Implementation | 7 | Deep spec, steering, hook, and property-test use with two real bugs logged. It uses only the IDE and Web, with no custom agents, MCP, or powers. |
| Design | 6 | The theme is intentional and the owner reports the window flow and images work. `docs/screenshots/` is empty, and VoiceOver and Reduce Motion are untested. |
| Innovation/Idea | 6 | The Resurrection framing and the graduated, safety-gated pipeline are distinctive. The core idea (find what holds a volume open) is not new. |
| Presentation | 2 | There is no video, only `docs/demo-script.md`, which says it is a plan. |

## 2. Blockers, by severity

1. **No demo video.** A public YouTube video under 3 minutes is required, and it caps Presentation at 3.
2. **Working flow is not yet visible to judges (downgraded from blocker).** The owner reports a full manual pass on 2026-11-12 and the docs now record it. Judges still need to see it in the video and screenshots. VoiceOver, Reduce Motion, and the drop-target path were not reported as tested, and the `ManualQA.md` boxes are not individually ticked.
3. **Devpost write-up is not drafted.** `docs/KiroUsage.md` calls itself a draft with several "Evidence to add" lines. It leaves MCP, custom agents, and powers as "record any".
4. **Prior-work disclosure (resolved in docs, 2026-11-12).** The owner states that no pre-existing code or art files were used. Only an AI image prompt from the 2025 West of House entry was reused, run fresh on Gemini to generate new art. The README and `docs/Assets.md` now say so. This is an owner statement and can't be verified from the repo.
5. **Asset licensing (resolved in docs, 2026-11-12).** The owner states the art was generated on 2026-11-11 with Gemini 3.8 Flash on a personal Google AI Pro account, that no terms limit its use, and that the ghost and colors are Kiro-inspired. The invisible SynthID watermark is kept on purpose and the AI origin is disclosed. These are owner statements and were not verified.
6. **Public GitHub status not verified.** The remote is `github.com/iolaire/PhantomTrace`. Whether it is public, and whether GitHub detects the MIT license, was not confirmed.

## 3. Stage One detail

**A. Disqualification risks**

| Item | Result | Evidence |
|---|---|---|
| Real Kiro use | Pass | 2 specs, 11 steering files, 4 hooks, and a work log with 86 "Kiro IDE" rows and 5 Kiro Web rows. |
| `.kiro` tracked and not in `.gitignore` | Pass | `git ls-files .kiro` lists the files; `.gitignore` has no `.kiro` entry. |
| Public repo and MIT license | Partial | `LICENSE` is MIT at the root. Public visibility is unverified. |
| Built in the Submission Period | Pass | The first commit is 2026-11-10 and there are 21 commits through 2026-11-12. One commit (`c441700`) lands the whole app at once, so it is weak evidence of steady building. |
| Assets and trademarks | Partial | See blockers 4 and 5. |
| English | Pass | Everything read is in English. |

**B. Functionality**
- `swift build` passed.
- `swiftlint --strict` passed, 0 violations in 202 files. It needed `DYLD_FRAMEWORK_PATH` set, as documented.
- `swift test` passed. The final summary line was 245 tests in 30 suites, including `DiskImageIntegrationTests`. Only the tail of the output was read, so the property-test suites were not confirmed separately.
- App launch, the Quick Action, and the window flow: owner-reported working (Quick Action in Finder's right-click menu, forward and back buttons, image placement, menus, Quit, force quit, and a two-stage quit of `agy` then `zsh`). I did not run them myself.

**C. Fit**
- Resurrection fits, with the "What's Keeping Me?" and System 7 framing.
- Kiro use is more than reasonable.

## 4. Per-criterion detail

**Potential Impact: 6**
- Strengths: it addresses a familiar, frustrating Finder error (`ProjectOverview.md`, README). The design is safety-first, with protected processes and volumes, fresh scans, and an identity guard. Failures and timeouts are shown, not hidden. The owner's manual test covers real signals and a realistic two-stage case (an agent in the terminal, then a leftover `zsh`), which is a strong demo story.
- Weaknesses: the audience is macOS users with external drives, and it targets only macOS 27.2.1. The manual result is owner-reported, with no recording or screenshots as evidence.
- Biggest lift: record a clean end-to-end demo. That proves the problem is solved.

**Technological Implementation: 7**
- Strengths:
  - The specs drive the build, with requirement numbers cited in the log.
  - The steering is thorough, covering safety, structure, and testing.
  - Four hooks are backed by scripts.
  - The property tests found a real safety bug (`/private/var/vm`, Property 10).
  - The integration test found `0xC000 | EBUSY` busy handling.
  - There are 90 log rows and 20 decision records.
  - The code is Core/UI/CLI split, with 7.6k source lines and 8.4k test lines.
- Weaknesses:
  - There are no custom agents, MCP, or powers.
  - Surface differences (IDE vs Web) are not written up.
  - The hooks are not confirmed live.
  - The steering-impact and hook-catch evidence lines are empty.
  - The parser fixtures are generated, not captured from real `lsof` output.
  - A commit message mentions MCP settings, but no MCP config is in the repo.
- Biggest lift: finish `KiroUsage.md` with concrete evidence (which steering rule changed output, what a hook caught, IDE vs Web).

**Design: 6** (no longer capped at 4 since the app was run and tested; held below 7 because nothing is captured)
- Strengths: the Platinum Retro Gothic theme is coherent. It has 7 sprites at 1x and 2x, an app icon, and a shared window chrome. Dialogs are custom (D-020), and `ManualQA.md` exists (270 lines).
- Weaknesses: `docs/screenshots/` is empty. VoiceOver and Reduce Motion are untested. The `Banner` kind is inferred from a message prefix. Several behaviors are marked provisional.
- Biggest lift: save the idle, haunting, and released screenshots, then test VoiceOver and Reduce Motion once.

**Innovation/Idea: 6**
- Strengths: the Resurrection angle is clear. The four-stage pipeline (cd out, ask, banish, unmount) with a safety choke point is a thoughtful take on a common manual task.
- Weaknesses: `lsof` plus kill is a known workflow. The product is a front end over existing tools.
- Biggest lift: make the "ghost haunting your drive" story visible in the video. The concept is more novel than the current docs show.

**Presentation: 2**
- Strengths: `demo-script.md` is a well-timed, 170-second plan.
- Weaknesses: there is no video. The README is long and status-heavy, and it admits no screenshots exist. There is no Devpost pitch text yet.
- Biggest lift: record the video.

## 5. Submission completeness

| Item | Status |
|---|---|
| Text description | Missing (the source material is in `ProjectOverview.md`) |
| Working app URL and test instructions | Mostly done (README Build and Run exist, flow owner-tested; tick the checklist item after the `ManualQA.md` record) |
| YouTube link | Missing |
| GitHub URL | Done, visibility unverified |
| Category and bonus selection | Not recorded (Resurrection planned) |
| Kiro usage write-up | Partial |

Kiro usage areas the write-up must cover:

| Area | Status |
|---|---|
| IDE / CLI / Web / Crew | IDE and Web only, no comparison written |
| Custom agents | Not used |
| Hooks | Used, live behavior unconfirmed |
| Specs vs vibe coding | Specs used, comparison missing |
| Steering | Used, impact evidence missing |
| MCP | Not used |
| Property-based testing | Used, with 2 bugs documented |
| Powers | Not used |

## 6. Bonus prizes

| Prize | Readiness |
|---|---|
| Best Demo | Not started. It needs the video and a top-10% overall score. |
| Bonus Blog Prize | Not started. |
| Social Blitz | Not started. |
| Ghost of Kiroween Past, Crew App, Startup, Student | Not evidenced anywhere in the repo, so treated as not relevant. Ghost of Kiroween Past may apply, since the 2025 entry is mentioned. Confirm. |

## 7. Action plan (ranked by gain per hour)

| # | Action | Gain | Effort | Criterion |
|---|---|---|---|---|
| 1 | Capture the three screenshots (idle, haunting, released) while replaying the tested flow, then test VoiceOver and Reduce Motion | +1 to +2 | 1 to 2 h | Design |
| 2 | Record and upload the under-3-minute public YouTube demo from `demo-script.md` | +4 to +5 | 3 to 4 h | Presentation |
| 3 | Finish `KiroUsage.md`: steering impact, hook catches, IDE vs Web, spec vs vibe. State plainly that custom agents, MCP, and powers were not used, or use one. | +1 | 1 to 2 h | Technological Implementation |
| 4 | Tick the individual `ManualQA.md` boxes from the owner's pass (done in docs: launch status, Quick Action, and pass record now agree) | +0.5 | 0.5 h | Honesty, Impact |
| 5 | None needed. Asset provenance is closed in `Assets.md`. | n/a | 0 h | Stage One |
| 6 | Confirm the repo is public with the license detected in About | Risk reduction | 0.1 h | Stage One |
| 7 | Draft the Devpost text, then write and publish the blog post and the `#KiroweenHackathon26` post | Bonus eligibility | 2 to 3 h | Bonus prizes |
| 8 | Commit `.kiro/prompts/score-hackathon.md`, add the ProjectLog row, and keep committing in small steps | Small | 0.3 h | Technological Implementation |
| 9 | Run `Scripts/lint-and-test.sh` end to end and record it in the log | Small | 0.2 h | Functionality |

## 8. Honesty check

- **Launch status.** The README, architecture doc, checklist, and `ManualQA.md` previously contradicted each other. They were updated on 2026-11-12 to record the owner's manual pass as owner-reported. I did not run the app or the Quick Action myself.
- **Checklist.** Most hard-requirement boxes are still unticked, even though some are likely done (license, `.kiro`, repo contents).
- **Pre-existing code.** The README claims none, and now also discloses the reused 2025 image prompt. The owner states no code or art files were reused; this can't be verified from the repo.
- **Screenshots.** `docs/screenshots/` is empty even though the README and checklist reference them.
- **Caps applied.**
  - Design held at 6: the flow is owner-tested, but nothing is captured and accessibility is untested.
  - Presentation set to 2 (cap 3): no video.
  - Technological Implementation held at 7: no MCP, custom agents, or powers, and hooks not confirmed live.
- **Not verified.** Whether the repo is public, the app launch and flow (owner-reported only), the Finder Quick Action (owner-reported only), the drop-target path, VoiceOver, and Reduce Motion. The full-suite `Scripts/lint-and-test.sh` was not run; the build, lint, and test steps were run separately.
