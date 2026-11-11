---
inclusion: always
---

# Product

PhantomTrace is a retro-themed macOS contextual forensic utility that demystifies Finder's opaque "The disk wasn't ejected because one or more programs may be using it" dialog. It pinpoints the exact locking processes and open file handles so users can safely resolve blockers and unmount external drives.

Mission: identify which processes prevent a volume from ejecting, and help the user fix it without data loss.

Full overview: `docs/ProjectOverview.md`. Master spec (source of truth): `.kiro/specs/phantomtrace-volume-lock-forensics/` (`requirements.md`, `design.md`). Do not modify the master spec from unrelated work. If code and spec disagree, raise it instead of silently picking one.

## What it does

Input is a volume, folder, file, or mounted `.dmg`. PhantomTrace:

1. Resolves the owning mount (`Mount_Resolver`); refuses protected volumes.
2. Discovers locks with `lsof` (`Lock_Discovery_Engine` -> `Lsof_Parser` -> `Lock_Classifier`).
3. Classifies each lock by category (`cwd`, `openFileHandle`) and process role (`systemDaemon`, `idleShell`, `userApplication`, `cliTool`, `unknown`).
4. Offers a graduated, opt-in resolution pipeline: **Egress Shells -> Graceful Request -> Banish Locks -> Clean Handoff**.

## Audience and tone

Mac users (including non-technical ones) who cannot eject a drive, plus developers with stray shells. UI copy is plain, calm, and specific: name the process, the pid, and the file. Retro flavor is allowed in visuals and light microcopy; never obscure what an action will do.

## Product principles

- **Inform first, act second.** Diagnosis is always available; every action is opt-in, previewed, and verified.
- **Least destructive path first.** Prefer `cd ~` over quit, quit over `SIGTERM`, `SIGTERM` over `SIGKILL`, non-forced unmount over force.
- **Never act on stale state.** Re-scan before and after every stage.
- **Local only.** No network, no telemetry.
- **Honest failure.** Partial results, timeouts, and denials are shown with the reason, never hidden.

## Entry points

- Finder Quick Action ("Why Can't I Eject?" / "Inspect Volume Locks") opening `phantomtrace://inspect?path=<percent-encoded>`.
- Desktop/Dock drop target (not a menu-bar widget; no menu-bar item).
- `phantomtrace` CLI for scripting and end-to-end tests.

## Hackathon theme

Kiroween 2026, Resurrection category: resurrect classic single-purpose Mac diagnostic tools (System 7 / OS 9 inspectors, *What's Keeping Me?*) for modern macOS. See `hackathon.md` and `platinum-ui.md`.

## Platform target

- macOS only. No other OS is supported.
- macOS 27.2.1 (build 26B131) only. Every other macOS version, older or newer, is out of scope and unsupported because it cannot be tested. Do not add compatibility shims or `#available` fallbacks for other versions.
- Details: `macos-platform.md`.

## Status

Scaffolding is complete; feature logic is implemented incrementally from the master spec. Build order: Models -> `LsofParser`/`LsofPrinter` -> `LockClassifier` -> `MountResolver` -> `LockDiscoveryEngine` -> `SafetyPolicy` -> `ResolutionPipeline` + `Unmounter` -> CLI -> AppKit app, Quick Action, UI.
