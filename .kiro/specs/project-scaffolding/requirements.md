# Requirements Document

## Introduction

This feature sets up the initial project foundation for PhantomTrace, a macOS utility written in Swift that targets macOS "Golden Gate" (27.2.1, build 26B131) or later. Earlier macOS versions are out of scope because they cannot be tested. The scaffolding creates the repository structure, an empty Swift Package Manager skeleton, project documentation, license, lint configuration, Kiro steering files, Kiro hooks, and a scripts folder. It contains no feature logic: no mount resolution, lsof parsing, or UI. The layout follows the "Project Layout" section of the master spec `.kiro/specs/phantomtrace-volume-lock-forensics/`, which this feature SHALL NOT modify. The Xcode app target and the Quick Action are out of scope.

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
2. THE Package SHALL declare a minimum platform of macOS 27.2.1 (build 26B131) or the lowest macOS version identifier that SwiftPM supports and that is greater than or equal to that release, and SHALL declare no support for earlier macOS versions.
3. THE Core_Library SHALL import only Foundation and SHALL contain no feature logic beyond one placeholder public declaration that exposes a version string of 1 to 32 characters.
4. WHEN CLI_Target is invoked with no arguments, THE CLI_Target SHALL print the placeholder version string followed by a single newline to standard output, print nothing to standard error, and exit with status 0.
5. THE CLI_Target SHALL depend on Core_Library and obtain the version string only from the Core_Library placeholder declaration.
6. THE Test_Targets SHALL each contain at least one placeholder test that passes.
7. WHEN `swift build` is run at the repository root on macOS 27.2.1 or later, THE Package SHALL build with zero errors and exit with status 0.
8. WHEN `swift test` is run at the repository root on macOS 27.2.1 or later, THE Package SHALL execute every placeholder test, report zero failures, and exit with status 0.
9. THE Package SHALL declare no third-party runtime dependency, and SHALL declare SwiftCheck only as a dependency of `PhantomTracePropertyTests`.
10. IF `swift build` or `swift test` fails to resolve a declared dependency, THEN THE Package SHALL cause the command to exit with a non-zero status and report an error identifying the unresolved dependency, leaving the source files unmodified.

### Requirement 3: README

**User Story:** As a visitor, I want a README, so that I can understand the project and build it.

#### Acceptance Criteria

1. THE Scaffold SHALL contain a `README.md` at the repository root that includes an elevator pitch of 1 to 3 sentences, a status section containing the phrase "scaffolding stage" stating that the project is at the scaffolding stage, and a supported-platform statement naming macOS 27.2.1 (build 26B131) or later, with older versions stated as unsupported.
2. THE `README.md` SHALL include a build section that lists the commands `swift build` and `swift test`, each in a fenced code block, with `swift build` listed before `swift test`.
3. THE `README.md` SHALL include a relative link to the Master_Spec and a relative link to the `project-scaffolding` spec, each of which resolves to an existing file or directory in the repository.
4. THE `README.md` SHALL state that the project is released under the MIT License and SHALL include a relative link to `LICENSE` that resolves to an existing file at the repository root.
5. IF a relative link in the `README.md` points to a path that does not exist in the repository, THEN THE Scaffold validation SHALL report a failure identifying the broken link.

### Requirement 4: License, Ignore Rules, and Lint Configuration

**User Story:** As a maintainer, I want license, ignore, and lint files in place, so that the repository is publishable and consistent.

#### Acceptance Criteria

1. THE Scaffold SHALL contain a `LICENSE` file at the repository root with the standard MIT License text and a copyright line in the format `Copyright (c) <YYYY> PhantomTrace`, where `<YYYY>` is a four-digit calendar year.
2. THE Scaffold SHALL contain a `.gitignore` file at the repository root with one separate line entry for each of `.build/`, `.swiftpm/`, `*.xcodeproj/xcuserdata/`, `DerivedData/`, and `.DS_Store`.
3. THE Scaffold SHALL contain Lint_Config at the repository root that sets `included` to `Sources` and `Tests`.
4. WHEN `swiftlint --strict` is run at the repository root on macOS 27.2.1 (build 26B131) or later, THE Scaffold SHALL exit with code 0 and report zero warnings and zero errors.
5. IF `swiftlint --strict` reports one or more violations, THEN THE Scaffold SHALL exit with a non-zero code and list each violation with its file path, line number, and rule name.
6. IF the `LICENSE` file, `.gitignore` file, or Lint_Config is missing from the repository root, THEN THE Scaffold SHALL be considered non-conforming and the check for this requirement SHALL fail.

