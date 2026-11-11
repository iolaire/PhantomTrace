# Demo Script

The demo length target is at most 3 minutes (180 seconds). The Rules require a public YouTube video, under 3 minutes, that shows the app running on a Mac. This is a plan: nothing below exists yet, so do not record until the app, Quick Action, and UI work.

Source flow: [ProjectOverview.md](ProjectOverview.md). Visual targets: [LookAndFeel](LookAndFeel/README.md).

## Setup (before recording)

Use a throwaway disk image, never a real drive.

1. Create and attach a small image, for example `hdiutil create -size 20m -fs APFS -volname DemoDrive demo.dmg`, then `hdiutil attach demo.dmg`.
2. Create the haunting: in Terminal, `cd /Volumes/DemoDrive` and leave the shell idle (a cwd lock). In another process, hold a file open (for example `tail -f /Volumes/DemoDrive/notes.txt`, or open a document from the volume in a GUI app).
3. Install the Quick Action (`Scripts/install-quick-action.sh`, once it exists) and confirm Terminal automation permission is granted.
4. Close notifications, set a clean Desktop, and hide unrelated windows. No third-party trademarks, music, or copyrighted material in frame.

## Timeline (target 170 seconds)

| Time | Beat | On screen | Narration idea |
|---|---|---|---|
| 0:00 to 0:15 | The problem | Finder: try to eject DemoDrive, see "The disk wasn't ejected because one or more programs may be using it" | "Finder tells you something is using the disk. It never says what." |
| 0:15 to 0:30 | The old way | Terminal with `lsof` output scrolling | "Today that means lsof, guesswork, and sometimes pulling the cable." |
| 0:30 to 0:45 | The trigger | Right-click the volume, Quick Actions, "Why Can't I Eject?" | "PhantomTrace starts from Finder, no menu-bar widget." |
| 0:45 to 1:10 | Reveal | Diagnostic Sheet: haunting ghost, table with process name, pid, user, lock category, path | "An idle zsh sitting in the volume, and an app holding a file open." |
| 1:10 to 1:25 | Safety | Plan preview with skipped locks and reasons; a protected or other-user process shown read-only | "Nothing runs until you choose it, and protected processes are never touched." |
| 1:25 to 1:45 | Stage 1 | Egress Shells: the Terminal prompt returns to home, session alive | "The shell moves out without being killed." |
| 1:45 to 2:10 | Stage 2 | Graceful Request: app quits politely; table rescans | "Ask politely first. It rescans after every stage." |
| 2:10 to 2:25 | Stage 3 (only if needed) | Banish Locks confirmation listing name and pid | "A last resort, with an explicit confirmation." |
| 2:25 to 2:45 | Clean handoff | Clean Handoff: ghost turns "VOLUME RELEASED", volume disappears from Finder | "Zero locks, then a normal unmount." |
| 2:45 to 2:55 | Close | Title card: PhantomTrace, Resurrection category, built with Kiro | "Resurrecting What's Keeping Me? for modern macOS." |

Keep 10 seconds of slack. If a beat runs long, cut the old-way beat first.

## Mention Kiro (judging)

One quick cutaway (5 to 10 seconds, inside the budget) showing `.kiro/specs`, `.kiro/steering`, `.kiro/hooks`, and a passing property-test run, with a line on how specs and hooks shaped the build. Evidence belongs in [KiroUsage.md](KiroUsage.md).

## Fallbacks and checks

- Rehearse twice; reset the image between takes (detach, recreate, re-haunt).
- If Terminal automation is denied, show the manual-instruction path for Stage 1 instead.
- Confirm the recording shows macOS 27.2.1 (build 26B131) and a visible clock or About screen if possible.
- Upload as public on YouTube, then paste the link into [SubmissionChecklist.md](SubmissionChecklist.md) and the submission form.
