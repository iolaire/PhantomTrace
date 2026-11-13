---
inclusion: always
---

# Testing

Frameworks: Swift Testing (`import Testing`, `@Test`, `#expect`) for unit and property tests, as in the existing placeholders. Property-based tests use the library pinned in `Package.swift` (`PropertyBased`; see `tech.md`). XCTest is not available on Command Line Tools installs, so do not use it.

## Layout

- Unit tests: `Tests/PhantomTraceCoreTests`, with mock adapters.
- Property tests: `Tests/PhantomTracePropertyTests`.
- Fixtures: `Tests/Fixtures` (hand-written and generated `lsof -F` samples, not yet captured from a real run; replace or add real captures when available: spaces, newlines, Unicode, `\x` escapes, non-UTF8 bytes, deleted files, symlinked mounts, `/Volumes` firmlinks). Save minimized property counterexamples there as regression fixtures.
- Test files mirror source layout: `<Type>Tests.swift`, `<Type>PropertyTests.swift`.

## Rules

- Only write tests when asked or when the task is a feature whose spec calls for them; never ship tests that assert nothing. Replace `PlaceholderTests` and `PlaceholderPropertyTests` once real tests exist.
- Every system effect (process execution, signals, app quitting, unmounting, file system probing) goes through a protocol and is mocked in tests. Tests never touch the real system.
- Mocks are hand-written, deterministic, record their calls, and live in the test target. Use injected clocks instead of real sleeps; tests must not depend on wall-clock time, network, locale, or the machine's mounts.
- Every parser and printer has a round-trip property.
- Property tests run at least 500 iterations in CI (`count: 500` or more). Do not lower counts to make a test pass.
- Tests must pass `swiftlint --strict`.
- Test names describe behavior (`parserKeepsNonUTF8PathBytes`), not implementation.
- Fix the code, not the test, unless the test contradicts the spec; then change the test and say so.

## What to cover (mapped to the master spec's Correctness Properties)

- Parser/printer (P1-P6): totality on arbitrary `Data` (including NUL bytes and up to 100 MiB inputs by size class), round-trip, byte fidelity, determinism, truncation prefix-safety, unknown-field tolerance, malformed escape handling. Generators: arbitrary `Data`, structured record sets serialized to `lsof -F`, and byte mutations (flip, drop, duplicate, truncate).
- Classifier (P7-P8): category from `fd`, daemon allowlist, shell/idle logic, containment under the mount, symlink escape.
- Mounts (P9-P10): longest whole-component prefix (`/Volumes/A` vs `/Volumes/AB/file`), protected volume refusal.
- Safety (P11-P13): deny-list table tests, escalation order, identity guard with generated process tables and stage histories.
- Pipeline (P14-P17): plan construction, unmount gating, fresh scan before and rescan after each stage, discovery merge/idempotence.
- Entry/UI logic (P18-P21): URL round-trip, middle truncation, ghost state mapping, argument-array fidelity.

## Integration and manual

- Local-only integration test (skipped in CI): create a 10 MB disk image with `hdiutil`, attach it, spawn helpers (a `cat` on a file, a shell with cwd inside), run discover -> pipeline -> unmount through the CLI, always detach and clean up in a `defer`.
- Manual QA checklist for the Quick Action, drop target, VoiceOver, and Reduce Motion lives in `docs/`.

## Commands

- `swift test` for tests; `Scripts/lint-and-test.sh` for lint plus tests.
- Coverage goal: at least 90% on `PhantomTraceCore`.
- Do not run watch-mode test commands.

Note: the property-based library is whatever `Package.swift` pins (currently swift-property-based); older specs call it SwiftCheck.