### Requirement 5: Documentation Stubs

**User Story:** As a contributor, I want documentation placeholders, so that architecture notes and demo material have a known location.

#### Acceptance Criteria

1. THE Scaffold SHALL contain the files `docs/architecture.md`, `docs/demo-script.md`, and `docs/screenshots/.gitkeep`.
2. THE `docs/architecture.md` file SHALL contain a first-line Markdown level-1 heading with a non-empty title and at least one relative Markdown link (a link target that does not begin with a URL scheme or `/`) whose target path resolves to the existing Master_Spec design document file.
3. THE `docs/demo-script.md` file SHALL contain a first-line Markdown level-1 heading with a non-empty title and a sentence stating that the demo length target is at most 3 minutes (180 seconds).
4. THE `docs/screenshots/.gitkeep` file SHALL have a size of 0 bytes.
5. IF a documentation file listed in criterion 1 is missing or fails the content checks in criteria 2 to 4, THEN THE Scaffold validation SHALL report a failure that names the file and the failed check.

### Requirement 6: Steering Files

**User Story:** As a developer working with Kiro, I want steering files derived from the master spec, so that Kiro follows project conventions.

#### Acceptance Criteria

1. THE Scaffold SHALL contain at least five Steering_Files, named `product.md`, `tech.md`, `structure.md`, `safety.md`, and `testing.md`, in `.kiro/steering/`, and each file SHALL be non-empty UTF-8 Markdown text.
2. THE `product.md` file SHALL state the mission "identify which processes prevent a volume from ejecting", the Resurrection hackathon theme, and the platform target macOS 27.2.1 (build 26B131) or later, with older versions stated as out of scope.
3. THE `tech.md` file SHALL state the use of Swift, SwiftPM, AppKit, and DiskArbitration, SHALL state that zero third-party runtime dependencies are permitted, and SHALL state that SwiftCheck and SwiftLint are used as test and development tools only.
4. THE `structure.md` file SHALL state the layering rule that Core_Library imports no AppKit module, and SHALL list every directory convention defined in Requirement 1.
5. THE `safety.md` file SHALL state all of the following rules: subprocesses are launched with argument arrays and without a shell; the Safety_Policy is the single approval path for every action; protected processes are never sent a signal; no network access and no telemetry are permitted.
6. THE `testing.md` file SHALL state all of the following property-based testing conventions: SwiftCheck runs at least 500 iterations per property in CI; every parser and every printer has a round-trip property; every system effect is accessed through a mock protocol.
7. IF any of the five Steering_Files is missing from `.kiro/steering/`, or lacks a statement required by criteria 2 to 6, THEN THE Scaffold validation SHALL report a failure that names the file and the missing statement, and SHALL leave the existing files unchanged.

### Requirement 7: Kiro Hooks

**User Story:** As a maintainer, I want hooks that run lint and tests, so that code quality is enforced automatically.

#### Acceptance Criteria

1. THE Scaffold SHALL contain three Hook_Files named `swiftlint-pre-commit.json`, `tests-pre-commit.json`, and `lint-on-save.json` in `.kiro/hooks/`.
2. WHEN a `git commit` command is about to run, THE `swiftlint-pre-commit.json` hook SHALL run `swiftlint --strict` from the repository root.
3. IF `swiftlint --strict` exits with a non-zero status, THEN THE `swiftlint-pre-commit.json` hook SHALL block the commit, leave the working tree and staged changes unmodified, and present the SwiftLint output to the user.
4. WHEN a `git commit` command is about to run, THE `tests-pre-commit.json` hook SHALL run `swift test` from the repository root.
5. IF `swift test` exits with a non-zero status, THEN THE `tests-pre-commit.json` hook SHALL block the commit, leave the working tree and staged changes unmodified, and present the test output to the user.
6. WHEN a file matching `*.swift` is saved, THE `lint-on-save.json` hook SHALL run SwiftLint on only that file and present any violations to the user.
7. IF SwiftLint is not installed or cannot be executed, THEN THE `swiftlint-pre-commit.json` hook SHALL block the commit and present an error message indicating that SwiftLint is unavailable.
8. THE Hook_Files SHALL each parse as valid JSON and conform to the Kiro hook file format, with each file defining one trigger event and one action.

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
