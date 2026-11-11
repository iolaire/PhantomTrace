# Requirements Document

## Introduction

PhantomTrace is a retro-themed macOS utility that identifies which processes prevent a volume from ejecting. Given a volume, folder, or mounted disk image, PhantomTrace resolves the owning mount point, enumerates and classifies every lock on that volume, and presents the result in a System 7 / Mac OS 9 Platinum-styled diagnostic sheet. The user then walks a graduated, opt-in resolution pipeline: Egress Shells, Graceful Request, Banish Locks, and Clean Handoff (unmount). Every stage is previewed, gated by a safety policy, and re-verified against a fresh scan. These requirements are derived from the approved design document. PhantomTrace is built entirely with Swift Package Manager on a machine that has only the Command Line Tools: a Core library, a CLI, and a programmatic AppKit executable target, assembled into an App_Bundle by a Bundling_Script. There is no Xcode project, Interface Builder file, asset catalog, or SwiftUI preview, and full Xcode.app is not required. PhantomTrace targets macOS "Golden Gate" (27.2.1, build 26B131) or later; earlier macOS versions are out of scope because they cannot be tested.

## Glossary

- **PhantomTrace**: The macOS application, including the Core library, CLI, and AppKit UI.
- **Mount_Resolver**: The component that converts user input into a canonical Mount_Info.
- **Mount_Info**: A record describing a mounted volume (mount point, name, device node, file system type, internal, removable, disk-image flags).
- **Protected_Volume**: The root volume `/`, any path under `/System/Volumes`, and `/private/var/vm`.
- **Lock_Discovery_Engine**: The component that produces the current list of Lock_Records for a volume.
- **Lsof_Parser**: The pure component that parses `lsof -F` field output bytes into Raw_Lsof_Records and Parse_Warnings.
- **Lsof_Printer**: The component that serializes Raw_Lsof_Records into `lsof -F` field output bytes.
- **Raw_Lsof_Record**: A parsed open-file entry containing pid, command, user, fd, access mode, file type, and path bytes.
- **Parse_Warning**: A diagnostic emitted by the Lsof_Parser for malformed, truncated, or invalid input fragments.
- **Lock_Classifier**: The component that converts a Raw_Lsof_Record into a Lock_Record.
- **Lock_Record**: A classified lock with pid, process name, user, Lock_Category, Process_Role, path, and process start time.
- **Lock_Category**: Either `cwd` (current working directory lock) or `openFileHandle`.
- **Process_Role**: One of `systemDaemon`, `idleShell`, `userApplication`, `cliTool`, or `unknown`.
- **Daemon_Allowlist**: The set of command names `mds`, `mds_stores`, `mdworker_shared`, `QuickLookSatellite`, `fseventsd`, `corespotlightd`, and `diskimages-helper`.
- **Shell_Set**: The set of command names `zsh`, `bash`, `fish`, `sh`, `dash`, and `tcsh`.
- **Resolution_Pipeline**: The component that plans and executes the four Resolution_Stages.
- **Resolution_Stage**: One of Egress Shells (1), Graceful Request (2), Banish Locks (3), or Clean Handoff (4).
- **Resolution_Plan**: The set of Proposed_Actions and skipped locks produced for one Resolution_Stage.
- **Proposed_Action**: An action of kind `resetShellCwd`, `quitApplication`, `sendSIGTERM`, `sendSIGKILL`, or `unmount`.
- **Stage_Outcome**: The result of executing a stage: succeeded actions, failed actions, and remaining Lock_Records.
- **Safety_Policy**: The single component that allows or denies every Proposed_Action.
- **Protected_Process**: PID 0, PID 1, PhantomTrace's own PID, and processes named `launchd`, `kernel_task`, `WindowServer`, `loginwindow`, or `Finder`.
- **Process_Identity**: The pair (pid, process start time) used to guard against PID reuse.
- **Unmounter**: The component that unmounts a volume via DiskArbitration with a `diskutil` fallback.
- **Diagnostic_Sheet**: The Platinum-styled window that displays exactly one Window_State at a time, composed of the Window_Frame_Art, one illustration, one Ghost_Mascot sprite, a title plaque, and the content of that Window_State.
- **Window_State**: One of `cannotPutAway` (title plaque "CANNOT PUT AWAY"), `phantomTrace` (title plaque "PHANTOM TRACE"), or `volumeReleased` (title plaque "VOLUME RELEASED"). The Window_State is a presentation layer over the discovery state and adds no discovery state.
- **Window_Selector**: The pure component that selects the Window_State from the discovery state, the Proceeded_Flag, and the current Window_State.
- **Proceeded_Flag**: A Boolean that is set when the user activates the Proceed_Button in the `cannotPutAway` window.
- **Phantom_Choice**: The control in the `phantomTrace` window that offers either "Let PhantomTrace act" with one selectable Resolution_Stage among Egress Shells, Graceful Request, and Banish Locks, or "I'll deal with these processes myself".
- **Proceed_Button**: The single primary button of the `cannotPutAway` and `phantomTrace` windows.
- **Eject_Button**: The button of the `volumeReleased` window that performs the Clean Handoff stage.
- **Scanning_Overlay**: A progress indication drawn inside the current Diagnostic_Sheet while a scan is running, which does not change the Window_State or the Ghost_Mascot sprite.
- **Failure_Banner**: The banner shown in the `phantomTrace` window when discovery fails or returns partial results, containing the description, Parse_Warnings, and the Rescan button.
- **Ghost_Mascot**: The original, Kiro-inspired, left-facing cloaked ghost sprite (not the Kiro ghost) whose Ghost_State is derived from the Window_State.
- **Quick_Action**: The Finder entry point named "Why Can't I Eject?" / "Inspect Volume Locks", implemented as a hand-written `.workflow` bundle and/or an `NSServices` entry in the App_Bundle `Info.plist`.
- **App_Bundle**: The `PhantomTrace.app` macOS application bundle assembled by the Bundling_Script.
- **Bundling_Script**: The shell script `Scripts/make-app.sh` that builds the App_Bundle from the SwiftPM build output.
- **Command_Line_Tools**: The Apple Command Line Tools toolchain, without the full Xcode.app.
- **Entitlements_File**: The file `PhantomTrace.entitlements` declaring the minimal entitlements used when signing the App_Bundle.
- **Sprite_Set**: The set of exported, cropped PNG images (`name.png` at 1x and `name@2x.png` at 2x) loaded by the app: the window frame, one illustration per Window_State, and one Ghost_Mascot sprite per Ghost_State.
- **Ghost_State**: One of `yellow`, `red`, or `green`, the three left-facing sprite states of the Ghost_Mascot, derived from the Window_State: `yellow` for `cannotPutAway`, `red` for `phantomTrace`, and `green` for `volumeReleased`.
- **Title_Font**: An optional bundled bitmap font, not yet chosen, used for title plaque text, stored in `Contents/Resources` with its license file stored beside it. When no Title_Font is present or registrable, a system font is used.
- **Table_Font**: The font of the lock table cells: Monaco loaded by name from the system, falling back to Menlo and then to the system monospaced font. No Apple font file is committed or bundled.
- **Resource_Files**: Plain files (sprites and, when present, the Title_Font) stored in `Contents/Resources` of the App_Bundle and loaded at runtime from the bundle resource directory.
- **Window_Frame_Art**: The window frame image, which is opaque inside the frame and therefore rendered as a 9-slice or with a content cutout.
- **Original_Art**: The source art in `docs/LookAndFeel/original/`.
- **Assets_Record**: The file `docs/Assets.md`, which records the provenance, author, and license terms of every non-code asset (images, fonts, app icon).
- **Drop_Target**: The non-menu-bar window or Dock icon that accepts dropped volumes or folders.
- **CLI**: The `phantomtrace` command-line executable.
- **Blocked_State**: The state in which a fresh scan reports one or more Lock_Records.

