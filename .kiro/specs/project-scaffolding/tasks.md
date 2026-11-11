# Implementation Plan: Project Scaffolding

## Overview

Create the static scaffold files described in the design: folder structure, a buildable SwiftPM package, repository files, documentation stubs, Kiro steering and hooks, a lint-and-test script, and a committed verification script. No git commands are run (no `git init`, no commits). Files under `.kiro/specs/phantomtrace-volume-lock-forensics/` are never modified. The target platform is macOS only, macOS 27.2.1 (build 26B131) only. The scaffold also meets the Kiroween 2026 rules (see `docs/Hackathon/Rules.md`) through the hackathon tasks below. The design has no Correctness Properties section, so there are no property tests; verification is by smoke checks in `Scripts/verify-scaffold.sh`.

## Tasks

- [ ] 1. Create folder structure and SwiftPM package skeleton
  - [x] 1.1 Create directories and `.gitkeep` files
    - Use create-if-absent semantics (`mkdir -p`); never delete or overwrite existing contents
    - Create `Sources/PhantomTraceCore/{Mounts,Discovery,Resolution,System,Models}`, `Sources/phantomtrace`, `Tests/PhantomTraceCoreTests`, `Tests/PhantomTracePropertyTests`, `Tests/Fixtures`, `docs/screenshots`, `Scripts`, `.kiro/steering`, `.kiro/hooks`
    - Add zero-byte `.gitkeep` to the five Core subdirectories, `Tests/Fixtures`, and `docs/screenshots`
    - Do not create `App`, `.xcodeproj`, `.xcworkspace`, or Quick Action items
    - _Requirements: 1.1, 1.2, 1.3, 1.5, 1.6, 5.4_

  - [-] 1.2 Write `Package.swift`, Core placeholder, CLI, and placeholder tests
    - `Package.swift` as in the design (one library, one executable, two test targets, SwiftCheck pinned exactly and only on `PhantomTracePropertyTests`); confirm the platform declaration for macOS 27.2.1 builds with the installed toolchain and confirm the SwiftCheck version resolves
    - `Sources/PhantomTraceCore/PhantomTraceCore.swift` (Foundation only, `version = "0.0.0"`)
    - `Sources/phantomtrace/main.swift` prints `PhantomTraceCore.version`
    - `PlaceholderTests.swift` and `PlaceholderPropertyTests.swift` (imports SwiftCheck), each with one passing test
    - Write all Swift so it passes `swiftlint --strict` (trailing newline, no trailing whitespace, lines under 120 characters)
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7, 2.8, 2.9, 2.10_

  - [x] 1.3 Add `.swiftlint.yml`
    - Set `included` to `Sources` and `Tests`
    - _Requirements: 4.3, 4.4_

- [x] 2. Add repository files and documentation
  - [x] 2.1 Write `README.md`, `LICENSE`, and `.gitignore`
    - README: pitch, problem, status section containing "scaffolding stage", platform statement (macOS only, macOS 27.2.1 (build 26B131) only), build section with `swift build` then `swift test` in separate fenced blocks, relative links to both specs, MIT statement linking `LICENSE`
    - LICENSE: standard MIT text with `Copyright (c) <current 4-digit year> PhantomTrace`
    - `.gitignore`: `.build/`, `.swiftpm/`, `*.xcodeproj/xcuserdata/`, `DerivedData/`, `.DS_Store`, each on its own line
    - If any of these files already exists with user content, read it first and confirm before replacing
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 4.1, 4.2_

  - [x] 2.2 Write documentation stubs and Scripts README
    - `docs/architecture.md`: first line `# Architecture`, relative link to `../.kiro/specs/phantomtrace-volume-lock-forensics/design.md`
    - `docs/demo-script.md`: first line `# Demo Script`, sentence "The demo length target is at most 3 minutes (180 seconds)."
    - `Scripts/README.md`: states `install-quick-action.sh` is reserved for a later feature and is not present
    - _Requirements: 5.1, 5.2, 5.3, 8.5_

  - [x] 2.3 Write the hackathon submission documents
    - `docs/ProjectOverview.md` (pitch, problem, category, platform scope), `docs/SubmissionChecklist.md` (hard requirements, bonus prizes, judging-criteria map, known gaps), `docs/KiroUsage.md` (one section per Kiro feature, "Evidence to add" where usage is not yet documented)
    - Extend `docs/demo-script.md` with the planned demo flow
    - Extend the README with the hackathon section (category, no pre-existing code, no runtime dependencies, links to the documents)
    - _Requirements: 3.6, 3.7, 3.8, 5.6, 5.7, 5.8, 5.9, 9.3, 9.4, 9.5, 9.6, 9.7_

