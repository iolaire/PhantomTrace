---
inclusion: always
---

# Structure

## Layering rule

`PhantomTraceCore` imports no AppKit (or SwiftUI/UIKit). It imports Foundation, plus Darwin, DiskArbitration, and OSLog only inside live adapters under `System/`. All UI code lives outside Core. Dependencies point one way: App/CLI -> Core. Core never depends on UI, the CLI, or the app.

Within Core:

- `Models` is the base: value types and errors; imports nothing else in Core.
- `Mounts`, `Discovery`, `Resolution` depend on `Models` and on **protocols** from `System`, never on live adapters.
- Live adapters in `System` implement the protocols; they are wired together only at the composition root (CLI `main.swift`, app `AppDelegate`).
- Pure logic (parser, printer, classifier, safety policy, plan building, path matching, URL parsing) must not perform I/O.

## Directory conventions

- `Sources/PhantomTraceCore/Mounts`: `MountInfo`, `MountResolver`
- `Sources/PhantomTraceCore/Discovery`: `LsofParser`, `LsofPrinter`, `LockDiscoveryEngine`, `LockClassifier`
- `Sources/PhantomTraceCore/Resolution`: `ResolutionPipeline`, `SafetyPolicy`, `ShellEgress`
- `Sources/PhantomTraceCore/System`: `ProcessRunner`, `SignalSender`, `AppQuitter`, `Unmounter`, `FileSystemProbe` (protocols + live implementations)
- `Sources/PhantomTraceCore/Models`: `LockRecord`, `RawLsofRecord`, stages, plans, outcomes, `PhantomTraceError`
- `Sources/phantomtrace`: CLI executable (thin: argument parsing, output, exit codes)
- `App/` (later): AppKit app, `QuickAction/`, `Info.plist`, entitlements
- `Tests/PhantomTraceCoreTests`: unit tests with mocks
- `Tests/PhantomTracePropertyTests`: property tests
- `Tests/Fixtures`: captured `lsof` outputs and minimized counterexamples
- `docs`: documentation; `docs/screenshots` holds screenshots
- `Scripts`: helper scripts (`lint-and-test.sh`, later `install-quick-action.sh`)
- `.kiro/specs`, `.kiro/steering`, `.kiro/hooks`: Kiro artifacts, always committed

## File conventions

- One primary type per file, file named after the type. Extensions go in `Type+Topic.swift`.
- Protocol and its live implementation live in separate files (`ProcessRunning.swift`, `LiveProcessRunner.swift`).
- Tests mirror the source layout and are named `<Type>Tests.swift` / `<Type>PropertyTests.swift`.
- Empty directories keep a zero-byte `.gitkeep`; remove it when real content arrives.
- Do not create `App/`, an Xcode project, or the Quick Action unless the task is the app feature.

## Naming

Use the spec's vocabulary exactly (`LockRecord`, `ProcessRole`, `SafetyPolicy`, `StageOutcome`, ...). Spec glossary terms use `Snake_Case` in prose; Swift types use `UpperCamelCase` of the same words.
