---
inclusion: always
---

# macOS Platform

## Target

Deployment target is macOS 15.0 (Sequoia) or later: `Package.swift` declares `platforms: [.macOS("15.0")]` and `LSMinimumSystemVersion` is `15.0`. 15.0 is the lowest version that compiles, because `Synchronization.Mutex` needs it; going lower means replacing `Mutex` everywhere. The only tested system is macOS "Golden Gate" 27.2.1 (build 26B131); Apple silicon or Intel as the dev machine provides. Versions 15.0 through 26.x are best effort and untested, so docs must say so. If the compiler flags an API newer than 15.0, guard it with `#available` in a `System/` adapter or the app target.

This sandbox is **Linux**: it cannot build or test macOS-only code (DiskArbitration, AppKit, `lsof` semantics). When working here:

- Do not claim a build or test passed unless it ran. Say "not verified on macOS" and give the commands for the user to run on a Mac (`swift build && swift test`, `swiftlint --strict`).
- Keep pure logic (parser, printer, classifier, safety, planning, URL handling) free of Darwin-only APIs so it can be checked wherever possible; isolate Darwin/DiskArbitration code in `System/` behind protocols with `#if canImport(Darwin)` only where unavoidable.

## System behavior to design around

- **Paths:** `/Volumes/X` entries can be symlinks or firmlinks; the data volume is firmlinked at `/System/Volumes/Data`. Canonicalize with `realpath`/`resolvingSymlinksInPath` before matching. Mount table from `getmntinfo`/`statfs` (`f_mntonname`, `f_mntfromname`, `f_fstypename`).
- **Disk images:** map a `.dmg` to its attached volume via `hdiutil info -plist` (parse with `PropertyListSerialization`) or DiskArbitration descriptions.
- **Unmount:** `DADiskCreateFromVolumePath` + `DADiskUnmount` with `kDADiskUnmountOptionDefault`; force option only on advanced confirmation. DiskArbitration callbacks need a session scheduled on a dispatch queue (`DASessionSetDispatchQueue`). Fallback `/usr/sbin/diskutil unmount <mountpoint>` once, only when DA fails with something other than busy.
- **lsof:** `/usr/sbin/lsof -F pcLnftau0 -w +f -- <mountpoint>` (NUL-terminated machine-readable fields). Prefer the device-based form; `+D` only as a timeout/truncation fallback. `lsof` output is only complete for processes the current user may inspect.
- **Process info:** start time via `proc_pidinfo`/`sysctl(KERN_PROC_PID)`; controlling terminal and foreground process group via `kinfo_proc`/`tcgetpgrp` data. Identity is always `(pid, start time)`.
- **GUI vs non-GUI:** `NSRunningApplication` (app target / app-quitter adapter only) decides `quitApplication` vs `SIGTERM`. Core sees this through an `AppQuitting` protocol so it stays AppKit-free.
- **Terminal automation:** Terminal/iTerm scripting for `cd ~` needs the user's Automation (TCC) permission. Handle denial as "manual" action with instruction, never retry or prompt in loops.

## App packaging (later feature)

- **App Sandbox cannot be enabled** (needs `lsof` and signals). Use Hardened Runtime, minimal entitlements, notarization-ready signing. Document entitlements in `docs/`.
- Register the `phantomtrace` URL scheme in `Info.plist` (`CFBundleURLTypes`) and handle it via `NSAppleEventManager`/`application(_:open:)`.
- Quick Action: Automator `.workflow` or Services entry passing the selected item to `phantomtrace://inspect?path=…`; `Scripts/install-quick-action.sh` installs it to `~/Library/Services`, prints a clear error and exits non-zero on failure, and leaves any existing installation untouched.
- Accessibility: VoiceOver labels on all custom controls; honor `NSWorkspace.shared.accessibilityDisplayShouldReduceMotion`.

## Anti-goals

- No Mac Catalyst/iOS/Linux/Windows code paths, no backwards-compat for older macOS, no deprecated-API workarounds for other versions.
- No kernel extensions, no private APIs, no `sudo` or privileged helper unless a later spec adds an explicit, user-initiated authorization flow.
