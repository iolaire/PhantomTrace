# Kiroween 2026 Score Review: PhantomTrace (Resurrection)

Generated with `@score-hackathon` (`.kiro/prompts/score-hackathon.md`). Reviewed on 2026-11-12, with 22 days left until December 4, 2026, 2:00 pm PT. This is the second run of the day. The first scored 25 / 50; owner-reported testing and the provenance answers have since been recorded in the docs. Owner statements were not independently verified.

## 1. Verdict

**Stage One: pass, with one unverifiable item (the repo being public).** There are no hard disqualifiers I could find. **Score: 28 / 50.** The engineering, Kiro usage, and an owner-tested working flow are strong. What a judge can see is still thin: no demo video, no screenshots, and a Kiro usage write-up that is still a draft.

| Criterion | Score | Reason |
|---|---|---|
| Potential Impact | 7 | A real, relatable Finder problem, and the owner reports the full flow working, including a realistic two-stage quit. The audience is narrow (macOS 27.2.1 only) and nothing is shown to judges yet. |
| Technological Implementation | 7 | Deep spec, steering, hook, and property-test use, with two real bugs documented. Only the IDE and Web are used, and there are no custom agents, project MCP use, or powers. |
| Design | 6 | Coherent Platinum theme, sprites, icon, and custom dialogs, tested by the owner. `docs/screenshots/` is empty, and VoiceOver and Reduce Motion are untested. |
| Innovation/Idea | 6 | The Resurrection framing and the graduated, safety-gated pipeline are distinctive. Finding what holds a volume open is not a new idea. |
| Presentation | 2 | No video exists, only a plan in `docs/demo-script.md` (cap 3). |
| **Total** | **28 / 50** | |

## 2. Blockers, by severity

1. **No demo video.** A public YouTube video under 3 minutes is required. Without it, Presentation is capped at 3 and Best Demo is out of reach.
2. **No screenshots.** `docs/screenshots/` is empty, so judges reading only the README and Devpost page see no UI.
3. **Kiro usage write-up is a draft.** `docs/KiroUsage.md` still has "Evidence to add" lines (lines 10, 27, 41) and "record any" placeholders for custom agents, MCP, and powers (lines 55 to 57). The Rules require this write-up, and Technological Implementation is scored on it.
4. **Public GitHub status unverified.** The remote is `github.com/iolaire/PhantomTrace`. I could not confirm it is public or that GitHub detects the MIT license.
5. **Working-app item is unticked in the checklist.** The owner reports a full pass, but `docs/ManualQA.md` step boxes are not ticked individually, so the evidence is a single owner statement.

Resolved since the first run (docs only, owner statements):
- Manual end-to-end pass recorded (README, architecture, checklist, ManualQA pass record).
- Prior-work disclosure: only an image prompt style from the 2025 West of House entry was reused, run fresh on Gemini; no old code or art files.
- Asset provenance: generated 2026-11-11 with Gemini 3.8 Flash on the owner's Google AI Pro account; no terms limit use; SynthID kept on purpose; ghost and colors are Kiro-inspired.

## 3. Stage One detail

**A. Disqualification risks**

| Item | Result | Evidence |
|---|---|---|
| Real Kiro use | Pass | 2 specs, 11 steering files, 4 hooks, 1 prompt, and a work log with about 90 rows naming the Kiro surface. |
| `.kiro` tracked and not in `.gitignore` | Pass | 26 tracked `.kiro` files (`git ls-files .kiro`); `.gitignore` has no `.kiro` entry. `.kiro/prompts/` was committed in `ced02f5`. |
| Public repo and MIT license | Unverifiable | `LICENSE` is MIT at the root. Public visibility and GitHub detection were not checked. |
| Built in the Submission Period | Pass | First commit 2026-11-10; 22 commits through 2026-11-12. `c441700` lands the whole app in one commit, so the history is weak evidence of steady building. |
| Assets, trademarks, licensing | Pass (owner statements) | `docs/Assets.md`: Gemini 3.8 Flash art, no limiting terms, AI origin disclosed, ghost and colors Kiro-inspired and checked as distinct. Not independently verified. |
| Prior-work disclosure | Pass | README Hackathon submission section and `docs/Assets.md` disclose the reused image-prompt style. |
| English | Pass | Everything read is in English. |

