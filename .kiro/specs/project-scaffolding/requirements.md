# Requirements Document

## Introduction

This feature sets up the initial project foundation for PhantomTrace, a macOS utility written in Swift that is macOS only and targets macOS "Golden Gate" 27.2.1 (build 26B131) only. Every other macOS version, older or newer, and every other operating system is out of scope because it cannot be tested. The scaffolding creates the repository structure, an empty Swift Package Manager skeleton, project documentation, license, lint configuration, Kiro steering files, Kiro hooks, and a scripts folder. It also makes the repository ready for the Kiroween 2026 hackathon (Resurrection category): the Rules require a public GitHub repository with a detectable open source license, a `/.kiro` directory that is not gitignored, runnable instructions, and a write-up of Kiro usage, and the judging criteria reward visible use of specs, steering, hooks, and property-based testing. It contains no feature logic: no mount resolution, lsof parsing, or UI. The layout follows the "Project Layout" section of the master spec `.kiro/specs/phantomtrace-volume-lock-forensics/`, which this feature SHALL NOT modify. The Xcode app target and the Quick Action are out of scope.

## Glossary

- **Scaffold**: The set of directories and files created by this feature.
- **Master_Spec**: The existing spec at `.kiro/specs/phantomtrace-volume-lock-forensics/`.
- **Package**: The SwiftPM package defined by `Package.swift` at the repository root.
- **Core_Library**: The SwiftPM library target `PhantomTraceCore`.
- **CLI_Target**: The SwiftPM executable target `phantomtrace`.
- **Test_Targets**: The SwiftPM test targets `PhantomTraceCoreTests` and `PhantomTracePropertyTests`.
- **Steering_Files**: Markdown files in `.kiro/steering/`.
- **Hook_Files**: JSON files in `.kiro/hooks/`.
- **Lint_Config**: The `.swiftlint.yml` file at the repository root.
- **Hackathon_Rules**: The Kiroween 2026 official rules and FAQ in `docs/Hackathon/Rules.md` and `docs/Hackathon/Faq.md`.
- **Submission_Docs**: `docs/ProjectOverview.md`, `docs/SubmissionChecklist.md`, and `docs/KiroUsage.md`.

## Requirements

### Requirement 1: Repository Folder Structure

**User Story:** As a developer, I want the repository folders from the master design to exist, so that later features have a defined place to live.

#### Acceptance Criteria

1. THE Scaffold SHALL contain at least these nine directories at these repository-root-relative paths: `Sources/PhantomTraceCore`, `Sources/phantomtrace`, `Tests/PhantomTraceCoreTests`, `Tests/PhantomTracePropertyTests`, `Tests/Fixtures`, `docs`, `Scripts`, `.kiro/steering`, and `.kiro/hooks`.
2. THE Scaffold SHALL contain at least these five subdirectories directly under `Sources/PhantomTraceCore`: `Mounts`, `Discovery`, `Resolution`, `System`, and `Models`.
3. WHILE a directory created by criterion 1 or 2 contains no source files and no subdirectories other than those required by criteria 1 and 2, THE Scaffold SHALL keep a zero-byte `.gitkeep` file in that directory so that Git tracks it.
4. THE Scaffold SHALL leave every file under `.kiro/specs/phantomtrace-volume-lock-forensics/` unmodified, with byte-identical contents, unchanged file names, and no files added or removed, relative to the state before the Scaffold was created.
5. THE Scaffold SHALL contain zero directories named `App`, zero files or directories with the `.xcodeproj` or `.xcworkspace` extension, and zero Quick Action files (no `.workflow` bundles and no files or directories with the `.action` extension).
6. IF a directory required by criterion 1 or 2 already exists, THEN THE Scaffold SHALL retain all existing contents of that directory without deletion or modification and SHALL NOT report an error.

### Requirement 2: SwiftPM Package Skeleton

**User Story:** As a developer, I want an empty but buildable Swift package, so that feature work can start from a green build.

#### Acceptance Criteria

