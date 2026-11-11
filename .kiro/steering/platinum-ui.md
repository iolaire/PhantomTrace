---
inclusion: fileMatch
fileMatchPattern: "App/**,**/*UI*.swift,**/*View*.swift,**/*Ghost*.swift,docs/screenshots/**"
---

# Platinum Retro Gothic UI

Applies to the AppKit app target (not Core). Spec: Requirements 12-14 and Component 9.

## Look

- Platinum gray `#DDDDDD` background; pinstripe title bar; 1 px beveled frames; square close/zoom boxes.
- Titles in a Chicago-style bitmap font; table cells in Monaco (or a verified open-license substitute). Bundle only fonts and sprites whose licenses are checked and recorded in `docs/`; no third-party trademarks or copyrighted material.
- Kiro ghost mascot sprites: **idle** (idle, scanning), **haunting** (Blocked), **banished** (clean, unmounted). Glow animation only when Reduce Motion is off; otherwise a static sprite.
- Playful but clear copy. Retro styling never replaces a clear statement of what an action does.

## Diagnostic Sheet

- Header: volume name and mount path.
- Table columns in order: Process Name, PID, User, Lock Category, File Path. One row per `LockRecord`.
- File Path truncates in the middle with an ellipsis, keeping the first and last components visible; tooltip shows the full path within 1 s. Display the lossy path but keep `pathBytes` for any copy/export action.
- Exactly four stage buttons in order: Egress Shells, Graceful Request, Banish Locks, Clean Handoff. Disabled when not applicable (and exposed as disabled to VoiceOver). While a stage runs, show progress on its button and disable the others.
- Other-user processes: read-only row with lock icon and visible text explanation; excluded from every stage.
- Plan preview before execution: actions plus skipped locks with denial reasons. Banish Locks lists each process name and pid and needs explicit confirmation. Force unmount lives behind an advanced confirmation.
- Banner for Failed/Partial discovery within 500 ms: description, up to 100 parse warnings (with omitted count), enabled Rescan. Failed actions listed with pid and error kind (up to 500 plus omitted count).
- Protected/non-volume input: alert "not a removable volume" with a single dismiss control within 1 s; no scan results and no eject action.

## Architecture and quality

- `DiagnosticViewModel` (`@MainActor`) owns UI state and maps the discovery state machine to the view; views contain no business logic and never call system adapters.
- Pure presentation logic (middle truncation, ghost state mapping, stage-button enablement) is a pure function in testable code, covered by property tests.
- Accessibility is required, not optional: a non-empty VoiceOver label for every custom control (each stage button and the ghost), full keyboard operation, sufficient contrast, Reduce Motion respected.
- Take screenshots of idle, haunting, and clean states into `docs/screenshots/` for the README and demo.
