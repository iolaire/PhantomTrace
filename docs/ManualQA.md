# Manual QA Checklist

Checks that automated tests cannot cover: the real app bundle, Finder, VoiceOver, and the real `lsof` and DiskArbitration stack. Run it on the target Mac (macOS 27.2.1). Nothing here has been run yet unless a result is filled in; tick a box only when you did the step.

Spec: [requirements](../.kiro/specs/phantomtrace-volume-lock-forensics/requirements.md) (Requirements 12, 13, 16, 17, 18), [tasks](../.kiro/specs/phantomtrace-volume-lock-forensics/tasks.md) (task 19.4). Design notes: [architecture](architecture.md#provisional-behaviors). Asset records: [Assets.md](Assets.md).

## Safety rules for this checklist

- Use a throwaway disk image only. Never test against a real backup drive, a real external disk, or any volume with data you care about.
- Never test against `/` or anything under `/System/Volumes` except in the "protected volume" step, which must be refused.
- Helper processes (`cat`, a shell) are started by you and are the only processes PhantomTrace may signal.
- Record the macOS build, the date, and who ran the pass at the bottom.

## 0. Set up the throwaway disk image

Do this once; most sections below use it.

```
hdiutil create -size 10m -fs APFS -volname PTQA /tmp/ptqa.dmg
hdiutil attach /tmp/ptqa.dmg
```

The volume mounts at `/Volumes/PTQA`. Create a file and hold it open:

```
echo hello > /Volumes/PTQA/held.txt
tail -f /Volumes/PTQA/held.txt
```

Leave that terminal running (this is the open file handle). In a second terminal start an idle shell inside the volume:

```
cd /Volumes/PTQA
```

Cleanup when finished (Section 9):

```
hdiutil detach /Volumes/PTQA
rm /tmp/ptqa.dmg
```

If detach reports busy, close the helper terminals first. Use `hdiutil detach -force` only on this throwaway image.

If a test volume (such as `Flash1GB` or `PTQA`) disappears from the Finder sidebar **Locations** list after being dragged out or removed via context menu, restore it with:

```
Scripts/restore-finder-volume-sidebar.sh Flash1GB
```

## 1. Build and bundle (Req 16)

Command: `Scripts/make-app.sh` (output `build/PhantomTrace.app`).

- [ ] Script exits 0 and prints success only after signature verification (16.8, 16.11).
- [ ] `build/PhantomTrace.app/Contents/MacOS/PhantomTrace`, `Contents/Info.plist`, and `Contents/Resources` exist (16.2).
- [ ] `codesign --verify --strict --verbose=2 build/PhantomTrace.app` passes (16.8).
- [ ] `codesign -dv --entitlements - build/PhantomTrace.app` shows the hardened runtime flag and no `com.apple.security.app-sandbox` entitlement (16.6, 16.7).
- [ ] `plutil -p build/PhantomTrace.app/Contents/Info.plist` shows `CFBundleExecutable`, `CFBundleIdentifier`, `LSMinimumSystemVersion` = `27.2.1`, a `CFBundleURLTypes` entry with scheme `phantomtrace`, and an `NSServices` entry (16.3, 16.4).
- [ ] No `.xcassets`, no Kiro logo or ghost art, and no Monaco, Menlo, SF, or Chicago font file in `Contents/Resources` (17.1, 17.15, 17.17).
- [ ] Failure case: run the script with `SIGN_IDENTITY` set to an identity that does not exist. It exits non-zero, names the failed step on standard error, and a previous `build/PhantomTrace.app` is unchanged (16.9, 16.10).
- [ ] Notarization is not performed by the script (16.12).

## 2. Launch and URL scheme (Req 12.1, 12.3, 12.4)

- [ ] Open the app (`open build/PhantomTrace.app`). The drop target window appears; there is no menu-bar item.
- [ ] With the throwaway volume mounted: `open 'phantomtrace://inspect?path=%2FVolumes%2FPTQA'`. Resolution starts within 2 seconds (12.1).
- [ ] A path containing a space or Unicode character, percent-encoded, resolves correctly.
- [ ] A symlink or `..` path (for example `path=%2FVolumes%2FPTQA%2F..%2FPTQA`) resolves to the same volume (12.3).
- [ ] Rejected with a clear error, and no scan starts, for each of: `phantomtrace://inspect` (no path), `phantomtrace://inspect?path=` (empty), a nonexistent path, a path over 1024 characters, a malformed URL (12.4).
- [ ] Rejection shows one alert with a single dismiss control, and no window content behind it (see P1 in Section 8).

## 3. Quick Action in Finder (Req 12.1, 12.8 to 12.11)

The repo ships both a `.workflow` bundle (`Packaging/QuickAction/Why Can't I Eject?.workflow`) and an `NSServices` entry ("Inspect Volume Locks") in the app `Info.plist`. Check each path separately and record which one works; Req 12.10 allows either or both.

Workflow path:

- [ ] `Scripts/install-quick-action.sh` exits 0 and prints no error; `~/Library/Services/Why Can't I Eject?.workflow` exists (12.8, 12.11).
- [ ] Run it a second time: still exits 0 and the action is still present.
- [ ] Failure case: make `~/Library/Services` unwritable in a temporary `HOME` (see `Tests/Scripts/install-quick-action-tests.sh`), or set `PHANTOMTRACE_QUICK_ACTION_SOURCE` to a missing folder. Exit non-zero, a cause on standard error, and an existing installed action is left unchanged (12.9).
- [ ] In Finder, right-click the mounted `PTQA` volume (Desktop or sidebar) and find "Why Can't I Eject?" under Quick Actions or Services. If it is not visible, check System Settings > Keyboard > Keyboard Shortcuts > Services and Extensions > Finder, and log out and in once. Note the result.
- [ ] Choosing it opens the app with the volume inspected within 2 seconds.
- [ ] Also try on a folder and a file inside the volume: the owning volume is resolved.

NSServices path (needs the app launched or registered once):

- [ ] "Inspect Volume Locks" appears in Finder > Services (right-click > Services, or the Finder menu) for a selected item.
- [ ] Choosing it inspects the selected item.
- [ ] Note any case where the Services entry is missing until `/System/Library/CoreServices/pbs -flush` is run, or until the app has been moved to `/Applications`.

Result to record: workflow works / NSServices works / both / neither. Decision still open for the owner if only one works.

## 4. Drop target (Req 12.2)

- [ ] Drag the `PTQA` volume icon onto the drop target. Resolution starts within 2 seconds.
- [ ] Drag a folder inside the volume: same result.
- [ ] Drag a non-file item (for example selected text): nothing happens and no crash.
- [ ] Reopen the app from the Dock after closing the drop window: the drop window comes back.
- [ ] VoiceOver reads a sensible label for the drop target.

## 4a. Volume picker and main menu (Req 19)
- [ ] Launch the app from Finder with no file: within 2 seconds the drop window opens with the volume list and no scan starts (19.14).
- [ ] The list shows `PTQA` with its mount point and the word "Removable"; `/`, `/System/Volumes/...`, Time Machine snapshots, and dot-named mounts are absent (19.3 to 19.5).
- [ ] File > Inspect Volume lists the same volumes in the same order; with no external volumes it shows one disabled "No volumes available to inspect" item (19.3, 19.13).
- [ ] Inspect on the `PTQA` row, a double-click, and Return on the focused row each start one inspect, same as dropping the volume (19.8).
- [ ] File > Inspect... (Cmd-O) opens a single-selection panel; Cancel does nothing; choosing `/Volumes/PTQA` starts an inspect (19.2).
- [ ] Attach a second throwaway image, rename it in Finder, then detach it: the list and submenu update within about 1 second each time (19.9).
- [ ] Detach `PTQA` and choose its row before the list refreshes, if you can: the rejection reason shows and no scan starts (19.12). Record "not exercised" if the refresh wins.
- [ ] Keyboard: Tab reaches the list rows and each Inspect button, arrow keys move between rows, Space activates a focused Inspect button (19.10).
- [ ] VoiceOver reads each row as "<name>, <mount point>, removable" or "internal", and each button as "Inspect <name>" (19.10).
- [ ] Cmd-W closes the drop window without quitting and without stopping a running inspect; clicking the Dock icon shows it again (19.15).
- [ ] Cmd-H hides, Cmd-M minimizes, Cmd-Q quits. No PhantomTrace item appears in the menu-bar status area (19.1).

## 5. Sprites, fonts, and the three windows (Req 13, 17, 18)

### 5.1 Assets (Req 17.3, 17.4, 17.5, 17.7, 17.8, 17.14, 17.16)

- [ ] All seven sprites exist at 1x and 2x in `build/PhantomTrace.app/Contents/Resources` (names in 17.3).
- [ ] On a Retina display the 2x art is used and is sharp; on a 1x display (or an external 1x monitor, or scaled mode) the 1x art is used and looks right.
- [ ] The window frame stretches without distorting corners or edges when the window is resized. Table and buttons stay inside the interior (17.5).
- [ ] Missing-asset fallback: copy the app to a temporary folder, delete one sprite file (for example `ghost-looking-left-red@2x.png`), launch, and confirm a text or system-drawn substitute appears, the rest of the window works, and the Console log names the missing file (17.7). Delete the temporary copy afterwards.
- [ ] Title plaque text is drawn live (not baked into the frame art). No Title_Font file is bundled at the moment, so the system font is expected (17.8, 17.14). If a title font is added later, confirm it is used and its license file is bundled.
- [ ] Lock table text uses Monaco if installed, otherwise Menlo, otherwise the system monospaced font (17.16). Note which one you saw.
- [ ] Compare the ghost against the official Kiro ghost side by side and record the result in [Assets.md](Assets.md) (owner action; this file does not edit Assets.md) (17.12, 17.15).

### 5.2 `cannotPutAway` window (Req 18.2, 18.10, 18.11, 18.12)

Start with the held file and shell from Section 0, then inspect `PTQA`.

- [ ] Title plaque "CANNOT PUT AWAY", illustration `shackled-volume-and-padlocks`, yellow ghost (13.6, 18.10).
- [ ] Spooky message, a question about running a Phantom Trace, exactly one Proceed button, and a close box (18.11).
- [ ] Proceed opens the `phantomTrace` window (18.12).
- [ ] Close box closes the window without any action taken on processes.

### 5.3 `phantomTrace` window (Req 13, 18.3, 18.13, 18.14)

- [ ] Title plaque "PHANTOM TRACE", illustration `crt-diagnostic-portal`, red ghost (13.7, 18.13).
- [ ] The table has columns Process Name, PID, User, Lock Category, File Path, and one row for `tail` (open file handle) and one for the shell (cwd) (13.1).
- [ ] A long path is truncated in the middle and shows the full path in a tooltip within 1 second (13.2).
- [ ] The choice control lists Egress Shells, Graceful Request, Banish Locks under "Let PhantomTrace act", then "I'll deal with these processes myself", plus exactly one Proceed button (13.3).
- [ ] Proceed is disabled until an option is selected (18.14).
- [ ] An inapplicable stage is shown disabled (for example Egress Shells when no idle shell is locking) (13.4).
- [ ] Rows for processes owned by another user (if any are present) are read-only, show a lock icon and a text explanation, and are never targeted (13.12). If none can be produced, record "not exercised".
- [ ] Blocked with no lock details (for example when `lsof` cannot see the holder): empty table, a "no lock details could be retrieved" message, every stage option disabled (13.13). Record "not exercised" if it cannot be produced safely.

### 5.4 Resolution stages against the test image (Req 6 to 9, 11)

Run one stage at a time, and confirm the plan preview names the process, pid, and file before anything runs.

- [ ] Egress Shells: the plan lists the idle shell. After proceeding, the shell's cwd is no longer in the volume (or the app reports a manual instruction if Terminal automation is denied; no repeated prompts).
- [ ] Graceful Request: the plan lists `tail` with a SIGTERM-style action. After proceeding, `tail` exits.
- [ ] Banish Locks: a confirmation lists name and pid. Declining sends nothing. Confirming works only for a process that earlier received a graceful request, or for a user-confirmed system daemon.
- [ ] Each stage ends with a rescan; the table shows the new state without stale rows.
- [ ] Failed actions (for example a process that exited in between) are listed with pid and error kind (14.5).
- [ ] Protected processes (launchd, Finder, and so on) never appear as targets.

### 5.5 `volumeReleased` window (Req 18.1, 18.19, 18.20, 18.22 to 18.25)

- [ ] When a rescan finds zero locks, the window changes to `volumeReleased`: title "VOLUME RELEASED", illustration `shattered-chains-and-portullis`, green ghost, spooky message (13.8, 18.19, 18.20).
- [ ] While still mounted: Eject button plus a note that retrying Eject in Finder also works (PROVISIONAL, see P5).
- [ ] Eject shows progress and is disabled while unmounting (18.24). The volume unmounts non-forced.
- [ ] Busy unmount: start `tail -f` again after releasing but before pressing Eject. Eject returns to the `phantomTrace` window with the new lock and the red ghost (18.25).
- [ ] After the volume is gone (for example eject it from Finder while the window is open): the window shows `volumeReleased` with only the message and the Finder instruction, no Eject button (18.9, PROVISIONAL, see P6).
- [ ] Force unmount is reachable only through the advanced confirmation.

### 5.6 Failure and partial scans (Req 14.1, 14.2, 18.26)

Hard to trigger on demand. Options: temporarily make the `lsof` path unreadable in a test build, or use a fixture-based test double in a debug build. Record "not exercised" if neither is done.

- [ ] A banner appears within 500 ms saying whether discovery failed or was partial, with parse warnings (up to 100, omitted count shown) and an enabled Rescan button (14.1).
- [ ] Proceed and every stage option are disabled (PROVISIONAL, see P7).
- [ ] Rescan clears the banner and warnings once the new run starts (14.2).
- [ ] On Failed, no signal is sent and the window stays open (14.4).

### 5.7 Protected and unsupported input (Req 2)

- [ ] Dropping `/` or a path under `/System/Volumes` is refused with an alert that has a single dismiss control, within 1 second, and no scan.
- [ ] A path that is not inside a mounted volume, or cannot be verified, is refused the same way.

## 6. Accessibility (Req 13.10, 13.11, 13.14)

VoiceOver (turn on with Cmd-F5):

- [ ] Every custom control has a non-empty spoken label: the choice control and each of its options, Proceed, Eject, Force Unmount, Rescan, the Failure banner, the ghost, each illustration, the close box, the drop target.
- [ ] A disabled choice option is announced as dimmed or unavailable (13.4).
- [ ] The lock table is navigable row by row; each row's process name, pid, user, category, and path can be read.
- [ ] The progress state of Proceed and Eject is announced or at least discoverable.
- [ ] A window change (`cannotPutAway` to `phantomTrace` to `volumeReleased`) is announced or the new window takes VoiceOver focus.
- [ ] Alerts (rejected input) are read and can be dismissed from the keyboard.

Keyboard:

- [ ] Tab reaches every control in a sensible order; Space or Return activates the focused button; Escape dismisses an alert.

Reduce Motion (System Settings > Accessibility > Display > Reduce motion):

- [ ] With Reduce Motion on, the ghost is a static image with no glow animation (13.10).
- [ ] With Reduce Motion on, illustrations and the Scanning_Overlay spinner show no animation beyond what is unavoidable; note the spinner behavior (13.14).
- [ ] With Reduce Motion off, the glow animation runs and nothing flickers.
- [ ] Toggle Reduce Motion while a window is open and note whether it updates live or only on the next window.

Other:

- [ ] Text remains readable and not clipped at default and larger display scaling.
- [ ] Contrast of table text on the platinum gray (#DDDDDD) background is acceptable (judged by eye; full WCAG validation needs expert review with assistive technology).

## 7. CLI against the test disk image (Req 12.5 to 12.7, 15)

Build once with `swift build`, then use `.build/debug/phantomtrace`. The CLI is read-only: it must never signal a process or unmount. Use the image from Section 0 with the helpers running.

- [ ] `.build/debug/phantomtrace /Volumes/PTQA` prints Lock_Records naming `tail` (open file handle) and the shell (cwd) with pids, and exits 0 (`echo $?`) (12.5, 12.7).
- [ ] `.build/debug/phantomtrace 'phantomtrace://inspect?path=%2FVolumes%2FPTQA'` gives the same result.
- [ ] A relative path from inside the volume (`cd /Volumes/PTQA && /path/to/phantomtrace .`) resolves to the volume.
- [ ] A file inside the volume (`/Volumes/PTQA/held.txt`) resolves to the owning volume.
- [ ] No arguments: usage or error on standard error, nothing on standard output, non-zero exit (12.6).
- [ ] A nonexistent path: error on standard error, no records, non-zero exit (12.6).
- [ ] `/`: refused as protected, non-zero exit, no scan.
- [ ] A file name that starts with `-` (create `/Volumes/PTQA/-dash.txt`, hold it with `tail -f`): handled as data, no option injection, listed correctly (15.8).
- [ ] A file name with a space, a newline, or a quote (for example `touch "$(printf '/Volumes/PTQA/a\nb')"`): record is printed intact and nothing is executed (15.2).
- [ ] After closing both helpers, the CLI reports zero locks and exits 0.
- [ ] After all CLI runs, the helper processes are still running (the CLI sent no signals).

## 8. Provisional behaviors awaiting user confirmation (Req 18)

These are implemented as specified but labelled `PROVISIONAL` in code so they are easy to change. Find them with:

```
grep -rn "PROVISIONAL" Sources
```

For each, check what the app does today and record the owner's decision. If the owner changes a decision, update the code, the requirements, [architecture](architecture.md#provisional-behaviors), and the decision entry in [ProjectLog.md](ProjectLog.md) together.

| ID | Req | Behavior to check | Code labels (grep) | Result | Owner decision |
|---|---|---|---|---|---|
| P1 | 18.6 | During Idle, Resolving, and resolve-failed, no window content is shown; a resolve error shows only an alert | `LockWindowController.swift`, `LockWindowContentView.swift`, `DiagnosticCoordinator.swift` | Not run | Pending |
| P2 | 18.7 | If the first scan runs longer than 500 ms, the frame with a Scanning_Overlay appears at 500 ms, not before | `ScanningOverlayView.swift`, `DiagnosticCoordinator.swift` | Not run | Pending |
| P3 | 18.15, 18.27-18.29 | "Retreat to the Shadows" in `phantomTrace` returns to `cannotPutAway` with the same locks, no scan, no signal; hidden while a stage runs | `DiagnosticCoordinator.goBack()`, `PhantomControls.goBackEnabled` | Not run | Decided 2026-11-12 (D-019): Go Back in `phantomTrace` only |
| P4 | 18.16 | Proceed with "I'll deal with these processes myself" does a fresh rescan only and sends no signal | `DiagnosticCoordinator.swift` | Not run | Pending |
| P5 | 18.21 | While mounted, `volumeReleased` shows an Eject button and a Finder-retry note | `PhantomControls.swift` | Not run | Pending |
| P6 | 18.23 | After unmount, `volumeReleased` shows only the message and the Finder instruction, no Eject button | `PhantomControls.swift` | Not run | Pending |
| P7 | 18.26 | After a failed or partial scan, the banner and Rescan show, and Proceed and all stage options are disabled | `PhantomControls.swift` | Not run | Pending |

Steps per item:

- P1: Launch the app and wait: no window appears before a volume is chosen. Inspect a protected path (`/`): only the alert appears, with no empty frame. Inspect a path that does not exist via URL: same.
- P2: Inspect a volume with a fast scan (small image): the frame should not flash before the result. For a slow scan (a volume with many files, or a debug build with an artificial delay), the frame with the overlay appears after about half a second. Note any flicker.
- P3: In `phantomTrace`, choose "Retreat to the Shadows". The window returns to "CANNOT PUT AWAY" with no scan (no overlay) and `tail` and the shell still running. "Summon the Phantom Trace" shows the same locks again with no option selected. Start a stage and check the button is hidden while it runs. It never appears in `volumeReleased`.
- P4: Select "I'll deal with these processes myself" and Proceed. Confirm via `ps` that `tail` and the shell are still running and the table refreshes (the rescan). Confirm the window stays in `phantomTrace` while locks remain.
- P5: With zero locks and the volume mounted, check for the Eject button and the Finder note. Try the Finder retry as the note suggests.
- P6: After the volume has unmounted, check that the Eject button is gone and the Finder instruction is shown.
- P7: Reproduce a failed or partial scan (see 5.6) and check the banner, the enabled Rescan, and the disabled Proceed and stage options.

Open question for the owner: the Failure_Banner kind (failed versus partial) is inferred from the coordinator message prefix because `Banner` has no kind field. This is a known shortcut, not a spec item (see [ProjectLog.md](ProjectLog.md)).

## 9. Cleanup

- [ ] Quit PhantomTrace.
- [ ] Stop the `tail` and shell helpers.
- [ ] `hdiutil detach /Volumes/PTQA` and `rm /tmp/ptqa.dmg`.
- [ ] Remove any temporary app copy made for the missing-asset check.
- [ ] If you installed the Quick Action only for this pass, remove `~/Library/Services/Why Can't I Eject?.workflow` and run `/System/Library/CoreServices/pbs -flush`.
- [ ] Confirm no network activity was observed during the pass (for example with Activity Monitor or `nettop` filtered to PhantomTrace) (15.3).

## Pass record

| Date | Tester | macOS build | App version | Sections run | Failures or notes |
|---|---|---|---|---|---|
| Not run yet | | | | | |