## Requirements

### Requirement 1: Resolve Input to a Mount

**User Story:** As a macOS user, I want to give PhantomTrace any file, folder, volume, or disk image, so that it finds the volume I am trying to eject.

#### Acceptance Criteria

1. WHEN a file URL is provided, THE Mount_Resolver SHALL canonicalize the path by resolving all symbolic links and firmlinks before matching mounts, so that the resulting path is absolute and contains no symbolic link or firmlink components.
2. WHEN a canonical path lies under one or more mounts, THE Mount_Resolver SHALL return the Mount_Info of the mount whose mount-point path is the longest prefix of that path, matching on whole path components (for example, the mount point `/Volumes/A` SHALL NOT match the path `/Volumes/AB/file`).
3. WHEN the canonical path equals a mount point exactly, THE Mount_Resolver SHALL return the Mount_Info of that mount.
4. WHEN a `.dmg` file that is currently attached is provided, THE Mount_Resolver SHALL return the Mount_Info of the volume attached from that disk image.
5. WHEN a `.dmg` file is attached with more than one mounted volume, THE Mount_Resolver SHALL return the Mount_Info of the first volume in mount-table order.
6. IF the provided path does not exist, THEN THE Mount_Resolver SHALL return the error `notAMountPoint` and SHALL NOT return a Mount_Info.
7. IF the canonical path lies under no mount in the current mount table, THEN THE Mount_Resolver SHALL return the error `notAMountPoint` and SHALL NOT return a Mount_Info.
8. IF a `.dmg` file is provided that is not currently attached, THEN THE Mount_Resolver SHALL return the error `notAMountPoint` and SHALL NOT return a Mount_Info.
9. THE Mount_Resolver SHALL return a Mount_Info whose mount point is absolute, canonical, present in the current mount table at the time of resolution, and paired with a volume name of at least 1 character.
10. IF the volume name of a mount is empty, THEN THE Mount_Resolver SHALL use the last path component of the mount point as the volume name.

### Requirement 2: Refuse Protected Volumes

**User Story:** As a macOS user, I want PhantomTrace to refuse system volumes, so that I cannot damage my running system.

#### Acceptance Criteria

1. IF the resolved mount is a Protected_Volume, THEN THE Mount_Resolver SHALL return the error `protectedVolume` within 500 milliseconds of receiving the path, and SHALL NOT return a mount result for that path.
2. IF the resolved path is not a mount point, THEN THE Mount_Resolver SHALL return the error `notAMountPoint` within 500 milliseconds of receiving the path.
3. IF the Mount_Resolver returns `protectedVolume` or `notAMountPoint`, THEN THE PhantomTrace SHALL perform no lock scan, SHALL NOT unmount, eject, or modify any volume, and SHALL leave all files and volumes unchanged.
4. IF the Mount_Resolver returns `protectedVolume` or `notAMountPoint`, THEN THE Diagnostic_Sheet SHALL display, within 1 second, an alert stating that the selected item is not a removable volume, with a single dismiss control, and SHALL NOT display lock scan results or any eject action for that item.
5. IF the Mount_Resolver cannot determine whether the resolved path is a mount point or a Protected_Volume (for example, the path no longer exists or cannot be read), THEN THE Mount_Resolver SHALL return an error, THE PhantomTrace SHALL treat the path as protected by performing no lock scan and no system mutation, and THE Diagnostic_Sheet SHALL display an alert stating that the item could not be verified as a removable volume.

### Requirement 3: Discover Locks

**User Story:** As a macOS user, I want a current list of every process locking a volume, so that I know exactly what blocks ejection.

#### Acceptance Criteria

1. WHEN discovery is requested for a Mount_Info, THE Lock_Discovery_Engine SHALL execute `lsof` with machine-readable field output scoped to the mount point of that Mount_Info and pass the captured bytes to the Lsof_Parser.
2. WHEN the Lsof_Parser returns records, THE Lock_Discovery_Engine SHALL pass each record to the Lock_Classifier and return the resulting Lock_Records, one per classified record, before merging and exclusion are applied.
3. WHEN two or more Lock_Records share the same pid and the same path, THE Lock_Discovery_Engine SHALL merge them into a single Lock_Record, so that the returned list contains at most one Lock_Record for each pid and path pair.
4. WHEN the Lock_Discovery_Engine builds its result, THE Lock_Discovery_Engine SHALL exclude every Lock_Record whose pid equals the PhantomTrace process identifier. If the result is empty after exclusion, THE Lock_Discovery_Engine SHALL return an empty list and no error.
5. WHEN discovery is performed twice against an unchanged system state, THE Lock_Discovery_Engine SHALL return results that contain the same Lock_Records (equal in every field) in the same order.
6. IF `lsof` output is truncated or `lsof` runs longer than 15 seconds, THEN THE Lock_Discovery_Engine SHALL terminate the `lsof` process, run `lsof +D` and `fuser -c` against the mount point (each limited to 15 seconds), merge their findings, and return the Lock_Records found with a partial indicator set to true.
7. IF `lsof` is not available, THEN THE Lock_Discovery_Engine SHALL return the error `lsofUnavailable` and no Lock_Records.
8. IF `lsof` runs longer than 15 seconds and the fallback cross-check in criterion 6 returns no usable result (both commands fail, time out, or produce no parseable output), THEN THE Lock_Discovery_Engine SHALL return the error `lsofTimedOut` and no Lock_Records.
9. THE Lock_Discovery_Engine SHALL run scanning off the main actor and SHALL deliver results to callers asynchronously, so that the main actor is never blocked for more than 100 milliseconds by a scan.
10. WHEN a scan is performed on an external drive with at most 100,000 files and at most 50 open files, THE Lock_Discovery_Engine SHALL publish the first results within 2 seconds of the request.

