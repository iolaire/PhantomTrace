---
inclusion: always
---

# Documentation

- Keep `README.md` truthful about status: say what exists, never what is planned as if done. Update the Status section and Build/Run instructions as features land.
- `docs/KiroUsage.md` records real Kiro usage only. Add evidence (what a steering rule changed, a bug property testing found, what a hook caught) when it happens; mark the rest "Evidence to add". Update the steering file list there when steering files change.
- `docs/SubmissionChecklist.md`: tick items only when actually done; keep "Known gaps" current.
- `docs/architecture.md` should summarize and link to the master design instead of duplicating it; replace the placeholder once the app exists. `docs/demo-script.md` stays at or under 180 seconds of planned content.
- Specs: `.kiro/specs/<feature>/` with `requirements.md`, `design.md`, `tasks.md`. Requirements use EARS-style "THE X SHALL" criteria and numbered references; correctness properties cite the requirements they validate. If implementation reveals a spec error, propose a spec change rather than diverging silently.
- Use plain ASCII punctuation in docs where practical, English only, relative links that resolve, and no em-dash overuse.
- Third-party assets (fonts, sprites, icons) get license notes in `docs/`; pre-existing code or templates must be disclosed in the README.
- When creating or changing steering, hooks, or specs, tell the user the file paths changed.

## Project log (`docs/ProjectLog.md`)

- Single record of work, tools, and decisions. Update it in the same commit as the change.
- Work log: one row per meaningful change with date, the Kiro surface used (Kiro IDE, CLI, Web, Crew, Mobile, Unknown, or Not recorded; run `Scripts/kiro-surface.sh --details` to detect it, and use `PHANTOMTRACE_KIRO_SURFACE` to override), spec refs, and how it was verified (say "not verified on macOS" when true).
- Tools: add or change a row whenever a dependency, tool, or version changes.
- Decisions: add a numbered `D-NNN` entry (context, decision, consequences) for any choice that affects architecture, dependencies, safety, or scope. Never edit history; mark old entries Superseded and add a new one.
- `.kiro/hooks/project-log-check.json` blocks commits that touch `Sources/`, `Tests/`, `Package.swift`, `Scripts/`, `App/`, or `.kiro/{specs,steering,hooks}` without `docs/ProjectLog.md` staged, and rejects new work-log rows with a missing or invalid Kiro surface. Use `[skip-log]` in the commit message only for trivial changes (typos, formatting).
