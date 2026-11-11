# Submission Checklist

Tracks the Kiroween 2026 requirements from [Rules.md](Hackathon/Rules.md) and [Faq.md](Hackathon/Faq.md). Deadline: **December 4, 2026, 2:00 pm Pacific Time**. No extensions, and no edits after the deadline.

Category: **Resurrection**. Bonus categories to pursue: Best Demo, Bonus Blog Prize, Social Blitz.

## Hard requirements (disqualification risk)

- [ ] Built with Kiro, with real use of several Kiro features (insufficient use is grounds for disqualification).
- [ ] Project created during the Submission Period (Oct 30 to Dec 4, 2026). Disclose any pre-existing code or templates.
- [ ] Public GitHub repository (not GitLab or Bitbucket).
- [ ] OSI open source license file, detected by GitHub and visible in the repository About section (`LICENSE`, MIT).
- [ ] `/.kiro` directory at the repo root, and not listed in `.gitignore`.
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

- Hooks exist (`lint-on-save`, `pre-commit-check`, `kiro-gitignore-guard`) but are untested live in Kiro, and SwiftLint is not installed on the dev machine (`brew install swiftlint`). Until it is, the commit gate blocks every agent commit.
- Feature logic is not implemented yet (scaffolding stage). The app, Quick Action, and UI must exist before submission.
- `docs/architecture.md` and `docs/demo-script.md` are placeholders.
- No screenshots in `docs/screenshots`.
- Git history has a single commit. Commit steadily to show the build happened inside the Submission Period.