### Requirement 4: Parse lsof Field Output

**User Story:** As a developer, I want a total and byte-faithful lsof parser, so that unusual file names never crash the tool or corrupt results.

#### Acceptance Criteria

1. WHEN any byte sequence of length 0 to 104,857,600 bytes (including empty input, arbitrary binary data, and input containing NUL bytes) is provided, THE Lsof_Parser SHALL return a result containing a list of records and a list of Parse_Warnings and SHALL terminate without raising an error.
2. THE Lsof_Parser SHALL operate on raw bytes and retain the exact unescaped path bytes of each record in `pathBytes`.
3. THE Lsof_Parser SHALL derive the display path from `pathBytes` using lossy UTF-8 decoding, replacing each invalid byte sequence with the Unicode replacement character U+FFFD, without modifying `pathBytes`.
4. WHEN a command or path field contains an lsof octal escape sequence (backslash followed by 1 to 3 octal digits), a hexadecimal escape sequence (backslash followed by `x` and 2 hexadecimal digits), or an escaped backslash (`\\`), THE Lsof_Parser SHALL decode it to the corresponding single byte.
5. THE Lsof_Parser SHALL emit only records whose pid is an integer from 1 to 4,294,967,295 and whose `pathBytes` is non-empty.
6. IF a pid field is not a positive integer in the range 1 to 4,294,967,295, THEN THE Lsof_Parser SHALL emit one Parse_Warning identifying the invalid pid field, discard all records of that process set (from the invalid pid field up to the next valid pid field or end of input), and continue parsing subsequent process sets.
7. IF the input ends in the middle of a field or record, THEN THE Lsof_Parser SHALL emit one Parse_Warning for the truncated tail, omit the incomplete record, and retain all complete records that precede it.
8. WHEN a field with an unknown tag letter is encountered, THE Lsof_Parser SHALL ignore the field and emit the same records as for input without that field.
9. WHEN a path contains spaces, newlines, Unicode, backslashes, or non-UTF-8 bytes, THE Lsof_Parser SHALL emit the record with `pathBytes` byte-for-byte identical to the original path.
10. WHEN the same input bytes are parsed more than once, THE Lsof_Parser SHALL return byte-identical records and Parse_Warnings in the same order each time.
11. THE Lsof_Printer SHALL serialize Raw_Lsof_Records into `lsof -F` field output bytes that the Lsof_Parser accepts and parses without emitting any Parse_Warning.
12. FOR ALL valid Raw_Lsof_Record sets, parsing then printing then parsing SHALL produce a record set equal to the first parse in pid, command, `pathBytes`, and record order (round-trip property).
13. WHEN a prefix of valid input is parsed, THE Lsof_Parser SHALL emit no record that is absent from the parse of the complete input.
14. IF a command or path field contains a malformed escape sequence (a backslash followed by a character that does not form a valid octal, hexadecimal, or escaped-backslash sequence, or by end of field), THEN THE Lsof_Parser SHALL emit one Parse_Warning, retain the backslash and following bytes literally, and continue parsing the record.

### Requirement 5: Classify Locks

**User Story:** As a macOS user, I want each lock labeled by kind and by the role of the process holding it, so that I understand what is safe to act on.

#### Acceptance Criteria

1. WHEN a Raw_Lsof_Record has fd `cwd`, THE Lock_Classifier SHALL assign the Lock_Category `cwd`.
2. WHEN a Raw_Lsof_Record has an fd other than `cwd`, THE Lock_Classifier SHALL assign the Lock_Category `openFileHandle`.
3. WHEN the command of a Raw_Lsof_Record is in the Daemon_Allowlist, THE Lock_Classifier SHALL assign the Process_Role `systemDaemon`, regardless of whether the command is also in the Shell_Set.
4. WHEN the command of a Raw_Lsof_Record is in the Shell_Set, is not in the Daemon_Allowlist, and the foreground process group ID of the controlling terminal of the process equals the process group ID of the shell process itself, THE Lock_Classifier SHALL assign the Process_Role `idleShell`.
5. WHEN the command of a Raw_Lsof_Record is in neither the Daemon_Allowlist nor the Shell_Set, or is in the Shell_Set but fails the idle-shell condition of criterion 4, THE Lock_Classifier SHALL assign exactly one Process_Role as follows: `cliTool` if the process has a controlling terminal, `userApplication` if the process has no controlling terminal and its executable resides in an application bundle, and `unknown` in all other cases.
6. IF the path of a Raw_Lsof_Record does not resolve under the mount point of the volume, THEN THE Lock_Classifier SHALL return no Lock_Record for that record and SHALL continue classifying the remaining records.
7. IF a path lies under a symbolic link whose resolved target is outside the volume, THEN THE Lock_Classifier SHALL return no Lock_Record for that path and SHALL continue classifying the remaining records.
8. WHEN a path resolves under the mount point of the volume, THE Lock_Classifier SHALL return exactly one Lock_Record containing the assigned Lock_Category and Process_Role.
9. WHEN a Lock_Record is created and the process start time is obtainable, THE Lock_Classifier SHALL record the process start time in that Lock_Record.
10. IF the process start time is not obtainable for a Raw_Lsof_Record, THEN THE Lock_Classifier SHALL create the Lock_Record with the start time marked as absent and SHALL NOT discard the record.
11. IF the foreground process group of the terminal cannot be determined for a Raw_Lsof_Record whose command is in the Shell_Set, THEN THE Lock_Classifier SHALL NOT assign the Process_Role `idleShell` and SHALL assign the Process_Role by criterion 5.

### Requirement 6: Enforce Safety Policy

**User Story:** As a macOS user, I want a single safety gate on every action, so that PhantomTrace cannot harm critical processes or my other work.

#### Acceptance Criteria

