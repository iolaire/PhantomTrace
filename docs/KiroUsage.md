# How PhantomTrace Uses Kiro

The Rules require a write-up showing how effectively Kiro was used. This document is the draft. Fill each "Evidence" line with what actually happened during the build; leave out anything not used.

## Spec-driven development

- Master spec: `.kiro/specs/phantomtrace-volume-lock-forensics/` (requirements, design) covering mount-point path resolution, process discovery, and the safe unmount workflow.
- Scaffolding spec: `.kiro/specs/project-scaffolding/` (requirements, design, tasks).
- Evidence to add: how the spec shaped the implementation, and how it compared to vibe coding.

## Steering docs

Files in `.kiro/steering/`:

- `product.md`: mission, theme, platform scope (macOS 27.2.1 only).
- `tech.md`: Swift, SwiftPM, AppKit, DiskArbitration, zero third-party runtime dependencies.
- `structure.md`: layering rule (Core library imports no AppKit) and directory layout.
- `safety.md`: no shell strings, protected processes never signaled, opt-in and re-verified stages.
- `testing.md`: mock protocols for all system effects, round-trip properties.
- Evidence to add: which steering rule changed Kiro's output the most.

## Agent hooks

- Planned: pre-commit hook running `swiftlint --strict` and `swift test` via `Scripts/lint-and-test.sh`.
- Status: `.kiro/hooks/` is empty. Add hooks, then record the workflow each one automates and the issues it caught.

## Property-based testing

- SwiftCheck, pinned to an exact version, in `Tests/PhantomTracePropertyTests`.
- Targets: the `lsof`/`fuser` output parser against malformed paths, non-UTF8 strings, spaces, and symlinks; round-trip properties for every parser and printer.
- Evidence to add: bugs PBT found that unit tests did not.

## Other Kiro features

- Kiro IDE, CLI, Web, or Crew: record which were used and how they differed.
- Custom agents: record any created and their effect.
- MCP: record any servers used and what they enabled.
- Kiro powers: record any powers used.
