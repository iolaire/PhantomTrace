---
inclusion: always
---

# Hackathon

PhantomTrace is a Kiroween 2026 entry in the Resurrection category. The deadline is **December 4, 2026, 2:00 pm Pacific Time** (no extensions, no edits after). Full rules: `docs/Hackathon/Rules.md`; FAQ: `docs/Hackathon/Faq.md`; checklist: `docs/SubmissionChecklist.md`.

## Disqualification risks (hard rules)

- Never add `.kiro/` or its subfolders to `.gitignore`.
- The repository stays public on GitHub with the MIT `LICENSE` at the root (detected by GitHub).
- All source, assets, and run instructions stay in the repository; a judge must be able to build and run it on macOS 27.2.1 following the README.
- Disclose any pre-existing code or templates in the README (currently: none).
- Use third-party SDKs, APIs, fonts, and sprites only within their licenses. Runtime dependencies stay at zero.
- Real, substantive use of Kiro features is required; keep it visible and honest.

## Demo and media

- Demo video under 3 minutes, public on YouTube, showing the app running on a Mac: locked drive -> Finder fails to eject -> Quick Action -> PhantomTrace reveals the process and file -> pipeline -> safe eject. Plan in `docs/demo-script.md`.
- No third-party trademarks or copyrighted music or material without permission. All submission material is in English.
- Bonus: Best Demo, Bonus Blog Prize (public third-party blog post), Social Blitz (post starting `#KiroweenHackathon26`).

## Judging criteria (equal weight)

Impact, Technological Implementation, Design, Innovation, Presentation.

- Technological Implementation: show specs (`.kiro/specs`), steering (`.kiro/steering`), hooks (`.kiro/hooks`: swiftlint and test pre-commit, lint on save), and property-based testing of the `lsof` parser. Keep `docs/KiroUsage.md` current with real evidence.
- Design: Platinum Retro Gothic polish and accessibility (`platinum-ui.md`).
- Presentation: keep the demo scenario reproducible (a throwaway `.dmg` with a held file and an idle shell) and capture screenshots as features land.
