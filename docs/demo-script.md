# Demo Script

The demo length target is at most 3 minutes (180 seconds). The Rules require a public YouTube video, under 3 minutes, that shows the app running on a Mac. This is a plan and the video has not been recorded. The app, Quick Action, and window flow passed the owner's manual end-to-end test on 2026-11-12, so recording can start once the setup below is rehearsed.

Source flow: [ProjectOverview.md](ProjectOverview.md). Visual targets: [LookAndFeel](LookAndFeel/README.md).

## Setup (before recording)

Use a throwaway disk image, never a real drive.

1. Create and attach a small image, for example `hdiutil create -size 20m -fs APFS -volname DemoDrive demo.dmg`, then `hdiutil attach demo.dmg`.
2. Create the haunting: in Terminal, `cd /Volumes/DemoDrive` and leave the shell idle (a cwd lock). In another process, hold a file open (for example `tail -f /Volumes/DemoDrive/notes.txt`, or open a document from the volume in a GUI app).
3. Install the Quick Action (`Scripts/install-quick-action.sh`), enable it under Quick Actions > Customize in Finder, and confirm Terminal automation permission is granted.
4. Close notifications, set a clean Desktop, and hide unrelated windows. No third-party trademarks, music, or copyrighted material in frame.

## Timeline (target 170 seconds)

| Time | Beat | On screen | Narration idea |
|---|---|---|---|
| 0:00 to 0:06 (new scene `s00-intro`) | Opening image | Frame 0 is already the finished poster (yellow ghost, "PhantomTrace", "Why can't I eject?"); a colored glitch settles and embers rise. Never blank | "Why won't this drive eject? Meet PhantomTrace." |
| 0:00 to 0:15 | The problem | Finder: try to eject DemoDrive, see "The disk wasn't ejected because one or more programs may be using it" | "Finder tells you something is using the disk. It never says what." |
| 0:15 to 0:30 | The old way | Terminal with `lsof` output scrolling | "Today that means lsof, guesswork, and sometimes pulling the cable." |
| 0:30 to 0:45 | The trigger | Right-click the volume, Quick Actions, "Why Can't I Eject?" | "PhantomTrace starts from Finder, no menu-bar widget." |
| 0:45 to 1:10 | Reveal | Diagnostic Sheet: haunting ghost, table with process name, pid, user, lock category, path | "An idle zsh sitting in the volume, and an app holding a file open." |
| 1:10 to 1:28 (new scene `s04b-heritage`, 17 s; shorten others to stay under 180 s) | Heritage | The Cannot Put Away window with the style callout | "The look carries over from my 2025 entry, West of House, a spooky retelling of the classic text game Zork. The art was made fresh for this project." |
| 1:10 to 1:25 | Safety | Plan preview with skipped locks and reasons; a protected or other-user process shown read-only | "Nothing runs until you choose it, and protected processes are never touched." |
| 1:25 to 1:45 | Stage 1 | Egress Shells: the Terminal prompt returns to home, session alive | "The shell moves out without being killed." |
| 1:45 to 2:10 | Stage 2 | Graceful Request: app quits politely; table rescans | "Ask politely first. It rescans after every stage." |
| 2:10 to 2:25 | Stage 3 (only if needed) | Banish Locks confirmation listing name and pid | "A last resort, with an explicit confirmation." |
| 2:25 to 2:45 | Clean handoff | Clean Handoff: ghost turns "VOLUME RELEASED", volume disappears from Finder | "Zero locks, then a normal unmount." |
| 2:45 to 2:55 | Close | Title card: PhantomTrace, Resurrection category, built with Kiro | "Resurrecting What's Keeping Me? for modern macOS." |

Keep 10 seconds of slack. If a beat runs long, cut the old-way beat first.

## Permissions for recording and screenshots

Screen clips, hands-free recording (`Scripts/demo/record-flow.sh`) and automated screenshots need macOS Accessibility, Screen Recording and Automation for the app that runs them (Kiro, Kiro Crew, or your terminal). Turn them on only while recording, then off again:

- Check: `Scripts/demo/privileges.sh status`
- Turn on: `Scripts/demo/privileges.sh grant`, then switch each on by hand and restart the app (macOS does not allow a script to do this)
- Turn off: `Scripts/demo/privileges.sh revoke --yes`

Full steps, the by-hand version, and what each permission allows: [demo/CLIPS.md](../demo/CLIPS.md#turn-the-recording-permissions-off-and-on).

## Making the video (Remotion kit)

The video is built from the `demo/` project, one scene per beat of the timeline above: [demo/README.md](../demo/README.md). The narration text lives in `demo/scenes.json`, and [demo/NARRATION.md](../demo/NARRATION.md) is the guide for editing it and recording your own voice.

1. Set up the throwaway drive: `Scripts/demo/setup-demo.sh` (add `--headless` for no Terminal window). Reset after a take with `Scripts/demo/teardown-demo.sh`.
2. Record each short clip (full guide: [demo/CLIPS.md](../demo/CLIPS.md)): `Scripts/demo/record-clip.sh <scene-id> 12`. Required clips: `s03-trigger`, `s06-egress`, `s09-handoff`. The others use screenshots or a terminal replay until you record them.
3. Record your voice per scene into `demo/public/audio/<scene-id>.wav`.
4. `cd demo && npm install && npm run studio`, then `npm run render`.

Status (2026-11-13): five clips are recorded (`s01-problem`, `s03-trigger`, `s06-egress`, `s07-graceful`, `s09-handoff`), the narration text is matched to them, and a 103 s draft renders with machine-voice placeholders. Your own voice-over is not recorded yet.

## Mention Kiro (judging)

One quick cutaway (5 to 10 seconds, inside the budget) showing `.kiro/specs`, `.kiro/steering`, `.kiro/hooks`, and a passing property-test run, with a line on how specs and hooks shaped the build. Evidence belongs in [KiroUsage.md](KiroUsage.md).

## Fallbacks and checks

- Rehearse twice; reset the image between takes (detach, recreate, re-haunt).
- If Terminal automation is denied, show the manual-instruction path for Stage 1 instead.
- Confirm the recording shows macOS 27.2.1 (build 26B131) and a visible clock or About screen if possible.
- Upload as public on YouTube, then paste the link into [SubmissionChecklist.md](SubmissionChecklist.md) and the submission form.