1. IF a Proposed_Action targets a Protected_Process, THEN THE Safety_Policy SHALL deny the action in every Resolution_Stage, return a denial result identifying the reason as a protected process, and leave the target process unmodified.
2. IF a Proposed_Action targets a process owned by a user other than the current user and no authorization exists for that Process_Identity, THEN THE Safety_Policy SHALL deny the action, return a denial result identifying the reason as missing authorization, and leave the target process unmodified.
3. IF a `sendSIGKILL` Proposed_Action targets a Process_Identity with no recorded prior `sendSIGTERM` or `quitApplication` attempt for that same Process_Identity, THEN THE Safety_Policy SHALL deny the action and return a denial result identifying the reason as escalation required.
4. WHERE the target Process_Role is `systemDaemon` and the user has explicitly confirmed that specific Process_Identity for the current resolution run, THE Safety_Policy SHALL allow a `sendSIGKILL` Proposed_Action without a recorded prior `sendSIGTERM` or `quitApplication` attempt, provided the target is not a Protected_Process and the Proposed_Action does not violate the authorization rule in criterion 2.
5. WHEN a Proposed_Action targets a process owned by the current user, is not a Protected_Process, and satisfies the stage-ordering rule, and no denial rule in criteria 1 to 3 applies, THE Safety_Policy SHALL allow the action and return an approval result.
6. IF the Safety_Policy cannot determine the owner, protection status, or recorded attempt history of the target within 1000 ms, THEN THE Safety_Policy SHALL deny the action, return a denial result identifying the reason as undetermined safety state, and leave the target process unmodified.
7. THE Safety_Policy SHALL be the sole path through which Resolution_Pipeline actions are approved before reaching a signal or unmount adapter.
8. WHEN a signal is about to be sent, THE Resolution_Pipeline SHALL compare the target Process_Identity with the Process_Identity recorded at discovery and send the signal only if the two are equal.
9. IF the target Process_Identity differs from the Process_Identity recorded at discovery at send time, THEN THE Resolution_Pipeline SHALL skip the action without sending any signal, record the error `processIdentityChanged` against the original Process_Identity, and continue with the remaining actions.

### Requirement 7: Stage 1 — Egress Shells

**User Story:** As a terminal user, I want idle shells moved off the volume without being killed, so that I keep my terminal sessions.

#### Acceptance Criteria

1. WHEN the Egress Shells stage is planned, THE Resolution_Pipeline SHALL propose exactly one `resetShellCwd` action for each Lock_Record with Lock_Category `cwd` and Process_Role `idleShell`, and SHALL propose no `resetShellCwd` action for any other Lock_Record.
2. WHEN a `resetShellCwd` action is allowed and the terminal of the shell is scriptable, THE Resolution_Pipeline SHALL send the fixed literal text ` cd ~` (a leading space, followed by `cd ~`, followed by a single newline) to that terminal session exactly once.
3. WHEN a `resetShellCwd` action completes, THE Resolution_Pipeline SHALL re-inspect the shell process within 5 seconds and mark the action as succeeded only if the shell process is still running and its working directory is not on the volume.
4. IF the re-inspection within 5 seconds of a completed `resetShellCwd` action shows that the shell process has exited or its working directory is still on the volume, THEN THE Resolution_Pipeline SHALL mark the action as failed, display an error indicating which condition was found for that pid, and leave the shell process running without sending further text or signals to it.
5. IF the shell has no terminal, is running a foreground job, or its terminal is not scriptable, THEN THE Resolution_Pipeline SHALL send no text to that shell, mark the action as manual, and display an instruction to run `cd ~` in the terminal for that pid.
6. IF sending the text to a scriptable terminal fails, THEN THE Resolution_Pipeline SHALL mark the action as failed, display an error indicating the send failure for that pid, and not retry the send.
7. THE Resolution_Pipeline SHALL derive the text injected into a terminal only from the fixed literal ` cd ~`, and SHALL NOT include any value taken from process data, volume paths, or user input in that text.

### Requirement 8: Stage 2 — Graceful Request

**User Story:** As a user, I want to ask applications to quit politely first, so that I do not lose unsaved work.

#### Acceptance Criteria

1. WHEN the Graceful Request stage is planned, THE Resolution_Pipeline SHALL propose exactly one `quitApplication` action for each distinct GUI application pid in the Lock_Records, and SHALL NOT propose more than one `quitApplication` action for the same pid.
2. WHEN the Graceful Request stage is planned, THE Resolution_Pipeline SHALL propose exactly one `sendSIGTERM` action for each distinct non-GUI pid in the Lock_Records that is not a protected daemon, and SHALL NOT propose more than one `sendSIGTERM` action for the same pid.
3. WHEN the Graceful Request stage is planned and a pid in the Lock_Records is a protected daemon, THE Resolution_Pipeline SHALL exclude that pid from the proposed actions and SHALL NOT send `sendSIGTERM` or `quitApplication` to it.
4. WHEN the Graceful Request stage is planned and the Lock_Records contain no eligible pids, THE Resolution_Pipeline SHALL propose zero actions, SHALL NOT wait for the grace period, and SHALL report the stage as having no actions to the user.
5. WHEN all graceful actions for the stage have been sent, THE Resolution_Pipeline SHALL wait for the stage grace period, which defaults to 5 seconds and is configurable from 1 to 60 seconds, and SHALL then rescan for locks.
6. WHEN a `quitApplication` or `sendSIGTERM` action is performed for a pid, THE Resolution_Pipeline SHALL record exactly one graceful attempt for that Process_Identity, including the action type and the time it was performed.
7. IF a `quitApplication` or `sendSIGTERM` action fails to be delivered to a pid (for example, because the process has already exited or permission is denied), THEN THE Resolution_Pipeline SHALL report the failure for that Process_Identity to the user with an error indication of the cause, SHALL still record the graceful attempt as failed, and SHALL continue performing the remaining graceful actions.

### Requirement 9: Stage 3 — Banish Locks

**User Story:** As a user, I want a last-resort targeted kill of stubborn processes, so that I can eject when polite requests fail.

#### Acceptance Criteria

