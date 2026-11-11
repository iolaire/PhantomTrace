# Project Log

Living record of the work, the tools we use, and the decisions we make. Update it in the same commit as the change it describes (enforced by `.kiro/hooks/project-log-check.json`; see `.kiro/steering/documentation.md`).

Newest entries go at the top of each section. Dates are YYYY-MM-DD.

## Work log

| Date | Change | Spec refs | Verified how |
|---|---|---|---|
| 2026-11-11 | Rewrote steering (product, tech, structure, safety, testing, hackathon) and added swift-conventions, macos-platform, platinum-ui, git-workflow, documentation | n/a | Reviewed against master spec; not built (Linux sandbox) |
| 2026-11-11 | Project scaffolding: SwiftPM package, CLI stub, placeholder tests, docs, LICENSE | project-scaffolding | `swift build`/`swift test` on macOS |

## Tools

| Tool | Version | Purpose | Scope |
|---|---|---|---|
| Swift / SwiftPM | tools 6.0 | Build and test | Dev + runtime |
| swift-property-based (`PropertyBased`) | 2.0.1 (exact) | Property-based tests | Test only |
| Swift Testing | toolchain | Unit and property tests | Test only |
| SwiftLint | Homebrew, `--strict` | Lint | Dev only |
| DiskArbitration | macOS SDK | Unmount | Runtime (system) |
| `/usr/sbin/lsof`, `/usr/bin/fuser`, `/usr/sbin/diskutil`, `/usr/bin/hdiutil` | macOS 27.2.1 | Lock discovery, unmount fallback, dmg mapping | Runtime (system) |
| Kiro (specs, steering, hooks) | n/a | Spec-driven development | Dev only |

Runtime third-party dependencies: none.

## Decisions

Format: ID, date, status (Accepted / Superseded), context, decision, consequences.

### D-001 (2026-11-11, Accepted): Platform scope is macOS 27.2.1 only
- Context: only that version can be tested.
- Decision: no support or compatibility code for other macOS versions or operating systems.
- Consequences: simpler code; `Package.swift` declares `.macOS("27.2.1")`.

### D-002 (2026-11-11, Accepted): Core library has no AppKit
- Decision: `PhantomTraceCore` imports Foundation only (Darwin/DiskArbitration/OSLog in `System/` adapters). UI lives outside Core.
- Consequences: Core logic is testable; system effects sit behind protocols.

### D-003 (2026-11-11, Accepted): Property-based library is swift-property-based, not SwiftCheck
- Context: `Package.swift` pins `swift-property-based` 2.0.1; older specs and docs say SwiftCheck.
- Decision: `Package.swift` is the source of truth; steering follows it.
- Consequences: scaffolding spec and checks that mention SwiftCheck need updating.

### D-004 (2026-11-11, Accepted): Single SafetyPolicy gate for all actions
- Decision: every `ProposedAction` is approved by `SafetyPolicy`; unknown state means deny.
- Consequences: UI/CLI never call signal or unmount adapters directly.

### D-005 (2026-11-11, Accepted): Hook enforces project log updates at commit time
- Context: pushes to `main` go through PRs, so a commit-time check covers all code.
- Decision: a commit hook blocks commits that change code or config without staging `docs/ProjectLog.md`; a steering rule says what to record.
- Consequences: small friction per commit; escape hatch is an `[skip-log]` marker in the commit message for trivial changes.
