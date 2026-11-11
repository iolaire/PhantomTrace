# Structure

## Layering rule

Core_Library (`PhantomTraceCore`) imports no AppKit module. It imports only Foundation (and system frameworks that are not UI). All UI code lives outside the Core library.

## Directory conventions

- `Sources/PhantomTraceCore`: the Core library
  - `Mounts`
  - `Discovery`
  - `Resolution`
  - `System`
  - `Models`
- `Sources/phantomtrace`: the CLI executable
- `Tests/PhantomTraceCoreTests`: unit tests
- `Tests/PhantomTracePropertyTests`: SwiftCheck property tests
- `Tests/Fixtures`: test fixtures
- `docs`: documentation (`docs/screenshots` holds screenshots)
- `Scripts`: helper scripts
- `.kiro/steering`: steering files
- `.kiro/hooks`: hook files

Empty directories keep a zero-byte `.gitkeep`; remove it when real content arrives.

## Not yet present

`App/`, the Xcode project, and the Quick Action are added by a later feature.