**B. Functionality**
- `swift build`: passed (re-run today).
- `swiftlint --strict`: passed, 0 violations in 202 files (needs `DYLD_FRAMEWORK_PATH` set, as the README documents).
- `swift test`: passed, 245 tests in 30 suites, including `DiskImageIntegrationTests`. I read only the tail of the output.
- App launch, Quick Action, window flow, force quit, and the two-stage quit (`agy` then `zsh`): owner-reported working on 2026-11-12. I did not run them myself.

**C. Fit**
- Resurrection fits (What's Keeping Me?, System 7 and OS 9 inspector style).
- Kiro is applied substantively.

## 4. Per-criterion detail

**Potential Impact: 7**
- Strengths: it targets a familiar Finder error (`docs/ProjectOverview.md`). The pipeline is safety-first, with protected processes and volumes, fresh scans, and an identity guard (`.kiro/steering/safety.md`). The owner's two-stage quit case (an agent in the terminal, then a leftover `zsh`) shows the tool handling a realistic situation.
- Weaknesses: macOS 27.2.1 only. The manual result is owner-reported with no recording or screenshots. The drop-target path was not reported as tested.
- Biggest lift: a clean end-to-end video.

**Technological Implementation: 7**
- Strengths:
  - Specs drive the build, with requirement numbers cited in `docs/ProjectLog.md`.
  - 11 steering files covering safety, structure, testing, and platform.
  - 4 hooks backed by scripts under `Scripts/`.
  - Property tests found a real safety bug (`/private/var/vm`, Property 10), and the integration test found the `0xC000 | EBUSY` busy status (`docs/KiroUsage.md`).
  - Core, UI, and CLI are split; about 7.6k source lines and 8.4k test lines.
- Weaknesses:
  - No custom agents, powers, or Crew use. MCP servers are configured at user level (`~/.kiro/settings/mcp.json`: AWS, fetch, playwright), but there is no repo config or documented use in the build.
  - IDE vs Web differences are not written up.
  - The hooks are not confirmed live in Kiro, and no hook catch is recorded.
  - Parser fixtures are generated, not captured from real `lsof` output.
- Biggest lift: finish `KiroUsage.md` with concrete evidence and an honest statement of what was not used.

**Design: 6**
- Strengths: coherent Platinum Retro Gothic theme, 7 sprites at 1x and 2x, an app icon (`Packaging/AppIcon.icns`), custom `PhantomDialog` instead of system alerts (D-020), and a 270-line `docs/ManualQA.md`. The owner reports the window flow and image placement work.
- Weaknesses: `docs/screenshots/` is empty. VoiceOver and Reduce Motion are untested (`windowAnnouncement` is not posted yet per `docs/architecture.md`). The `Banner` kind is inferred from a message prefix, and several behaviors are marked provisional.
- Biggest lift: capture the idle, haunting, and released screenshots, then test VoiceOver and Reduce Motion once.

**Innovation/Idea: 6**
- Strengths: a clear resurrection of a classic single-purpose Mac inspector. The four-stage opt-in pipeline (cd out, ask, banish, unmount) behind one safety choke point is a thoughtful take on a manual task.
- Weaknesses: it is a front end over `lsof` and signals, so the underlying technique is known. Nothing unusual is combined beyond the theme.
- Biggest lift: lead the video with the "ghost haunting your drive" story and the two-stage quit.

**Presentation: 2**
- Strengths: `docs/demo-script.md` is a well-timed 170-second plan.
- Weaknesses: no video. The README is long and status-heavy, and there is no Devpost pitch text yet.
- Biggest lift: record and upload the video.

## 5. Submission completeness

| Item | Status |
|---|---|
| Text description | Missing (source material in `docs/ProjectOverview.md`) |
| Working-app URL and test instructions | Mostly done (README Build and Run; flow owner-tested) |
| YouTube link | Missing |
| GitHub URL | Done, visibility unverified |
| Category and bonus selection | Not recorded (Resurrection planned) |
| Kiro usage write-up | Partial (draft) |

Kiro usage areas the write-up must cover:

| Area | Status |
|---|---|
| IDE / CLI / Web / Crew | IDE and Web only; no comparison written |
| Custom agents | Not used |
| Hooks | Used; live behavior unconfirmed; no catches recorded |
| Specs vs vibe coding | Specs used; comparison missing |
| Steering | Used; impact evidence missing |
| MCP | Not used in the build as documented (servers exist at user level) |
| Property-based testing | Used; 1 property bug and 1 integration bug documented |
| Powers | Not used |

## 6. Bonus prizes

| Prize | Readiness |
|---|---|
| Best Demo | Not started. Needs the video and a top-10% overall score. |
| Bonus Blog Prize | Not started. |
| Social Blitz | Not started. |
| Ghost of Kiroween Past | Possibly relevant, since a 2025 entry is mentioned. Confirm registration; the rules also require the 2026 project to be newly created, which the README states. |
| Crew App, Startup, Student | No evidence they apply. |

## 7. Action plan (ranked by gain per hour)

| # | Action | Gain | Effort | Criterion |
|---|---|---|---|---|
| 1 | Record and upload the under-3-minute public YouTube demo from `docs/demo-script.md`, leading with the two-stage quit | +4 to +5 | 3 to 4 h | Presentation |
| 2 | Capture three screenshots (idle, haunting, released) while recording; save to `docs/screenshots/` | +1 to +2 | 0.5 h | Design |
| 3 | Finish `docs/KiroUsage.md`: steering impact, hook catches, IDE vs Web, spec vs vibe; state plainly that custom agents and powers were not used and say whether MCP was used | +1 | 1 to 2 h | Technological Implementation |
| 4 | Test VoiceOver and Reduce Motion once, and tick the matching `docs/ManualQA.md` boxes | +0.5 to +1 | 1 h | Design |
| 5 | Confirm the repo is public and GitHub shows the MIT license in About | Risk reduction | 0.1 h | Stage One |
| 6 | Tick the individual `docs/ManualQA.md` boxes from the owner's pass, then tick the checklist "working app" item | +0.5 | 0.5 h | Honesty |
| 7 | Draft the Devpost text; write the blog post and the `#KiroweenHackathon26` post | Bonus eligibility | 2 to 3 h | Bonus prizes |
| 8 | Run `Scripts/lint-and-test.sh` end to end and record it in the log | Small | 0.2 h | Functionality |
| 9 | Keep committing in small steps so the history shows steady work | Small | ongoing | Technological Implementation |

## 8. Honesty check

- **Owner-reported only.** The working flow, the Quick Action, the force quit, the two-stage quit, the West of House disclosure, the Gemini terms, and the ghost comparison all rest on owner statements. The docs now say so. I verified none of them.
- **Stale checklist boxes.** Most hard-requirement boxes in `docs/SubmissionChecklist.md` are still unticked, even though some are likely done (license, `.kiro`, repo contents).
- **Screenshots.** The README and checklist reference screenshots, but `docs/screenshots/` is empty.
- **Hooks.** `docs/KiroUsage.md` says hooks are tested with sample payloads, with live behavior unconfirmed. I did not confirm they run in Kiro.
- **MCP.** The user-level MCP config exists, but no repo document says it was used. I scored it as unused.
- **Caps and holds.**
  - Presentation set to 2 (cap 3): no video.
  - Design held at 6: owner-tested, but nothing captured and accessibility untested.
  - Technological Implementation held at 7: no custom agents, powers, or documented MCP use, and hooks unconfirmed.
- **Not verified by me.** Whether the repo is public, the app launch and flow, the Finder Quick Action, the drop-target path, VoiceOver, Reduce Motion, and the full-suite `Scripts/lint-and-test.sh`. I ran `swift build`, `swiftlint --strict`, and `swift test` separately; all passed.