1. THE Package SHALL declare exactly one library target named Core_Library, exactly one executable target named CLI_Target, and the Test_Targets.
2. THE Package SHALL declare a minimum platform of macOS 27.2.1 (build 26B131) or the lowest macOS version identifier that SwiftPM supports and that is greater than or equal to that release, and SHALL declare no support for earlier macOS versions. Because SwiftPM can only express a minimum version, the exact-version scope (macOS 27.2.1 only) SHALL be stated in the README, `docs/ProjectOverview.md`, and the `product.md` and `tech.md` steering files.
3. THE Core_Library SHALL import only Foundation and SHALL contain no feature logic beyond one placeholder public declaration that exposes a version string of 1 to 32 characters.
4. WHEN CLI_Target is invoked with no arguments, THE CLI_Target SHALL print the placeholder version string followed by a single newline to standard output, print nothing to standard error, and exit with status 0.
5. THE CLI_Target SHALL depend on Core_Library and obtain the version string only from the Core_Library placeholder declaration.
6. THE Test_Targets SHALL each contain at least one placeholder test that passes.
7. WHEN `swift build` is run at the repository root on macOS 27.2.1, THE Package SHALL build with zero errors and exit with status 0.
8. WHEN `swift test` is run at the repository root on macOS 27.2.1, THE Package SHALL execute every placeholder test, report zero failures, and exit with status 0.
9. THE Package SHALL declare no third-party runtime dependency, and SHALL declare SwiftCheck only as a dependency of `PhantomTracePropertyTests`.
10. IF `swift build` or `swift test` fails to resolve a declared dependency, THEN THE Package SHALL cause the command to exit with a non-zero status and report an error identifying the unresolved dependency, leaving the source files unmodified.

### Requirement 3: README

**User Story:** As a visitor, I want a README, so that I can understand the project and build it.

#### Acceptance Criteria