1. WHEN the Banish Locks stage is planned, THE Resolution_Pipeline SHALL perform a fresh scan completed no more than 5 seconds before planning and SHALL propose `sendSIGKILL` only for pids that appear in that fresh scan and for which a graceful attempt (Stage 1 or Stage 2) has been recorded.
2. IF no pid in the fresh scan has a recorded graceful attempt, THEN THE Resolution_Pipeline SHALL propose zero `sendSIGKILL` actions and THE Diagnostic_Sheet SHALL display a message indicating that no eligible processes exist for Banish Locks.
3. IF the fresh scan fails or does not complete within 10 seconds, THEN THE Resolution_Pipeline SHALL propose zero `sendSIGKILL` actions, SHALL leave all processes unchanged, and THE Diagnostic_Sheet SHALL display an error indicating that the scan failed.
4. WHEN a `sendSIGKILL` action is proposed, THE Diagnostic_Sheet SHALL list, for each targeted process, its process name and pid, and SHALL display this list before any `sendSIGKILL` is executed.
5. WHILE the user has not explicitly confirmed the Banish Locks stage, THE Resolution_Pipeline SHALL execute zero `sendSIGKILL` actions.
6. WHEN the user confirms the Banish Locks stage, THE Resolution_Pipeline SHALL re-verify that each targeted pid still exists with the same process name and, IF a pid no longer exists or its process name has changed, THEN THE Resolution_Pipeline SHALL skip that pid, send no `sendSIGKILL` to it, and report it as skipped in the Diagnostic_Sheet.

### Requirement 10: Stage 4 — Clean Handoff

**User Story:** As a user, I want the volume unmounted only when nothing is holding it, so that data is never corrupted by a forced eject.

The 10-second scan limit in this requirement applies specifically to the Clean Handoff pre-unmount scan (criteria 1 and 4). General stage scans in Requirement 11 use a separate 30-second limit.

#### Acceptance Criteria

1. WHEN the Clean Handoff stage is requested, THE Resolution_Pipeline SHALL perform a fresh pre-unmount discovery scan of the target volume and complete it before any unmount call is issued, with the pre-unmount scan completing within 10 seconds.
2. WHEN the fresh scan reports zero Lock_Records and the user has confirmed the unmount, THE Unmounter SHALL unmount the volume using DiskArbitration with default unmount options and SHALL report success to the user once the volume is no longer mounted.
3. IF the fresh scan reports one or more Lock_Records, THEN THE Resolution_Pipeline SHALL issue no unmount call, SHALL return to the Blocked_State, and SHALL display the newly discovered Lock_Records.
4. IF the pre-unmount scan does not complete within 10 seconds or fails with an error, THEN THE Resolution_Pipeline SHALL issue no unmount call, SHALL remain in its current stage, and SHALL display an error indicating the scan failure.
5. IF the DiskArbitration unmount fails with a result other than `kDAReturnBusy`, THEN THE Unmounter SHALL make exactly one attempt to unmount using `/usr/sbin/diskutil unmount` invoked with an argument array and without a shell.
6. IF the DiskArbitration unmount or the `/usr/sbin/diskutil unmount` attempt returns `kDAReturnBusy` or `EBUSY`, THEN THE Resolution_Pipeline SHALL perform a rescan, SHALL return to the Blocked_State, and SHALL display the newly discovered Lock_Records.
7. IF the DiskArbitration unmount and the `/usr/sbin/diskutil unmount` attempt both fail for reasons other than `kDAReturnBusy` or `EBUSY`, THEN THE Unmounter SHALL return the error `unmountFailed` containing the error code of the last failed attempt, SHALL leave the volume mounted and unmodified, and THE Resolution_Pipeline SHALL display an error indicating the unmount failed.
8. WHERE the user has requested force unmount through the advanced confirmation, THE Unmounter SHALL perform a force unmount.
9. WHEN force unmount has not been requested through the advanced confirmation, THE Unmounter SHALL use a non-forced unmount.

### Requirement 11: Rescan and Stage Verification

**User Story:** As a user, I want each stage to act on fresh information, so that PhantomTrace never acts on stale state.

The 30-second scan limits in this requirement apply to the general stage-start scan and post-stage rescan of Stages 1 to 3. The Clean Handoff pre-unmount scan is governed by the 10-second limit in Requirement 10.

#### Acceptance Criteria

1. WHEN a Resolution_Stage begins, THE Resolution_Pipeline SHALL perform a fresh discovery scan and build the Resolution_Plan only from the results of that scan, without reusing Lock_Records from any earlier scan.
2. WHEN a Resolution_Stage completes, THE Resolution_Pipeline SHALL perform a rescan and return in the Stage_Outcome the complete list of Lock_Records that remain after the rescan, or an empty list if none remain.
3. WHEN a Resolution_Stage completes, THE Resolution_Pipeline SHALL wait 500 milliseconds after the last action of that stage before starting the post-stage rescan.
4. IF a post-stage rescan does not complete within 30 seconds, THEN THE Resolution_Pipeline SHALL abort the rescan, return a Stage_Outcome marked as rescan-timed-out with no remaining Lock_Records reported as verified, and indicate the timeout to the user.
5. WHEN a Resolution_Plan is built, THE Resolution_Pipeline SHALL present to the user, before any execution, the plan's Proposed_Actions and each skipped lock together with its denial reason.
6. THE Resolution_Pipeline SHALL execute a Resolution_Stage only after the user has explicitly selected that specific stage in the current session, and SHALL NOT execute any stage that has not been selected.
7. IF a Proposed_Action is denied by the Safety_Policy, THEN THE Resolution_Pipeline SHALL exclude the action from execution and list it in the Resolution_Plan as skipped, with the denial reason stated.
8. IF the fresh discovery scan at the start of a Resolution_Stage fails or does not complete within 30 seconds, THEN THE Resolution_Pipeline SHALL NOT build or execute a Resolution_Plan, SHALL leave all locks unchanged, and SHALL indicate the failure to the user.

### Requirement 12: Entry Points

**User Story:** As a Finder user, I want to start an inspection directly from Finder, so that I do not need a menu-bar widget.

#### Acceptance Criteria

