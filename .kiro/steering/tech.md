---
inclusion: always
---

# Tech

## Stack

- Language: Swift 6 (`swift-tools-version: 6.0`), strict concurrency on.
- Build: SwiftPM (`swift build`, `swift test`). The AppKit app target and Xcode project arrive in a later feature and depend on the local package.
- UI: AppKit, app target only. Never SwiftUI-first and never in Core.
- Volume operations: DiskArbitration (`DADiskUnmount`), with `/usr/sbin/diskutil unmount` as the single fallback.
- System tools used at runtime: `/usr/sbin/lsof`, `/usr/bin/fuser` (cross-check), `/usr/sbin/diskutil`, `/usr/bin/hdiutil`. Always absolute paths.
- Logging: `OSLog` (`Logger`). No `print` in Core.
- Platform: deployment target macOS 15.0+, tested on macOS 27.2.1 (build 26B131) only. See `macos-platform.md`.

## Dependencies

- Zero third-party runtime dependencies. Do not add one without an explicit decision recorded in the spec.
- Test-only: the property-based testing library declared in `Package.swift` (currently `swift-property-based` 2.0.1, product `PropertyBased`), a dependency of `PhantomTracePropertyTests` only, pinned with `exact:`.
- Dev-only: SwiftLint (installed via Homebrew, not a package dependency).
- Source of truth for the test library is `Package.swift`. The master/scaffolding specs and older docs say "SwiftCheck"; treat that as meaning "the pinned property-based testing library" and update docs when touching them. Do not add SwiftCheck unless the user decides to switch.

## Concurrency

- Discovery, rescans, and subprocesses run off the main actor; results are delivered with `async`/`await` or `AsyncStream`. The main actor is never blocked more than 100 ms by a scan.
- Public Core types are `Sendable`. Prefer value types (`struct`/`enum`). Use `actor` for mutable shared state (for example the escalation history). No `@unchecked Sendable` without a comment explaining why it is safe.
- All UI types are `@MainActor`.

## Quality gates

- `swiftlint --strict`: zero warnings and zero errors.
- `swift build` and `swift test` pass before every commit.
- `Scripts/lint-and-test.sh` runs lint, then `swift test`. Hooks in `.kiro/hooks/` run the same checks.
- Do not weaken lint rules or disable them inline to get a green build; fix the code. Any `swiftlint:disable` needs a one-line reason.

See `swift-conventions.md` for code style and `testing.md` for test rules.