1. THE Scaffold SHALL contain a `README.md` at the repository root that includes an elevator pitch of 1 to 3 sentences, a status section containing the phrase "scaffolding stage" stating that the project is at the scaffolding stage, and a supported-platform statement saying PhantomTrace is macOS only and targets macOS 27.2.1 (build 26B131) only, with every other macOS version and operating system stated as unsupported.
2. THE `README.md` SHALL include a build section that lists the commands `swift build` and `swift test`, each in a fenced code block, with `swift build` listed before `swift test`.
3. THE `README.md` SHALL include a relative link to the Master_Spec and a relative link to the `project-scaffolding` spec, each of which resolves to an existing file or directory in the repository.
4. THE `README.md` SHALL state that the project is released under the MIT License and SHALL include a relative link to `LICENSE` that resolves to an existing file at the repository root.
5. IF a relative link in the `README.md` points to a path that does not exist in the repository, THEN THE Scaffold validation SHALL report a failure identifying the broken link.
6. THE `README.md` SHALL state the hackathon name (Kiroween 2026) and category (Resurrection), SHALL link to the Submission_Docs, and SHALL state whether any pre-existing code or third-party runtime dependency is used (the Rules require disclosure of pre-existing work).
7. THE `README.md` SHALL describe the problem solved (Finder's generic eject failure), the three lock types, and the graduated resolution pipeline, consistent with `docs/ProjectOverview.md`, so that a judge reading only the README understands the real problem and audience.
8. THE `README.md` SHALL contain build and test instructions sufficient for a judge to run the project on the target platform from a fresh clone, and SHALL be updated to include run instructions when a runnable app exists.

### Requirement 4: License, Ignore Rules, and Lint Configuration

**User Story:** As a maintainer, I want license, ignore, and lint files in place, so that the repository is publishable and consistent.

#### Acceptance Criteria

1. THE Scaffold SHALL contain a `LICENSE` file at the repository root with the standard MIT License text and a copyright line in the format `Copyright (c) <YYYY> PhantomTrace`, where `<YYYY>` is a four-digit calendar year. The text SHALL be the unmodified standard MIT text so that GitHub detects the license and shows it in the repository About section, as the Hackathon_Rules require.
2. THE Scaffold SHALL contain a `.gitignore` file at the repository root with one separate line entry for each of `.build/`, `.swiftpm/`, `*.xcodeproj/xcuserdata/`, `DerivedData/`, and `.DS_Store`. THE `.gitignore` SHALL NOT contain any entry that matches `.kiro`, `.kiro/`, or any path beneath it, because the Hackathon_Rules state that ignoring `/.kiro` can disqualify the submission.
3. THE Scaffold SHALL contain Lint_Config at the repository root that sets `included` to `Sources` and `Tests`.
4. WHEN `swiftlint --strict` is run at the repository root on macOS 27.2.1 (build 26B131), THE Scaffold SHALL exit with code 0 and report zero warnings and zero errors.
5. IF `swiftlint --strict` reports one or more violations, THEN THE Scaffold SHALL exit with a non-zero code and list each violation with its file path, line number, and rule name.
6. IF the `LICENSE` file, `.gitignore` file, or Lint_Config is missing from the repository root, THEN THE Scaffold SHALL be considered non-conforming and the check for this requirement SHALL fail.

### Requirement 5: Documentation Stubs

**User Story:** As a contributor, I want documentation placeholders, so that architecture notes and demo material have a known location.

#### Acceptance Criteria

1. THE Scaffold SHALL contain the files `docs/architecture.md`, `docs/demo-script.md`, `docs/screenshots/.gitkeep`, `docs/ProjectOverview.md`, `docs/SubmissionChecklist.md`, and `docs/KiroUsage.md`.
2. THE `docs/architecture.md` file SHALL contain a first-line Markdown level-1 heading with a non-empty title and at least one relative Markdown link (a link target that does not begin with a URL scheme or `/`) whose target path resolves to the existing Master_Spec design document file.
3. THE `docs/demo-script.md` file SHALL contain a first-line Markdown level-1 heading with a non-empty title and a sentence stating that the demo length target is at most 3 minutes (180 seconds).
4. THE `docs/screenshots/.gitkeep` file SHALL have a size of 0 bytes.
5. IF a documentation file listed in criterion 1 is missing or fails the content checks in criteria 2 to 4 and 6 to 9, THEN THE Scaffold validation SHALL report a failure that names the file and the failed check.
6. THE `docs/demo-script.md` file SHALL list the planned demo flow (locked drive, Finder failing to eject, PhantomTrace revealing the hidden process, safe eject), because the Hackathon_Rules require a demo video under 3 minutes that shows the project working end to end on the target device, and the Presentation criterion rewards a clear, memorable pitch.
7. THE `docs/ProjectOverview.md` file SHALL state the elevator pitch, the problem and affected audience, the target category, the macOS-only and 27.2.1-only platform scope, and the Kiro features used, so that it can be reused as the text description in the submission form.
8. THE `docs/SubmissionChecklist.md` file SHALL list the hard submission requirements from the Hackathon_Rules (public GitHub repository, detectable open source license, `/.kiro` directory present and not gitignored, demo video under 3 minutes on YouTube, working app with judge instructions, English-only materials, submission deadline of December 4, 2026 at 2:00 pm Pacific Time), the bonus prizes pursued, and a mapping of the five equally weighted judging criteria to project artifacts.
9. THE `docs/KiroUsage.md` file SHALL contain one section for each Kiro feature the Hackathon_Rules ask judges to assess (specs, steering, agent hooks, property-based testing, and the IDE/CLI/Web/Crew, custom agents, MCP, and powers questions), SHALL cite only usage that actually occurred, and SHALL mark undocumented evidence as "Evidence to add" rather than stating unverified claims.

### Requirement 6: Steering Files

**User Story:** As a developer working with Kiro, I want steering files derived from the master spec, so that Kiro follows project conventions.

#### Acceptance Criteria

1. THE Scaffold SHALL contain at least six Steering_Files, named `product.md`, `tech.md`, `structure.md`, `safety.md`, `testing.md`, and `hackathon.md`, in `.kiro/steering/`, and each file SHALL be non-empty UTF-8 Markdown text.
2. THE `product.md` file SHALL state the mission "identify which processes prevent a volume from ejecting", the Resurrection hackathon theme, and the platform target as macOS only and macOS 27.2.1 (build 26B131) only, with every other macOS version stated as out of scope.
3. THE `tech.md` file SHALL state the use of Swift, SwiftPM, AppKit, and DiskArbitration, SHALL state that zero third-party runtime dependencies are permitted, and SHALL state that SwiftCheck and SwiftLint are used as test and development tools only.
4. THE `structure.md` file SHALL state the layering rule that Core_Library imports no AppKit module, and SHALL list every directory convention defined in Requirement 1.
5. THE `safety.md` file SHALL state all of the following rules: subprocesses are launched with argument arrays and without a shell; the Safety_Policy is the single approval path for every action; protected processes are never sent a signal; no network access and no telemetry are permitted.
6. THE `testing.md` file SHALL state all of the following property-based testing conventions: SwiftCheck runs at least 500 iterations per property in CI; every parser and every printer has a round-trip property; every system effect is accessed through a mock protocol.
7. IF any of the six Steering_Files is missing from `.kiro/steering/`, or lacks a statement required by criteria 2 to 6 and 8, THEN THE Scaffold validation SHALL report a failure that names the file and the missing statement, and SHALL leave the existing files unchanged.
8. THE `hackathon.md` file SHALL state the Resurrection category and the submission deadline, that `.kiro/` is never added to `.gitignore`, that the repository stays public on GitHub with the MIT license, that the demo video is under 3 minutes with no copyrighted material, that all materials are in English, and that `docs/KiroUsage.md` is kept current with real evidence.

### Requirement 7: Kiro Hooks

**User Story:** As a maintainer, I want hooks that run lint and tests, so that code quality is enforced automatically.

#### Acceptance Criteria

1. THE Scaffold SHALL contain four Hook_Files named `swiftlint-pre-commit.json`, `tests-pre-commit.json`, `lint-on-save.json`, and `kiro-gitignore-guard.json` in `.kiro/hooks/`. Agent hooks are a Technological Implementation item in the Hackathon_Rules, so the hooks SHALL be committed and described in `docs/KiroUsage.md`.
2. WHEN a `git commit` command is about to run, THE `swiftlint-pre-commit.json` hook SHALL run `swiftlint --strict` from the repository root.
3. IF `swiftlint --strict` exits with a non-zero status, THEN THE `swiftlint-pre-commit.json` hook SHALL block the commit, leave the working tree and staged changes unmodified, and present the SwiftLint output to the user.
4. WHEN a `git commit` command is about to run, THE `tests-pre-commit.json` hook SHALL run `swift test` from the repository root.
5. IF `swift test` exits with a non-zero status, THEN THE `tests-pre-commit.json` hook SHALL block the commit, leave the working tree and staged changes unmodified, and present the test output to the user.
6. WHEN a file matching `*.swift` is saved, THE `lint-on-save.json` hook SHALL run SwiftLint on only that file and present any violations to the user.
7. IF SwiftLint is not installed or cannot be executed, THEN THE `swiftlint-pre-commit.json` hook SHALL block the commit and present an error message indicating that SwiftLint is unavailable.
8. THE Hook_Files SHALL each parse as valid JSON and conform to the Kiro hook file format, with each file defining one trigger event and one action.
9. WHEN a `git commit` command is about to run, THE `kiro-gitignore-guard.json` hook SHALL check `.gitignore` for any entry that matches `.kiro`, and IF one is found, THEN THE hook SHALL block the commit with exit status 2 and a message explaining that ignoring `.kiro` can disqualify the hackathon submission.

### Requirement 8: Scripts Folder and Git Policy

**User Story:** As a maintainer, I want a scripts placeholder and a safe git policy, so that helper scripts have a home and history is created only when I choose.

#### Acceptance Criteria

1. THE Scaffold SHALL contain `Scripts/lint-and-test.sh` that runs `swiftlint --strict` first and `swift test` second, in that order, and is executable by the file owner (owner execute permission bit set).
2. IF `swiftlint --strict` exits with a non-zero status, THEN THE `Scripts/lint-and-test.sh` script SHALL NOT run `swift test`, SHALL print the SwiftLint output to the terminal, and SHALL exit with a non-zero status.
3. IF `swift test` exits with a non-zero status, THEN THE `Scripts/lint-and-test.sh` script SHALL print the test output to the terminal and SHALL exit with a non-zero status.
4. WHEN both `swiftlint --strict` and `swift test` exit with status 0, THE `Scripts/lint-and-test.sh` script SHALL exit with status 0.
5. THE Scaffold SHALL contain `Scripts/README.md` stating that `install-quick-action.sh` is reserved for a later feature and is not present in the Scaffold.
6. WHEN scaffolding is performed, THE Scaffold SHALL NOT run `git init`, create a git commit, or modify git configuration (global, system, or repository-local) unless the user explicitly requests it in the same session.
7. WHEN scaffolding completes, THE Scaffold SHALL leave the project directory without a `.git` directory, unless one existed before scaffolding began or the user explicitly requested `git init`.

### Requirement 9: Hackathon Submission Readiness

**User Story:** As a submitter, I want the repository to satisfy the Kiroween 2026 rules and judging criteria, so that the entry is eligible and scores well.

#### Acceptance Criteria

1. THE Scaffold SHALL contain a `/.kiro` directory at the repository root holding `specs`, `steering`, and `hooks`, and THE `.gitignore` SHALL NOT exclude it (Requirement 4.2).
2. THE Scaffold SHALL contain a `LICENSE` file with an OSI-approved license (MIT) at the repository root so that GitHub shows the license in the About section.
3. THE Scaffold SHALL contain the Submission_Docs and a `.kiro/steering/hackathon.md` file that restate the rules a contributor must not break (Requirement 6.8).
4. THE Scaffold SHALL declare zero third-party runtime dependencies, so no third-party license or terms apply to the shipped app, and SHALL record SwiftCheck and SwiftLint as development tools only.
5. THE Scaffold SHALL NOT include copyrighted images, fonts, music, or third-party trademarks as assets. Historical tool names (for example "What's Keeping Me?") MAY appear in text as references only.
6. THE Scaffold SHALL keep all documentation, comments, and file names in English.
7. THE `docs/SubmissionChecklist.md` file SHALL list each known gap that blocks submission (empty hooks folder, missing feature code, placeholder docs, missing screenshots), and WHEN a gap is closed THE checklist SHALL be updated in the same change.
8. THE repository history SHALL be built up through regular commits made after the Submission Period start (October 30, 2026), so that the work is visibly new, as the Hackathon_Rules require. This criterion is advisory; the Scaffold itself SHALL NOT create commits (Requirement 8.6).
9. WHEN the Scaffold validation runs, THE validation SHALL check criteria 1 to 3 and 6 of this requirement and SHALL report each failure with the file and the failed check.
