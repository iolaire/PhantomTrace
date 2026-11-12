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

Platinum Retro Gothic: a System 7 / Mac OS 9 platinum alert window (pinstripe title bars, Monaco/Chicago typography, 1px beveled frames) haunted by an original, Kiro-inspired ghost mascot. It resurrects classic single-purpose Mac diagnostic tools, such as *Put Away* inspectors and *What's Keeping Me?*, for the modern Darwin APFS kernel.

## Status

The code for every task in the master spec's build order is written (Core library, live adapters, `phantomtrace` CLI, AppKit app, Quick Action bundle, bundling script). What has and has not been checked:

- Verified on macOS during development: `swift build`, targeted `swift test` runs (unit and property tests), `swiftlint --strict`, the bundler (`Scripts/make-app.sh`) and its shell test, the Quick Action installer shell test, and a local-only integration test that attaches a throwaway disk image. See [docs/ProjectLog.md](docs/ProjectLog.md) for what was run for each change.
- The app has been launched by the owner and the lock windows were checked as offscreen renders. The app now has a main menu (Quit Cmd-Q, Close Window Cmd-W, Inspect... Cmd-O, File > Inspect Volume) and a drop window that lists mounted volumes with an Inspect button each (Requirement 19); these are covered by unit and property tests.
- **Not verified:** the new drop window with its volume list has not been seen on screen. The three-window flow end to end, the Finder Quick Action in Finder, the drop target, VoiceOver, and Reduce Motion are untested. The 100 ms main-actor bound is not measured. Notarization has not been attempted.
- Several behaviors are provisional and await the owner's confirmation; see [docs/architecture.md](docs/architecture.md#provisional-behaviors) and the known gaps in [docs/SubmissionChecklist.md](docs/SubmissionChecklist.md).
- No screenshots, demo video, or app icon exist yet.

## Platform

PhantomTrace is **macOS only** and targets **macOS 27.2.1 (build 26B131) only**. It is not supported on any other macOS version, older or newer, and not on Linux, Windows, or iOS.

## Build

Only the Command Line Tools are needed. There is no Xcode project, and `xcodebuild`, `actool`, and Interface Builder are not used.

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

SwiftLint is required for the checks: `brew install swiftlint`. On a Command Line Tools only machine, `swiftlint` may fail to load SourceKit unless `DYLD_FRAMEWORK_PATH=/Library/Developer/CommandLineTools/usr/lib` is set (and in some runs `SOURCEKIT_TOOLCHAIN_PATH=/Library/Developer/CommandLineTools`). This is a known gap; `Scripts/lint-and-test.sh` does not set it for you.

## Run

### CLI

The CLI is read-only: it resolves the volume and lists the locks. It never signals a process or unmounts anything.

```
swift run phantomtrace /Volumes/SomeDrive
swift run phantomtrace "phantomtrace://inspect?path=%2FVolumes%2FSomeDrive"
```

### App bundle

Build, sign (ad-hoc by default), and verify `build/PhantomTrace.app`:

```
Scripts/make-app.sh
open build/PhantomTrace.app
```

`make-app.sh` runs `swift build` for `PhantomTraceApp`, assembles the bundle in a staging directory, signs it with the hardened runtime, runs `codesign --verify --strict`, and replaces `build/PhantomTrace.app` only if that passes. On failure it prints the failed step to standard error, exits non-zero, and leaves an existing bundle unchanged. Set `SIGN_IDENTITY` to use a real identity instead of ad-hoc. The script does not notarize. The bundle has been built, verified, and launched (see Status).

Opened with no file or URL, the app shows the drop window: drop a volume or folder on the left, or pick a mounted volume from the list on the right and choose Inspect (or press Return). The same volumes are under File > Inspect Volume, and File > Inspect... (Cmd-O) chooses any file, folder, or volume. Protected and system volumes are never listed. The list refreshes when a volume is mounted, unmounted, or renamed. Cmd-W closes the window without quitting; click the Dock icon to bring it back. Quit with Cmd-Q.

### Finder Quick Action

```
Scripts/install-quick-action.sh
```

Copies `Packaging/QuickAction/Why Can't I Eject?.workflow` into `~/Library/Services` and refreshes Services. It prints an error and exits non-zero on failure, and leaves any existing installation untouched. The shell test for the installer passes, but it has since been installed and seen in Finder on macOS 27.2.1.

After installing, enable it once: right-click any item in Finder, choose Quick Actions > Customize..., and tick "Why Can't I Eject?" (or go to System Settings > General > Login Items & Extensions > Finder). Until then macOS hides it from every right-click menu, including the drive's. Quick Actions do not appear in the Finder sidebar's menu; right-click the volume on the Desktop or in the Computer window.

### Optional manual notarization

Not required to run the app locally, and not done for this repository. `notarytool` and `stapler` are present with Command Line Tools (checked by `Scripts/spike-signing.sh`), but nothing has been submitted. To notarize a build signed with a Developer ID identity, using your own keychain profile:

```
ditto -c -k --keepParent build/PhantomTrace.app build/PhantomTrace.zip
xcrun notarytool submit build/PhantomTrace.zip --keychain-profile "<profile>" --wait
xcrun stapler staple build/PhantomTrace.app
```

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
