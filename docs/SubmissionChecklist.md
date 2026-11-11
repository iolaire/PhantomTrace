# Submission Checklist

Tracks the Kiroween 2026 requirements from [Rules.md](Hackathon/Rules.md) and [Faq.md](Hackathon/Faq.md). Deadline: **December 4, 2026, 2:00 pm Pacific Time**. No extensions, and no edits after the deadline.

Category: **Resurrection**. Bonus categories to pursue: Best Demo, Bonus Blog Prize, Social Blitz.

## Hard requirements (disqualification risk)

- [ ] Built with Kiro, with real use of several Kiro features (insufficient use is grounds for disqualification).
- [ ] Project created during the Submission Period (Oct 30 to Dec 4, 2026). Disclose any pre-existing code or templates.
- [ ] Public GitHub repository (not GitLab or Bitbucket).
- [ ] OSI open source license file, detected by GitHub and visible in the repository About section (`LICENSE`, MIT).
- [x] `/.kiro` directory at the repo root, and not listed in `.gitignore` (checked 2026-11-11: `.kiro` files are tracked and `.gitignore` has no `.kiro` entry).
- [ ] Repository holds all source, assets, and instructions needed to run the app (see README Build section).
- [ ] Working app installable and runnable on the target platform: macOS 27.2.1 (build 26B131).
- [ ] Demo video under 3 minutes, public on YouTube, showing the app running on a Mac.
- [ ] Video has no third-party trademarks or copyrighted music or material without permission.
- [ ] All submission materials in English.
- [ ] Third-party SDKs, APIs, and data used within their licenses (current runtime dependencies: none).

## Submission form content

- [ ] Text description of features and functionality (start from [ProjectOverview.md](ProjectOverview.md)).
- [ ] URL to the functional app, plus testing instructions for judges (README Build and Run sections).
- [ ] YouTube video link.
- [ ] GitHub repository URL.
- [ ] Category and bonus categories selected.
- [ ] Kiro usage write-up (see [KiroUsage.md](KiroUsage.md)).

## Bonus prizes

- [ ] Best Demo: top 10% overall and top Presentation score. Needs an end-to-end demo that is clear and memorable.
- [ ] Bonus Blog Prize: public post on a third-party blog platform, published during the Submission Period, stating it was written as part of the Kiroween 2026 hackathon. Submit the URL.
- [ ] Social Blitz: post starting with `#KiroweenHackathon26`, with the favorite thing about Kiro and how it changed the approach to development. Submit the link.

## Judging criteria map (each worth 20%)

| Criterion | What judges look for | Where PhantomTrace shows it |
|---|---|---|
| Potential Impact | Real problem, real audience, usable | Finder's unhelpful eject error; [ProjectOverview.md](ProjectOverview.md) section 1 |
| Technological Implementation | Deep, varied, thoughtful Kiro use | [KiroUsage.md](KiroUsage.md), `.kiro/specs`, `.kiro/steering`, `.kiro/hooks` |
| Design | Complete, polished, intentional product | Platinum Retro Gothic UI, diagnostic sheet |
| Innovation/Idea | Novel concept | Resurrecting "What's Keeping Me?"-style tools for modern macOS |
| Presentation | End-to-end demo, clear pitch | [demo-script.md](demo-script.md) |

## Known gaps

Last reviewed 2026-11-11.

- Code for the Core, CLI, app, Quick Action, and bundler is written, but the app has never been launched. Nothing has been seen on screen, so the "working app" item above stays unticked. Status table: [architecture.md](architecture.md).
- Known design gaps (details in [architecture.md](architecture.md#known-gaps-and-deviations-from-the-design)): `ResolutionPipeline` does not pass user-confirmed daemons to plan building; manual Egress Shells outcomes cannot be represented in `StageOutcome`; `Banner` has no partial/failed kind field (the window controller infers it from the message prefix).
- Untested: VoiceOver, Reduce Motion, the Quick Action in Finder, the drop target, and the end-to-end flow. `docs/ManualQA.md` does not exist yet.
- Provisional behaviors (Req 18.6, 18.7, 18.15, 18.16, 18.21, 18.23, 18.26) still need the owner's confirmation.
- Notarization is optional and has not been attempted (`notarytool` and `stapler` are present).
- `swiftlint` on this machine needs `DYLD_FRAMEWORK_PATH=/Library/Developer/CommandLineTools/usr/lib`.
- Hooks exist (`lint-on-save`, `pre-commit-check`, `kiro-gitignore-guard`, `project-log-check`) but are not confirmed live in Kiro. Git hooks (`Scripts/install-git-hooks.sh`) are written but not enabled in every clone.
- The earlier note that `swift test` could not run on the dev machine is out of date: targeted `swift test` runs pass on macOS. A full-suite run followed by `Scripts/lint-and-test.sh` has not been recorded; do that before submission. The Kiro Web sandbox is Linux and cannot build or test macOS code.
- [demo-script.md](demo-script.md) is a plan and cannot be recorded until the app works.
- `docs/screenshots/` is empty. Capture the idle, haunting, and released states once the UI exists.
- Design reference art is in [LookAndFeel](LookAndFeel/README.md), and their origin (Google Gemini) is recorded in [Assets.md](Assets.md), but its "To confirm" items (Gemini terms, the ghost side-by-side check, title font license) are still open. Close them before submission.
- [KiroUsage.md](KiroUsage.md) now records two real bugs (the `/private/var/vm` protected-path bug found by a property test, and the `0xC000 | EBUSY` busy status found by the integration test). It still has "Evidence to add" lines (steering impact, hook catches, surface differences).
- Commit steadily and keep [ProjectLog.md](ProjectLog.md) current; the history and log are the proof the build happened inside the Submission Period.