1. WHEN the Quick_Action is invoked on a selected item, THE PhantomTrace SHALL open the URL `phantomtrace://inspect?path=<percent-encoded path>` and begin volume resolution within 2 seconds of invocation.
2. WHEN a volume icon or folder is dropped on the Drop_Target, THE PhantomTrace SHALL begin volume resolution for the dropped item within 2 seconds of the drop.
3. WHEN a `phantomtrace://` URL is received, THE PhantomTrace SHALL percent-decode the path, canonicalize it (resolving symbolic links, `.` and `..` segments, and redundant separators), and use only the canonicalized path for subsequent operations.
4. IF a `phantomtrace://` URL is malformed, has no `path` parameter, has an empty `path` value, has a `path` value longer than 1024 characters, or the canonicalized path does not exist, THEN THE PhantomTrace SHALL reject the request, display an error message indicating the reason for rejection, and not begin any scan.
5. WHEN the CLI is invoked with a path, THE CLI SHALL resolve the volume, run discovery, and print the Lock_Records to standard output.
6. IF the CLI is invoked with no path, an invalid path, or a path that cannot be resolved to a volume, THEN THE CLI SHALL print an error message indicating the reason to standard error, print no Lock_Records, and exit with a non-zero status.
7. WHEN the CLI completes discovery successfully, THE CLI SHALL exit with status 0.
8. THE PhantomTrace SHALL provide a script that installs the Quick_Action.
9. IF the Quick_Action installation script fails, THEN THE PhantomTrace SHALL print an error message indicating the cause, exit with a non-zero status, and leave any previously installed Quick_Action unchanged.
10. THE PhantomTrace SHALL implement the Quick_Action as a hand-written `.workflow` bundle composed of plain property list files, as an `NSServices` entry in the App_Bundle `Info.plist`, or as both, and SHALL NOT use App Intents.
11. WHEN the Quick_Action installation script succeeds, THE PhantomTrace SHALL have copied the `.workflow` bundle to `~/Library/Services` and refreshed the Services list.

### Requirement 13: Diagnostic Sheet and Ghost Mascot

**User Story:** As a user, I want a clear, themed diagnostic sheet, so that I can read the results and pick the next step easily.

#### Acceptance Criteria

