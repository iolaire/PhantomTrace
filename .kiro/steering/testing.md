# Testing

- Unit tests live in `Tests/PhantomTraceCoreTests`; property tests live in `Tests/PhantomTracePropertyTests`.
- SwiftCheck runs at least 500 iterations per property in CI.
- Every parser and every printer has a round-trip property.
- Every system effect (processes, mounts, signals, unmount) is accessed through a mock protocol so tests never touch the real system.
- Tests must pass `swiftlint --strict`.
- Run `swift test`, or `Scripts/lint-and-test.sh` for lint plus tests.
