# PhantomTrace

**Volume Lock Forensics & Banishment**

A retro-themed macOS contextual forensic utility that demystifies Finder's opaque *"The disk wasn't ejected because one or more programs may be using it"* dialog by pinpointing the exact locking processes and open file handles, allowing users to safely resolve blockers and unmount external drives.

PhantomTrace is built for the Kiroween **Resurrection** category. See [docs/ProjectOverview.md](docs/ProjectOverview.md) for the full overview.

## The problem

When an external drive, USB stick, or disk image (`.dmg`) fails to unmount, Finder shows a generic error without naming the responsible application. Users end up running `lsof`, `fuser`, and `kill -9` by hand, or pulling the cable and risking filesystem corruption.

PhantomTrace shows what is blocking the volume and tells these cases apart:

- **Background system daemons:** Spotlight indexing (`mds`, `mdworker_shared`) and QuickLook satellites.
- **Current working directory (CWD) locks:** orphaned shells (`zsh`, `bash`, `node`) sitting inside a folder on the volume.
- **Active open file handles:** running apps holding read/write locks on specific files.

## How it works

- **Trigger:** a native Finder Quick Action (`Why Can't I Eject?` / `Inspect Volume Locks`) and a Desktop drop target. It is independent of any menu-bar widget.
- **Diagnostic sheet:** shows the volume name and path, and lists each offending process with its name, PID, user, lock category (CWD or open file handle), and exact file path.
- **Graduated resolution pipeline** (opt-in):
  1. Egress Shells: reset idle shell working directories (`cd ~`) without killing terminal sessions.
  2. Graceful Request: send AppKit quit / `SIGTERM` requests to active applications.
  3. Banish Locks: send a targeted `SIGKILL` to hung daemons or orphan workers.
  4. Clean Handoff: unmount through `DiskArbitration.framework` or `/usr/sbin/diskutil unmount` once no locks remain.

## Visual direction

Platinum Retro Gothic: a System 7 / Mac OS 9 platinum alert window (pinstripe title bars, Monaco/Chicago typography, 1px beveled frames) haunted by the Kiro ghost mascot. It resurrects classic single-purpose Mac diagnostic tools, such as *Put Away* inspectors and *What's Keeping Me?*, for the modern Darwin APFS kernel.

## Status

The project is at the scaffolding stage. The repository structure, an empty Swift package, and project tooling exist, but no feature logic has been implemented yet.

## Platform

PhantomTrace is **macOS only** and targets **macOS 27.2.1 (build 26B131) only**. It is not supported on any other macOS version, older or newer, and not on Linux, Windows, or iOS.

## Build

Build the package:

```
swift build
```

Run the tests:

```
swift test
```

Enable the commit checks once per clone (lint, tests, project log, and `.kiro` guard on every commit):

```
Scripts/install-git-hooks.sh
```

SwiftLint is required for the checks: `brew install swiftlint`.

## Built with Kiro

- **Specs** in `.kiro/specs/`: mount-point path resolution, process discovery state machines, and safe unmount workflows.
- **Property-based testing:** fuzz tests of the `lsof`/`fuser` output parser against malformed paths, non-UTF8 strings, spaces, and symlinks.
- **Agent hooks** in `.kiro/hooks/`: pre-commit checks that enforce swiftlint rules and require passing tests.
- **Steering files** in `.kiro/steering/`.

See [docs/KiroUsage.md](docs/KiroUsage.md) for how each Kiro feature was used.

## Hackathon submission

- Category: Resurrection. Hackathon: Kiroween 2026.
- [Submission checklist](docs/SubmissionChecklist.md)
- [Demo script](docs/demo-script.md)
- Pre-existing code: none. The project was created during the Submission Period.
- Runtime dependencies: none. swift-property-based and SwiftLint are development tools only.

## Documentation

- [Architecture](docs/architecture.md): layers, data flow, pipeline, safety model, implementation status
- [Project log](docs/ProjectLog.md): work, tools, and decisions
- [Look and feel](docs/LookAndFeel/README.md): visual design reference
- [docs index](docs/README.md)

## Specs

- [Project overview](docs/ProjectOverview.md)
- [Master spec: PhantomTrace volume lock forensics](.kiro/specs/phantomtrace-volume-lock-forensics/)
- [Project scaffolding spec](.kiro/specs/project-scaffolding/)

## License

PhantomTrace is released under the MIT License. See [LICENSE](LICENSE).
