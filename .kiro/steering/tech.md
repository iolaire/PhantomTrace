# Tech

## Stack

- Language: Swift
- Build system: SwiftPM (`swift build`, `swift test`)
- UI framework: AppKit (app target only, added by a later feature)
- Volume operations: DiskArbitration
- Platform: macOS only, macOS 27.2.1 (build 26B131) only; other versions are unsupported

## Dependencies

- Zero third-party runtime dependencies are permitted.
- SwiftCheck and SwiftLint are used as test and development tools only.
- SwiftCheck is pinned to an exact version and is a dependency of `PhantomTracePropertyTests` only.

## Quality gates

- `swiftlint --strict` must report zero warnings and zero errors.
- `Scripts/lint-and-test.sh` runs lint first, then `swift test`.
