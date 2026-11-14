# PhantomTrace Hackathon Score Review
Date: 2026-11-14 (UTC). Deadline: 2026-12-04, 2:00 pm PT (22:00 UTC). 20 days left.
Category: Resurrection. Method: re-check against HEAD 467cb3a. No changes to `Sources/`, `Tests/`, or `Package.swift` since the earlier run today, so scores are carried forward. Rules (equal weights, 10 points each) re-read; no rules change found. I did not launch the app or watch a video.
Checks: not re-run; last result in the earlier 2026-11-14 run: `swift build` pass; `swiftlint --strict` 0 violations in 209 files; `swift test` 274 tests pass, 2 known issues. Re-verified now: `.kiro/` is not gitignored, `LICENSE` exists, `grep youtube README.md` finds nothing, no `.kiro/settings/mcp.json`.

## 1. Verdict
- Stage One: PASS on theme and Kiro use. No disqualifying defect found in the repo. The missing public YouTube video and unfilled Devpost fields can still sink the entry.
- Total: 29 / 50 (was 28). Realistic ceiling with a public voiced video, accessibility QA, and write-up: about 37 to 39.
- Summary: a safety-first, well-tested tool with real spec, steering, hook, agent, and property-test evidence and a coherent themed UI, but no public video, a modest resurrection idea, no MCP, and unverified accessibility.

## 2. Score table
| Criterion | Score | Reason |
|---|---|---|
| Potential Impact | 6 | Common annoyance, working fix, one-Mac testing and a niche audience. |
| Technological Implementation | 8 | Specs, 11 steering files, 4 hooks with captured block output, custom agent, power, property tests with a real bug; MCP unused, agent never run itself. |
| Design | 7 | Cohesive Platinum UI in 8 real captures; VoiceOver, Reduce Motion, drop target untested. |
| Innovation/Idea | 5 | Faithful revival of "What's Keeping Me?" with a graduated safe pipeline; overlaps existing tools. |
| Presentation | 3 | Capped: no public YouTube video; local drafts only. |
| Total | 29 / 50 | |

## 3. Blockers (by severity)
1. No public YouTube demo (Rules: required). Local drafts `demo/out/phantomtrace-demo.mp4` and `phantomtrace-demo-alex.mp4` exist, are gitignored (`demo/.gitignore`), and are unpublished. `grep youtube README.md` finds nothing.
2. Devpost fields unfilled: description, test instructions, video link, category and bonuses, Kiro write-up (`docs/SubmissionChecklist.md`, "Submission form content" all unticked). Unverifiable from the repo.
3. Video trademark/music check unticked (`docs/SubmissionChecklist.md`).
4. Low risk: a downloaded app is blocked by Gatekeeper (ad-hoc signed, not notarized); README says build from source. Fresh-clone run on a second Mac not done.
5. Low risk: ghost art is Gemini-generated, "Kiro-inspired"; provenance is an owner statement (`docs/Assets.md`).

