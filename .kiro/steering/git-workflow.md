---
inclusion: always
---

# Git Workflow

- Commit steadily in small, logical commits; the history is judged evidence that the project was built in the Submission Period (Oct 30 to Dec 4, 2026). Do not squash away history or rewrite published commits.
- Conventional-style subjects, imperative mood, at most 72 characters: `feat(discovery): add LsofParser`, `fix(mounts): match whole path components`, `test(parser): add round-trip property`, `docs:`, `chore:`, `refactor:`.
- One concern per commit. Spec changes (`.kiro/specs`) and code that implements them can be separate commits that reference the requirement numbers.
- Before committing: `swiftlint --strict` clean, `swift build` and `swift test` pass (on a Mac). Never use `--no-verify`.
- Never commit build output (`.build/`, `DerivedData/`), `.DS_Store`, secrets, or signing certificates.
- Never add `.kiro/` or any subfolder to `.gitignore`. Never remove `.kiro/steering`, `.kiro/specs`, or `.kiro/hooks` content without being asked.
- Do not push directly to `main`; use a feature branch and a pull request unless the user says otherwise.
- PR description: what changed, which spec requirements it covers, how it was verified (and what was not verified on macOS).
