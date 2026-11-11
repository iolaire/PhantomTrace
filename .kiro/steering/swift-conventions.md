---
inclusion: fileMatch
fileMatchPattern: "**/*.swift"
---

# Swift Conventions

Applies to all Swift in `Sources/` and `Tests/`. Lint is enforced by `swiftlint --strict` (`.swiftlint.yml`).

## Style

- Follow the Swift API Design Guidelines. Types `UpperCamelCase`; members `lowerCamelCase`; protocols named for capability (`ProcessRunning`, `Unmounting`, `LockDiscovering`) as in the design.
- 4-space indent, lines at most 120 characters, no trailing whitespace, one blank line at EOF.
- Prefer `struct`/`enum` over `class`. `final class` only when identity or reference semantics are needed. Prefer `let`. Default to the narrowest access level; Core API is explicit `public`.
- Prefer `guard` early exits. No force unwrap (`!`), `try!`, `as!`, or `fatalError` in Core; only allowed in tests with obvious intent. Prefer exhaustive `switch` without `default` on our own enums.
- No `print` in Core; use `Logger`. The CLI writes results to stdout and errors to stderr.
- Comments explain why, not what. Doc comments (`///`) on public API reference the spec requirement when it is non-obvious (for example `/// Requirement 4.14`).

## Data and bytes

- Paths and process names from `lsof` are **bytes** first. Keep `Data` (`pathBytes`, `commandBytes`) as the source of truth; derive `String` with lossy UTF-8 (`String(decoding:as:)`) for display only. Never round-trip bytes through `String` for logic.
- Use `URL(fileURLWithPath:)` and `FileManager` for file paths, never string concatenation of path components. Match mount prefixes on whole path components.
- Model failures with `PhantomTraceError` and typed `throws`/`Result` at boundaries. Errors carry the data needed to show the user why (pid, command, code).
- Model states as enums with associated values (discovery state machine: Idle, Resolving, Scanning, Parsed, Classified, Clean, Blocked, Unmounting, Unmounted, Failed), not boolean flags.

## Dependency injection

- Types receive collaborators through initializers as protocol values (`ProcessRunning`, `SignalSending`, `AppQuitting`, `Unmounting`, `FileSystemProbing`, a clock). No singletons or global mutable state in Core.
- Time, PID of self, current uid, and environment come from injected values so tests are deterministic.

## Concurrency

- `async`/`await`, structured concurrency, `Task` cancellation honored in scans and sleeps. No `DispatchQueue` unless wrapping a C callback (DiskArbitration), and then bridge with `withCheckedThrowingContinuation` exactly once per callback.
- Every `Process` run: set timeout, read stdout/stderr concurrently to avoid pipe deadlock, terminate and reap on timeout or cancellation.

## Lint specifics to respect

- Keep functions and types small enough for default SwiftLint complexity and length rules; split rather than disable.
- Sort imports; no unused imports; no unused variables or parameters (use `_`).