## 4. Per-criterion detail
### Potential Impact: 6
- + Real, widespread problem (Finder's generic eject error); README lines 11 and up.
- + Graduated, opt-in pipeline with preview and rescan (`Sources/PhantomTraceCore/Resolution/`), plus a CLI.
- - Niche audience; only the owner tested it, on one Mac (`docs/ManualQA.md`: 34 checked, 73 open boxes).
- - Install needs a source build and Terminal Automation consent (about 15 s silent wait on first Egress).
- Biggest lever: a fresh-clone run on a second user account, with fixes.

### Technological Implementation: 8
- + Master spec and tasks drive work-log rows; 11 steering files; custom lint rules derived from steering (`no_print_in_core`).
- + Real hook output captured in Kiro IDE for `project-log-check` and `pre-commit-check` (`docs/KiroUsage.md`).
- + Real bugs found: `/private/var/vm` by Property 10, `0xC000|EBUSY` by the integration test, escape gap by `Tests/Fixtures/real_capture_macos.lsof`.
- + Safety design: single `SafetyPolicy` choke point, identity guard, re-evaluate before send (`ResolutionPipelineSafetyRecheckTests`).
- - MCP not used. `.kiro/agents/safety-reviewer.json` has never been run as an agent, only dry-run by a sub-agent. `lint-on-save` never fired from the IDE.
- - No steering with/without comparison; no IDE/CLI/Web differences written.
- Biggest lever: run `safety-reviewer` for real on a diff and log it; capture an IDE save-hook result.

### Design: 7
- + Platinum window chrome, nine-slice sprites, dialogs (`Sources/PhantomTraceUI/`), 8 captures in `docs/screenshots/`.
- + Accessibility code exists in 10 UI files (labels, motion handling found by grep).
- - VoiceOver, Reduce Motion, drop target untested (`docs/SubmissionChecklist.md` Known gaps).
- - Start/drop window screenshot was not kept; "Working Dire" truncation noted earlier; no daemon-confirm UI.
- Biggest lever: run and record VoiceOver and Reduce Motion QA.

### Innovation/Idea: 5
- + Locks classified by process role with a least-destructive escalation ladder.
- + Kiro drove the real app through Accessibility to record clips and found two real bugs (`docs/KiroUsage.md`).
- - Concept is the same as What's Keeping Me? plus `lsof`; the novelty is the safety pipeline and skin.
- - Nothing that no other tool could do.
- Biggest lever: show in the video the one thing Finder and `lsof` cannot (named process, file, safe stage-by-stage release).

### Presentation: 3 (capped)
- + Scripted clips exist (`demo/CLIPS.md`); the 97 to 103 s drafts fit the 3 minute limit.
- + Eight screenshots tell the story in README.
- - No public video; drafts use placeholder machine voice.
- - `docs/demo-script.md` is only a plan.
- Biggest lever: record own voice, render, upload public.

## 5. Submission completeness
| Item | Status |
|---|---|
| Text description | Missing (source: `docs/ProjectOverview.md`) |
| Working app URL and test instructions | Partial: GitHub URL and README Build/Run; no release |
| YouTube link | Missing |
| GitHub URL | Done (`https://github.com/iolaire/PhantomTrace`) |
| Category and bonus selection | Unverifiable |
| Write-up: IDE/CLI/Web/Crew | Weak: surfaces labelled per row, differences not written |
| Write-up: custom agents | Partial: defined, dry-run only |
| Write-up: hooks | Done: captured block output; IDE `lint-on-save` missing |
| Write-up: specs vs vibe coding | Partial: no comparison |
| Write-up: steering | Done with lint/test evidence; no before/after |
| Write-up: MCP | Not used (stated plainly) |
| Write-up: property tests | Done, with real bugs |
| Write-up: powers | Done: `swift-expert`, two logged uses |

## 6. Bonus prizes
| Prize | Readiness | Notes |
|---|---|---|
| Best Demo | Not started | Needs top 10% overall and top Presentation. |
| Bonus Blog Prize | Not started | No public third-party post. |
| Social Blitz | Not started | Post must start with `#KiroweenHackathon26`. |
Team prizes: Best Ghost of Kiroween Past possibly relevant (2025 entry, confirm on form); Kiro Crew App, Startup, Student not relevant.

## 7. Action plan (20 days left; submit by 2026-12-03)
| # | Action | Gain | Hours | Criterion |
|---|---|---|---|---|
| 1 | Record own voice-over, render, upload public to YouTube, link in README and checklist | +3 to +4 | 2 to 3 | Presentation |
| 2 | Fill Devpost text and Kiro write-up from `docs/KiroUsage.md` and `docs/ProjectOverview.md` | Required | 1.5 | Submission |
| 3 | Post `#KiroweenHackathon26`; add link | Bonus | 0.5 | Bonus |
| 4 | Run VoiceOver and Reduce Motion QA; record in `docs/ManualQA.md` | +0.5 to +1 | 2 | Design |
| 5 | Run `safety-reviewer` as an agent on a diff; capture an IDE `lint-on-save` result | +0.5 | 1 | Tech |
| 6 | Add a 10 s Kiro cutaway (specs, steering, hooks, property tests) to the video | +0.5 | 1 | Presentation |
| 7 | Fresh-clone test on a second Mac or user; follow README only | Risk | 2 | Impact |
| 8 | Publish a third-party blog post naming Kiroween 2026 | Bonus | 2 | Bonus |

## 8. Honesty check
Claims the repo does not fully support:
- `README.md` line 145 says fuzz tests cover `lsof`/`fuser` output. `LockDiscoveryEngine.swift` runs `fuser -c` but I found no fuser parser or fuser property test. Overstated.
- Commit `1ad77c7` says "add MCP settings"; no MCP config is tracked and KiroUsage says MCP is unused. Mismatch in history only.
- `docs/SubmissionChecklist.md` says 259 tests; the run now shows 274. Out of date.
- Hooks "active during the build" and the 2026-11-12 manual pass are owner-reported; only the 2026-11-14 hook blocks have output.
- README and checklist claims of the Quick Action seen in Finder and Gatekeeper behavior: not re-verified by me.
- GitHub public status and MIT detection come from the checklist's 2026-11-13 API check, not re-run.
- Art provenance and "ghost distinct from Kiro" are owner statements.
Scores capped for missing evidence:
- Presentation capped at 3 (no public video).
- Design held at 7 (accessibility untested; app not launched by me).
- Tech held at 8 (no MCP; agent not run as an agent; no IDE save-hook output).
- Impact held at 6 (single-machine testing).