1. WHEN the Window_State is `phantomTrace` and one or more Lock_Records are available, THE Diagnostic_Sheet SHALL display a table with the columns Process Name, PID, User, Lock Category, and File Path, with one row per Lock_Record.
2. WHEN a File Path is wider than its column, THE Diagnostic_Sheet SHALL truncate the path in the middle with an ellipsis, keeping the first and last path components visible, and SHALL show the full untruncated path in a tooltip within 1 second of the pointer resting on the cell.
3. THE Diagnostic_Sheet SHALL display in the `phantomTrace` window one Phantom_Choice control, containing one selectable option for each of Egress Shells, Graceful Request, and Banish Locks in stage order under "Let PhantomTrace act" and one option "I'll deal with these processes myself", together with exactly one Proceed_Button. Clean Handoff is not an option of the Phantom_Choice; it is performed by the Eject_Button.
4. IF a Resolution_Stage is not applicable to the current Lock_Records, THEN THE Diagnostic_Sheet SHALL show the Phantom_Choice option for that stage as disabled, SHALL ignore activation of it, and SHALL expose the disabled state to VoiceOver.
5. WHILE a Resolution_Stage is executing, THE Diagnostic_Sheet SHALL display a progress state on the Proceed_Button, SHALL dim the lock table, and SHALL disable the Proceed_Button and every Phantom_Choice option.
6. WHILE the Window_State is `cannotPutAway`, THE Ghost_Mascot SHALL display the `yellow` sprite.
7. WHILE the Window_State is `phantomTrace`, THE Ghost_Mascot SHALL display the `red` sprite.
8. WHILE the Window_State is `volumeReleased`, THE Ghost_Mascot SHALL display the `green` sprite.
9. THE Diagnostic_Sheet SHALL render pinstripe title bars, 1-pixel beveled frames, and a platinum gray (#DDDDDD) background.
10. WHERE the user has enabled Reduce Motion, THE Ghost_Mascot SHALL display its current sprite as a static image with no glow animation.
11. THE Diagnostic_Sheet SHALL provide a non-empty VoiceOver label for every custom control, including each Resolution_Stage button and the Ghost_Mascot.
12. WHEN a Lock_Record belongs to a process owned by a user other than the current user, THE Diagnostic_Sheet SHALL display that row as read-only with a lock icon and a visible text explanation that the process is owned by another user, and SHALL exclude that Lock_Record from the targets of every Resolution_Stage.
13. IF the discovery state is Blocked_State and no Lock_Records are available, THEN THE Diagnostic_Sheet SHALL display an empty table with a text message stating that no lock details could be retrieved, and SHALL disable every Phantom_Choice option that selects a Resolution_Stage.
14. THE Diagnostic_Sheet SHALL provide a non-empty VoiceOver label for the Phantom_Choice, each of its options, the Proceed_Button, the Eject_Button, the Failure_Banner, the Rescan button, and each illustration, and WHERE the user has enabled Reduce Motion, THE Diagnostic_Sheet SHALL display every sprite and illustration as a static image with no animation.

### Requirement 14: Error Reporting

**User Story:** As a user, I want clear errors and recovery options, so that I can act when something goes wrong.

#### Acceptance Criteria

1. IF discovery fails or returns partial results, THEN THE Diagnostic_Sheet SHALL display a banner within 500 ms of the discovery state changing to Failed or Partial, where the banner contains a text description identifying whether discovery failed or returned partial results, every Parse_Warning produced during that discovery run (up to a maximum of 100 displayed, with a count of any omitted warnings), and an enabled Rescan button.
2. WHEN the user activates the Rescan button, THE PhantomTrace SHALL start a new discovery run and SHALL clear the previous banner and Parse_Warnings once the new run begins.
3. IF a signal returns `EPERM`, THEN THE Resolution_Pipeline SHALL record the error `permissionDenied` together with the pid of the target process, mark that action as failed in the Stage_Outcome, continue processing the remaining actions in the stage, and SHALL NOT attempt privilege escalation unless the user explicitly initiates it through a user-activated control.
4. IF the discovery state is Failed, THEN THE PhantomTrace SHALL terminate the workflow without sending any signal, modifying any file, or changing any process state, and SHALL leave the Diagnostic_Sheet open showing the failure banner.
5. WHEN a Stage_Outcome contains one or more failed actions, THE Diagnostic_Sheet SHALL list every failed action (up to a maximum of 500 displayed, with a count of any omitted entries), each entry showing the target pid and an error indication that identifies the error kind (for example `permissionDenied`).

### Requirement 15: Process Execution and Security

**User Story:** As a security-conscious user, I want PhantomTrace to handle untrusted data safely, so that file names cannot compromise my system.

#### Acceptance Criteria

1. WHEN PhantomTrace launches a subprocess, THE PhantomTrace SHALL pass the executable path and each argument as a separate element of an argument array, and SHALL NOT invoke a shell (such as `/bin/sh -c`) or concatenate paths or `lsof` output into a command string.
2. WHEN PhantomTrace parses `lsof` output, THE PhantomTrace SHALL treat every path and process name as inert data, and SHALL NOT execute, evaluate, or interpret any such value as a command, script, or format string. This applies to values containing spaces, newlines, quotes, backticks, semicolons, `$`, and leading `-` characters.
3. THE PhantomTrace SHALL open zero outbound or inbound network connections and SHALL transmit zero bytes of telemetry, analytics, or crash reports to any remote host.
4. THE PhantomTrace Core library SHALL contain zero `import AppKit` statements and SHALL build successfully in a target that does not link AppKit.
5. THE PhantomTrace SHALL expose each of the following system effects through a protocol that tests can replace with a mock implementation: process execution, signal sending, application quitting, volume unmounting, and file system probing.
6. WHEN a subprocess is launched, THE PhantomTrace SHALL enforce a default timeout of 10 seconds on the subprocess unless a requirement specifies another timeout (lsof discovery: 15 seconds), and SHALL terminate the subprocess if it has not exited when the applicable timeout elapses.
7. IF a subprocess exceeds its timeout, THEN THE PhantomTrace SHALL report a timeout error identifying the command that timed out, SHALL discard any partial output from that subprocess, and SHALL remain responsive to further user actions.
8. IF a path or process name returned by `lsof` begins with a `-` character, THEN THE PhantomTrace SHALL pass it to any subprocess only after an end-of-options marker or as an absolute path, so that it cannot be interpreted as an option.

### Requirement 16: Application Packaging

**User Story:** As a developer on a machine with only the Command Line Tools, I want one script that builds a signed PhantomTrace.app from the SwiftPM output, so that I can run and demo the app without Xcode.

#### Acceptance Criteria

1. WHEN the Bundling_Script is run, THE Bundling_Script SHALL build the `PhantomTraceApp` executable with `swift build` using only the Command_Line_Tools, and SHALL NOT invoke `xcodebuild`, `actool`, or Interface Builder.
2. WHEN the build succeeds, THE Bundling_Script SHALL assemble the App_Bundle at `build/PhantomTrace.app` containing `Contents/MacOS/PhantomTrace`, `Contents/Info.plist`, and `Contents/Resources`.
3. THE Bundling_Script SHALL write an `Info.plist` that declares `CFBundleExecutable`, `CFBundleIdentifier`, `LSMinimumSystemVersion` with the value `27.2.1`, and a `CFBundleURLTypes` entry registering the `phantomtrace` URL scheme.
4. WHERE an `NSServices` Quick_Action is shipped, THE Bundling_Script SHALL include the `NSServices` entry in the `Info.plist`.
5. THE Bundling_Script SHALL copy the Sprite_Set into `Contents/Resources` of the App_Bundle, and WHERE a Title_Font file and its license file are present, THE Bundling_Script SHALL copy both into `Contents/Resources` of the App_Bundle.
6. WHEN the App_Bundle is assembled, THE Bundling_Script SHALL sign it with `codesign` using the hardened runtime option and the Entitlements_File, using the ad-hoc identity `-` unless another identity is provided.
7. THE Entitlements_File SHALL declare only the entitlements required by PhantomTrace and SHALL NOT enable the App Sandbox.
8. WHEN signing completes, THE Bundling_Script SHALL run `codesign --verify --strict` on the App_Bundle and SHALL report success only if verification passes.
9. IF any step of the Bundling_Script fails, THEN THE Bundling_Script SHALL print an error message naming the failed step and its cause to standard error and exit with a non-zero status.
10. IF any step of the Bundling_Script fails, THEN THE Bundling_Script SHALL leave any previously existing App_Bundle at `build/PhantomTrace.app` unchanged, by assembling the new bundle in a temporary location and replacing the previous bundle only after signing and verification succeed.
11. WHEN the Bundling_Script completes successfully, THE Bundling_Script SHALL exit with status 0.
12. THE PhantomTrace documentation SHALL describe notarization with `xcrun notarytool submit --wait` and `xcrun stapler staple` as a manual, optional step, and THE Bundling_Script SHALL NOT perform notarization.

### Requirement 17: Asset Pipeline and Resource Loading

**User Story:** As a developer and designer, I want sprites and fonts delivered as plain bundle files with safe fallbacks, so that the retro look works without Xcode asset tooling and a missing image never breaks the app.

#### Acceptance Criteria

1. THE PhantomTrace SHALL load every sprite and font from Resource_Files in the App_Bundle resource directory, and SHALL NOT use an asset catalog (`.xcassets`).
2. WHERE a Title_Font file is present in the Resource_Files, THE PhantomTrace SHALL register it at launch using `CTFontManagerRegisterFontsForURL`.
3. THE Sprite_Set SHALL contain, each as one cropped image at 1x (`name.png`) and one at 2x (`name@2x.png`) named in kebab-case: `window-frame`, `shackled-volume-and-padlocks`, `crt-diagnostic-portal`, `shattered-chains-and-portullis`, `ghost-looking-left-yellow`, `ghost-looking-left-red`, and `ghost-looking-left-green`.
4. WHEN a sprite is loaded, THE PhantomTrace SHALL compose a single image from its 1x and 2x files.
5. THE Diagnostic_Sheet SHALL render Window_Frame_Art as a 9-slice with fixed corners and edges, or with a content cutout, and SHALL place the table and buttons inside the interior rectangle.
6. THE PhantomTrace SHALL record the 9-slice insets of Window_Frame_Art alongside the sprite files.
7. IF a sprite file is missing or cannot be decoded, THEN THE Diagnostic_Sheet SHALL render a text or system-drawn substitute for that image, log the name of the missing file, and keep all other Diagnostic_Sheet functions operational.
8. IF no Title_Font file is present or the Title_Font cannot be registered, THEN THE Diagnostic_Sheet SHALL render title text with a system font and keep all other Diagnostic_Sheet functions operational.
9. THE PhantomTrace asset tooling SHALL NOT modify, overwrite, or delete any file in `docs/LookAndFeel/original/`.
10. WHEN the asset tooling produces transparent full-size PNGs, THE PhantomTrace asset tooling SHALL write them to `docs/LookAndFeel/use/`.
11. THE PhantomTrace documentation SHALL record the confirmed mapping from Window_State to image files: `cannotPutAway` uses `shackled-volume-and-padlocks` and `ghost-looking-left-yellow`, `phantomTrace` uses `crt-diagnostic-portal` and `ghost-looking-left-red`, and `volumeReleased` uses `shattered-chains-and-portullis` and `ghost-looking-left-green`, all inside the shared `window-frame`.
12. THE PhantomTrace documentation SHALL record in the Assets_Record, before the project is submitted, the provenance and license of the Original_Art, the result and date of the side-by-side check of the Ghost_Mascot against the official Kiro ghost, and the name, author, version, source, and license of the Title_Font WHERE a Title_Font is bundled.
13. THE PhantomTrace asset tooling written in Python SHALL pin its dependencies in `Scripts/requirements.txt` and SHALL NOT be included in the App_Bundle.
14. THE Diagnostic_Sheet SHALL draw the title plaque text of each Window_State in the Title_Font WHERE the Title_Font is available, otherwise in a system font, and SHALL NOT rely on text baked into the Window_Frame_Art.
15. THE PhantomTrace SHALL use no Kiro logo and no Kiro ghost artwork in the app, the app icon, or any bundled asset.
16. THE Diagnostic_Sheet SHALL draw lock table cell text in the Table_Font, using Monaco when installed, Menlo when Monaco is unavailable, and the system monospaced font when both are unavailable.
17. THE PhantomTrace repository and App_Bundle SHALL contain no Apple font file (Monaco, Menlo, SF, or Chicago).
18. WHEN an asset is added, replaced, or bundled, THE PhantomTrace documentation SHALL be updated in the Assets_Record in the same change.

### Requirement 18: Window States and Window Selection

**User Story:** As a user, I want one clear window for each phase of the investigation, so that I always know whether my disk is blocked, being traced, or released.

Provisional items, pending user confirmation: criteria 6, 7, 15, 16, 21, 23, and 26 implement proposals from the design's open questions and may change after confirmation.

#### Acceptance Criteria

1. WHEN the discovery state is Clean, Unmounting, or Unmounted, THE Window_Selector SHALL select the Window_State `volumeReleased`.
2. WHILE the discovery state is Blocked_State and the Proceeded_Flag is not set and the current Window_State is not `phantomTrace`, THE Window_Selector SHALL select the Window_State `cannotPutAway`.
3. WHILE the discovery state is Blocked_State and either the Proceeded_Flag is set or the current Window_State is `phantomTrace`, THE Window_Selector SHALL select the Window_State `phantomTrace`.
4. WHEN a scan fails or returns partial results, THE Window_Selector SHALL select the Window_State `phantomTrace`.
5. WHILE a scan is running, THE Diagnostic_Sheet SHALL keep the current Window_State and Ghost_State unchanged and SHALL display a Scanning_Overlay.
6. WHILE the discovery state is Idle or Resolving, or Failed because of a resolution error under Requirement 2, THE Diagnostic_Sheet SHALL display no Window_State content (provisional, pending user confirmation).
7. IF the first scan of a resolved volume runs longer than 500 milliseconds, THEN THE Diagnostic_Sheet SHALL display the Window_Frame_Art with a Scanning_Overlay until the first scan result arrives (provisional, pending user confirmation).
8. THE Diagnostic_Sheet SHALL derive the Ghost_State only from the Window_State.
9. WHEN the volume is no longer present in the mount table, THE Window_Selector SHALL select the Window_State `volumeReleased` with the volume marked as no longer mounted, from any current Window_State.
10. THE Diagnostic_Sheet SHALL display the title plaque "CANNOT PUT AWAY", the illustration `shackled-volume-and-padlocks`, and the `yellow` Ghost_Mascot in the `cannotPutAway` window.
11. THE Diagnostic_Sheet SHALL display in the `cannotPutAway` window a spooky-style message that the disk cannot be put away, a question asking whether to run a Phantom Trace, one Proceed_Button, and a close box.
12. WHEN the user activates the Proceed_Button in the `cannotPutAway` window, THE Diagnostic_Sheet SHALL set the Proceeded_Flag and display the `phantomTrace` window.
13. THE Diagnostic_Sheet SHALL display the title plaque "PHANTOM TRACE", the illustration `crt-diagnostic-portal`, the `red` Ghost_Mascot, the lock table, the Phantom_Choice, and one Proceed_Button in the `phantomTrace` window.
14. WHILE no option of the Phantom_Choice is selected, THE Diagnostic_Sheet SHALL disable the Proceed_Button.
15. THE Diagnostic_Sheet SHALL provide no control that returns from the `phantomTrace` window to the `cannotPutAway` window (provisional, pending user confirmation).
16. WHEN the user activates the Proceed_Button with the option "I'll deal with these processes myself" selected, THE Resolution_Pipeline SHALL perform a fresh rescan, SHALL send no signal, and SHALL leave all processes unchanged (provisional, pending user confirmation).
17. WHEN the user activates the Proceed_Button with a Resolution_Stage selected, THE Resolution_Pipeline SHALL execute that stage under Requirements 6 to 9 and 11, including the plan preview and, for Banish Locks, the explicit confirmation, and SHALL then perform a fresh rescan.
18. WHEN a rescan started from the `phantomTrace` window finds one or more Lock_Records, THE Diagnostic_Sheet SHALL remain in the `phantomTrace` window and display the remaining Lock_Records.
19. WHEN a rescan started from the `phantomTrace` window finds zero Lock_Records, THE Window_Selector SHALL select the Window_State `volumeReleased`.
20. THE Diagnostic_Sheet SHALL display the title plaque "VOLUME RELEASED", the illustration `shattered-chains-and-portullis`, the `green` Ghost_Mascot, and a spooky-style message on how to proceed in the `volumeReleased` window.
21. WHILE the volume is still mounted, THE Diagnostic_Sheet SHALL display in the `volumeReleased` window an Eject_Button and a note that retrying Eject in Finder also works (provisional, pending user confirmation).
22. WHEN the user activates the Eject_Button, THE Resolution_Pipeline SHALL perform the Clean Handoff stage under Requirement 10.
23. WHILE the volume is no longer mounted, THE Diagnostic_Sheet SHALL display in the `volumeReleased` window only the message and the instruction to retry in Finder, with no Eject_Button (provisional, pending user confirmation).
24. WHILE the Unmounter is unmounting, THE Diagnostic_Sheet SHALL display a progress state on the Eject_Button and disable it.
25. IF the unmount returns `kDAReturnBusy` or `EBUSY`, THEN THE Diagnostic_Sheet SHALL display the `phantomTrace` window with the newly discovered Lock_Records and the `red` Ghost_Mascot.
26. IF a scan fails or returns partial results, THEN THE Diagnostic_Sheet SHALL display the Failure_Banner of Requirement 14.1 in the `phantomTrace` window with an enabled Rescan button, and SHALL disable the Proceed_Button and every Phantom_Choice option that selects a Resolution_Stage (provisional, pending user confirmation).
