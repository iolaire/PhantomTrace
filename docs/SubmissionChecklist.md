# Submission Checklist

Tracks the Kiroween 2026 requirements from [Rules.md](Hackathon/Rules.md) and [Faq.md](Hackathon/Faq.md). Deadline: **December 4, 2026, 2:00 pm Pacific Time**. No extensions, and no edits after the deadline.

Category: **Resurrection**. Bonus categories to pursue: Best Demo, Bonus Blog Prize, Social Blitz.

## Hard requirements (disqualification risk)

- [x] Built with Kiro, with real use of several Kiro features (insufficient use is grounds for disqualification). Checked 2026-11-13: specs, 11 steering files, 4 hooks, property tests, and the `swift-expert` power are in the repo; the log names the Kiro surface per change. Gaps in hook, MCP, and custom-agent evidence are listed in [KiroUsage.md](KiroUsage.md).
- [x] Project created during the Submission Period (Oct 30 to Dec 4, 2026). Disclose any pre-existing code or templates. Checked 2026-11-13: first commit is 2026-11-10; the README discloses the only carry-over (an image-prompt style from the 2025 entry).
- [x] Public GitHub repository (not GitLab or Bitbucket). Checked 2026-11-13: `https://github.com/iolaire/PhantomTrace` returns HTTP 200 unauthenticated and the API reports `private: false`.
- [x] OSI open source license file, detected by GitHub and visible in the repository About section (`LICENSE`, MIT). Checked 2026-11-13: the GitHub API reports license `MIT` (spdx_id).
- [x] `/.kiro` directory at the repo root, and not listed in `.gitignore` (checked 2026-11-11: `.kiro` files are tracked and `.gitignore` has no `.kiro` entry).
- [x] Repository holds all source, assets, and instructions needed to run the app (see README Build section). Checked 2026-11-13: `swift build`, `swiftlint --strict`, and `swift test` (259 tests) pass on macOS 27.2.1 from a clean tree; screenshots are tracked.
- [ ] Working app installable and runnable on the target platform: macOS 27.2.1 (build 26B131). Owner-reported working on 2026-11-12; tick after the ManualQA pass record is filled in.
- [ ] Demo video under 3 minutes, public on YouTube, showing the app running on a Mac.
- [ ] Video has no third-party trademarks or copyrighted music or material without permission.
- [x] All submission materials in English. Checked 2026-11-13 for the repo docs; the Devpost text and video still need the same check.
- [x] Third-party SDKs, APIs, and data used within their licenses (current runtime dependencies: none). Checked 2026-11-13: `Package.swift` has only the test-only `swift-property-based`; art provenance is in [Assets.md](Assets.md).

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

Last reviewed 2026-11-12.

- The owner completed a manual end-to-end pass on 2026-11-12 on a throwaway disk image: the Quick Action in Finder's right-click menu, the three-window flow with forward and back buttons, image placement, menus and Quit, force quitting apps, and a two-stage quit (`agy` in the terminal first, then the rescan shows `zsh` still locking the drive, and quitting that releases it). This is owner-reported; fill in the pass record in [ManualQA.md](ManualQA.md) and tick the "working app" item when the recorded pass matches. Status table: [architecture.md](architecture.md).
- Design gaps from the last review are fixed in Core (D-023, details in [architecture.md](architecture.md#known-gaps-and-deviations-from-the-design)): the pipeline accepts confirmed daemons, `StageOutcome.manual` reports hand-off shells, and `Banner.kind` replaces the message-prefix check. Still open: no UI asks the user to confirm a daemon. The window now lists manual shells (2026-11-13).
- Untested: VoiceOver, Reduce Motion, and the drop target path. [ManualQA.md](ManualQA.md) is partly ticked (2026-11-13 pass record: Sections 1 and 7 in full, parts of 3 and 5); the rest is open.
- Provisional behaviors (Req 18.6, 18.7, 18.15, 18.16, 18.21, 18.23, 18.26) still need the owner's confirmation.
- Notarization is optional and has not been attempted (`notarytool` and `stapler` are present).
- `swiftlint` on this machine needs `DYLD_FRAMEWORK_PATH=/Library/Developer/CommandLineTools/usr/lib`.
- Hooks exist (`lint-on-save`, `pre-commit-check`, `kiro-gitignore-guard`, `project-log-check`) and the owner states (2026-11-12) they were active in Kiro IDE during the build, but no hook output was captured, so a recorded block or lint message is still to add. The `swift-expert` power was also used (owner statement; two logged uses, including the D-021 concurrency audit, see [KiroUsage.md](KiroUsage.md)). Git hooks (`Scripts/install-git-hooks.sh`) are written but not enabled in every clone.
- The earlier note that `swift test` could not run on the dev machine is out of date: targeted `swift test` runs pass on macOS. A full-suite run followed by `Scripts/lint-and-test.sh` has not been recorded; do that before submission. The Kiro Web sandbox is Linux and cannot build or test macOS code.
- [demo-script.md](demo-script.md) is a plan and cannot be recorded until the app works.
- `docs/screenshots/` holds eight captures from 2026-11-13 (including Finder's own eject failure dialog) (Finder eject failure, cannot put away, lock list, both plan previews, rescan after a stage, Banish confirmation, volume released). The start/drop window with the volume list was not kept because it showed other drives' names; retake it with only the demo image mounted if wanted. No demo video yet. Clips: all three required clips (`s03-trigger`, `s06-egress`, `s09-handoff`) and the optional `s01-problem` and `s07-graceful` are recorded (2026-11-13, see [../demo/CLIPS.md](../demo/CLIPS.md)). The video has not been rendered with them yet.
- The first Egress Shells run on a new build waits about 15 s with no message while macOS asks for Automation consent for Terminal. When the `cd ~` cannot be sent, the window now shows the Requirement 7.5 instruction (fixed 2026-11-13).
- Design reference art is in [LookAndFeel](LookAndFeel/README.md), and their origin (Google Gemini) is recorded in [Assets.md](Assets.md), and its "To confirm" items are closed (owner statements, 2026-11-12: generation date 2026-11-11, no terms limiting use of the art, ghost and colors Kiro-inspired and checked as distinct, system font fallback so no font license). The model was Gemini 3.8 Flash on the owner's Google AI Pro account.
- [KiroUsage.md](KiroUsage.md) now records two real bugs (the `/private/var/vm` protected-path bug found by a property test, and the `0xC000 | EBUSY` busy status found by the integration test). It also records steering-to-lint and steering-to-test evidence taken from the project log. It still has "Evidence to add" lines (a captured hook block or lint message, a with/without steering comparison, surface differences).
- Commit steadily and keep [ProjectLog.md](ProjectLog.md) current; the history and log are the proof the build happened inside the Submission Period.