- [ ] 3. Add Kiro steering, hooks, and helper script
  - [x] 3.1 Write the six steering files
    - `.kiro/steering/{product,tech,structure,safety,testing,hackathon}.md`, concise, derived from the Master_Spec and the Hackathon_Rules, each containing the statements required by Requirement 6 (platform stated as macOS 27.2.1 only)
    - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 6.8_

  - [x] 3.2 Write the three hook files and their scripts
    - `Scripts/hooks/commit-gate.sh` (modes `checks` and `gitignore`; reads stdin JSON, acts only on `git commit`, exit 2 to block) and `Scripts/hooks/lint-on-save.sh` (reads the saved file path from stdin, lints that file only); both mode 755
    - `.kiro/hooks/lint-on-save.json` (PostFileSave, matcher `.*\.swift$`), `pre-commit-check.json` (PreToolUse on `execute_bash`, runs `commit-gate.sh checks`), and `kiro-gitignore-guard.json` (PreToolUse on `execute_bash`, runs `commit-gate.sh gitignore`)
    - Each file: v1 format, one trigger, one command action; hooks never modify or stage files
    - Test the scripts with sample payloads (commit, non-commit, empty payload, missing swiftlint) and live in Kiro
    - Update `docs/KiroUsage.md` (Agent hooks section) and `docs/SubmissionChecklist.md` (remove the "hooks folder empty" gap)
    - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5, 7.6, 7.7, 7.8, 9.7_

  - [~] 3.3 Write `Scripts/lint-and-test.sh`
    - As in the design: `swiftlint --strict` first, then `swift test`, non-zero exit on either failure, set mode 755
    - _Requirements: 8.1, 8.2, 8.3, 8.4_

- [ ] 4. Add and run the verification script
  - [~] 4.1 Write `Scripts/verify-scaffold.sh` (committed, mode 755)
    - Check required directories and `.gitkeep` files, absence of forbidden `App`/Xcode/Quick Action items, `docs/screenshots/.gitkeep` size 0, Package.swift targets and SwiftCheck scope, LICENSE copyright regex, `.gitignore` entries, README phrases and command order, relative links in `README.md` and `docs/*.md` resolve, doc heading and 180-second checks, steering files non-empty with required phrases, three hook files parse as JSON with one trigger and one action, `Scripts/lint-and-test.sh` owner execute bit, hackathon readiness (`.kiro/specs`, `.kiro/steering`, `.kiro/hooks` exist; no `.kiro` entry in `.gitignore`; LICENSE is MIT; Submission_Docs and `hackathon.md` exist and are non-empty; README and steering state macOS 27.2.1 only)
    - Report the file and failed check for each failure; make no changes; exit non-zero on any failure
    - Do not run any git command
    - _Requirements: 1.1, 1.2, 1.3, 1.5, 2.1, 2.9, 3.3, 3.5, 4.1, 4.2, 4.6, 5.1, 5.2, 5.3, 5.4, 5.5, 6.1, 6.7, 7.1, 7.8, 8.1, 9.1, 9.2, 9.3, 9.9_

  - [~] 4.2 Run the verification and build checks
    - Run `Scripts/verify-scaffold.sh`, `swift build`, `swift test`, `swift run phantomtrace` (expect exactly `0.0.0\n` on stdout, empty stderr), and `swiftlint --strict`; fix any failures
    - Run `Scripts/lint-and-test.sh` on the clean tree (expect exit 0)
    - Confirm the master spec files are unchanged and no `.git` directory was created by this work
    - _Requirements: 1.4, 2.4, 2.7, 2.8, 4.4, 8.4, 8.6, 8.7_

- [~] 5. Final checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 6. Manual hackathon submission checks (not automatable)
  - Confirm on GitHub that the repository is public and the MIT license shows in the About section
  - Confirm `.kiro/` is committed and pushed
  - Record the demo video (under 3 minutes, public on YouTube, no copyrighted music or trademarks) and add the link to the submission
  - Fill every "Evidence to add" line in `docs/KiroUsage.md` with real usage, and tick `docs/SubmissionChecklist.md`
  - Submit before December 4, 2026, 2:00 pm Pacific Time
  - _Requirements: 9.1, 9.2, 9.7, 9.8_

## Notes

- This task list contains no git commands; scaffolding does not run `git init` or commit.
- The design has no Correctness Properties section, so no property-based test tasks are included.
- The verification script is committed as `Scripts/verify-scaffold.sh` because it is small and reusable.

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1"] },
    { "id": 1, "tasks": ["1.2", "1.3", "2.1", "2.2", "2.3", "3.1", "3.2", "3.3"] },
    { "id": 2, "tasks": ["4.1"] },
    { "id": 3, "tasks": ["4.2"] }
  ]
}
```
