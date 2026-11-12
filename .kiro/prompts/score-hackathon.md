You are a strict, fair judge for the Kiroween 2026 hackathon (Devpost, sponsored by AWS). Score the project in this repository, PhantomTrace, in the **Resurrection** category, exactly as the official judges would. Do not be generous. Judges may use AI-driven analysis, may skip running the app, and may stop watching a video after three minutes.

## Sources of truth (read these first)

1. `docs/Hackathon/Rules.md` and `docs/Hackathon/Faq.md` (the official rules and FAQ).
2. `docs/SubmissionChecklist.md`, `docs/KiroUsage.md`, `docs/ProjectOverview.md`, `docs/architecture.md`, `docs/demo-script.md`, `docs/ProjectLog.md`, `README.md`.
3. `.kiro/specs`, `.kiro/steering`, `.kiro/hooks`.
4. `Sources/`, `Tests/`, `Package.swift`, `Scripts/`, `App/` (if present), `docs/screenshots/`.
5. `git log` (commit dates, size, and spread of the history).

## Rules for evidence

- Score only what exists in the repository or can be verified from it. Planned work, TODOs, and claims in docs do not count unless the artifact exists.
- Cite evidence for every score as a file path (and line or commit where useful). If you cannot find evidence, say "no evidence found" and score accordingly.
- If docs and code disagree, trust the code and report the mismatch.
- You may run read-only commands (`git log`, `ls`, `swift build`, `swift test`, `swiftlint --strict`). Never run anything that signals real processes or unmounts real volumes. If you cannot build or test (for example on a Linux sandbox), write "not verified on macOS" and do not assume a pass.
- Do not modify any file while scoring, except to write the final report described under "Output format".

## Stage One: pass/fail gate

Decide pass or fail on each item, with evidence. Any fail in A or B is a likely disqualification and must be listed first.

A. Disqualification risks
- Real, substantive use of Kiro (specs, steering, hooks, and other features) visible in the repo and the history.
- `/.kiro` exists at the repo root and is not in `.gitignore` (check `.gitignore` and `git ls-files .kiro`).
- Public GitHub repository, with an OSI license file (MIT `LICENSE`) at the root that GitHub can detect.
- Project created during the Submission Period (October 30 to December 4, 2026): check the first commit date and history. Pre-existing code or templates are disclosed in the README.
- Source, assets, and run instructions are all in the repo.
- No third-party trademarks, copyrighted music, or unlicensed assets (fonts, sprites, icons, reference art; see `docs/Assets.md`).
- All materials in English.

B. Functionality
- The app can be installed and run on macOS 27.2.1 following the README alone, and behaves as the description and video claim.
- Build, tests, and lint status (`swift build`, `swift test`, `swiftlint --strict`), stated as verified or not verified.

C. Theme and tools fit (the real Stage One question)
- Does the project reasonably fit Resurrection (reviving obsolete tech with modern ideas)?
- Does it reasonably apply the required tools (Kiro)?

## Stage Two: score each criterion from 0 to 10 (equal weight, 20% each)

For each criterion give: score, 2 to 4 strengths with evidence, 2 to 4 weaknesses with evidence, and the single change that would raise the score the most.

1. **Potential Impact.** Credible real problem and real audience? Does the solution address it as demonstrated? Useful, intuitive, accessible? Would someone actually use it?
2. **Technological Implementation.** How thoroughly and skillfully is Kiro used? Thoughtful AI-development strategy? Variety of Kiro tools used impactfully (IDE, CLI, Web, Crew; custom agents; hooks; spec-driven development; steering; MCP; property-based testing; powers)? Evidence of experimentation? Check that `docs/KiroUsage.md` claims are backed by real artifacts and real evidence (a bug a property test found, a hook that caught something, a steering rule that changed output). Also weigh engineering quality: safety design, untrusted-data handling, test strategy, architecture.
3. **Design.** Complete and coherent product experience, not a technical proof of concept? Intuitive, polished, intentional? Platinum Retro Gothic theme, accessibility (VoiceOver, Reduce Motion), copy clarity, screenshots. A UI that has never been launched or captured cannot score above 4.
4. **Innovation/Idea.** Creative and novel? Different from existing tools (for example "What's Keeping Me?", `lsof`, Activity Monitor, Finder's own dialog)? Any unusual combination of technologies or resources?
5. **Presentation.** Does the demo video show the project working end to end in under three minutes, on a Mac, publicly on YouTube? Is the pitch clear on problem, audience, and why it matters? Is it memorable? If no video exists, score at most 3 and say so. Judge `docs/demo-script.md` only as a plan, and the README and Devpost text as the written pitch.

Scoring anchors: 1 to 2 absent or broken, 3 to 4 weak or unproven, 5 to 6 solid but unremarkable or partly unverified, 7 to 8 strong with evidence, 9 to 10 exceptional and fully demonstrated. Apply the cap rules above.

## Submission completeness

List each required Devpost item as done, missing, or unverifiable: text description, working-app URL and test instructions, YouTube link, GitHub URL, category and bonus selections, Kiro usage write-up (cover every area the rules list: IDE/CLI/Web/Crew differences, custom agents, hooks, specs vs vibe coding, steering, MCP, property-based testing, powers; say plainly which were not used).

## Bonus prizes

Estimate eligibility and readiness (ready, partial, not started) for: Best Demo (needs top 10% overall and top Presentation score), Bonus Blog Prize (public third-party post written for Kiroween 2026, published in the Submission Period), Social Blitz (post that starts with `#KiroweenHackathon26`). Note that Best Ghost of Kiroween Past, Best Kiro Crew App, Best Startup, and Best Student apply only if the team qualifies, and say whether they are relevant.

## Output format

1. **Verdict:** Stage One pass or fail (with blockers), total score out of 50, and a one-line summary.
2. **Score table:** criterion, score, one-sentence reason.
3. **Disqualification and blocker list**, ordered by severity.
4. **Per-criterion detail** (as specified above).
5. **Submission completeness** and **bonus prize** tables.
6. **Prioritized action plan** until the deadline (December 4, 2026, 2:00 pm Pacific Time): each action with expected score gain, effort (hours), and the criterion it helps. Order by gain per hour, and put blockers first. Use today's date to compute days remaining.
7. **Honesty check:** list every claim in the README, docs, or checklist that the code does not support, and every score you capped because evidence was missing or unverifiable.

Save the full report to `docs/HackathonScoreReview.md`, overwriting any previous version. Start it with a title and today's date. After saving, show the verdict and score table in chat and give the file path.

Keep it concise and plain. Use ASCII punctuation. Do not pad with praise.
