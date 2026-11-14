# Clip Collection Guide

How to capture the short screen clips for the demo video. Each clip is one scene, recorded on its own, so you can redo one without touching the others.

Scene ids, narration, and what to show are in `scenes.json` and [NARRATION.md](NARRATION.md). Run `npm run sync` to see which clips are still missing.

## Who can record what

The demo runs on macOS (Finder, the Quick Action, the PhantomTrace app). The clips must show a real Mac screen. A Linux sandbox (Kiro Web) has no Finder and cannot run this app, so it can store and edit files but cannot capture these clips. Record on the Mac, then put the files in `demo/public/clips/`.

## Clip list

| Priority | Scene id | Show | Length |
|---|---|---|---|
| Required | `s03-trigger` | Right-click the drive in Finder, Quick Actions, Why Can't I Eject? Stop when the PhantomTrace window opens. | 10 to 12 s |
| Required | `s06-egress` | Terminal and PhantomTrace side by side. Choose Egress Shells, Proceed, confirm. The Terminal prompt goes to `~` and the lock list updates. | 12 to 15 s |
| Required | `s09-handoff` | Press Eject. The green VOLUME RELEASED window shows, and the drive leaves Finder. | 10 to 12 s |
| Optional | `s01-problem` | Open the drive's Finder window, right-click the drive in the sidebar, Eject. Let Finder's refusal dialog (it names no program and offers only Force Eject) sit for 3 s, then Cancel. | 10 to 12 s |
| Optional | `s04-reveal` | The lock list opens. Slowly point at each row. | 10 to 15 s |
| Optional | `s05-safety` | Choose a stage, press Proceed. Stop on the plan preview. | 8 to 12 s |
| Optional | `s07-graceful` | Graceful Request, Proceed, confirm. Let the rescan finish. | 10 to 15 s |
| Optional | `s08-banish` | Only if a lock is left after stage two. Show the confirmation. | 6 to 10 s |

Scenes with no clip use a screenshot or a terminal replay, so only the three required clips block the video.

## Before you record

1. Make sure no other session is running Swift builds or tests. Wait for them to finish.
2. Build the app if needed: `Scripts/make-app.sh`. Install the Quick Action: `Scripts/install-quick-action.sh`, then enable it in Finder (Quick Actions > Customize).
3. Set up the throwaway drive: `Scripts/demo/setup-demo.sh`.
4. In Terminal run `cd /Volumes/PhantomDemo` and leave it idle. (If macOS allows it, the setup script does this for you.)
5. Check both locks show: `.build/debug/phantomtrace /Volumes/PhantomDemo`. You should see a `tail` and a `zsh`.
6. Clear the Desktop. Turn on Do Not Disturb. Close unrelated windows. Keep other drives out of the Finder sidebar if you can; screenshots showed other drives' names last time.

## Record one clip

```bash
Scripts/demo/record-clip.sh <scene-id> <seconds>
# example
Scripts/demo/record-clip.sh s03-trigger 12
```

It counts down 3 seconds, records the screen with no sound, and saves `demo/public/clips/<scene-id>.mp4` (H.264, 30 fps, at most 1920 wide). The first time, macOS asks for Screen Recording permission for your terminal app. Allow it and run the command again.

Run the next take by repeating the same command. It replaces only that scene's file.

## Record hands-free (Kiro or a person)

`Scripts/demo/record-flow.sh` records the clips without anyone touching the keyboard or mouse. It drives Finder and PhantomTrace through the Accessibility API, using `Scripts/demo/ax-drive.swift` (built on first use into `~/PhantomTraceDemo/bin/`). Kiro recorded the current clips this way on 2026-11-13. It has two modes:

| Mode | Shows | Saves |
|---|---|---|
| `problem` | Finder window on the drive, right-click the drive in the sidebar, Eject, Finder's "wasn't ejected" alert for 3 s, then Cancel. No PhantomTrace. | `s01-problem` (about 12 s) |
| `resolve` | One take: right-click the drive's desktop icon, then Quick Actions > Why Can't I Eject?, Summon, Egress Shells, Graceful Request, Eject. The desktop icon disappears at the end. | Cut from the take at logged step times: `s03-trigger` (to the lock list), `s06-egress`, `s07-graceful`, `s09-handoff` (release and eject). The full take and the step times stay in `~/PhantomTraceDemo/takes/`. |

How it works:

- `resolve` layout, left to right: the drive's desktop icon, Terminal, PhantomTrace. The start window is moved flush right, so the lock window opens on top of it (the app keeps it on screen) and plan dialogs center on that. App placement code and requirements are unchanged. The icon's old desktop position is put back after a preview.
- The demo Terminal tab gets a `%~ %#` prompt and an 18 pt font, so the prompt visibly changes from `/Volumes/PhantomDemo %` to `~ %`.
- The real pointer glides to each control and clicks or right-clicks it. `screencapture -C -k` shows the cursor and a ring on each click (AXPress alone moves no pointer and draws no ring).
- Each step waits for its control, then pauses about 1 s. The script records a screen region and trims it to the measured length.
- Finder's desktop context menu is not in Finder's AX tree. `ax-drive` finds it by screen position (`AXAT=x,y`).
- It never presses Force Eject or Force Unmount.

Steps:

1. Grant **Accessibility** and **Screen Recording** to the app that runs the script (Kiro or your terminal), then restart that app.
2. `Scripts/make-app.sh`, `Scripts/install-quick-action.sh` (enable it in Finder), then `Scripts/demo/setup-demo.sh`. `resolve` needs a Terminal tab with its cwd on the drive plus the `tail` lock. A `--headless` shell is classed `cliTool`, so Egress Shells is disabled for it.
3. Clear the screen area being recorded. The clip is a region, so whatever is behind the windows shows.
4. Preview: `PHANTOMTRACE_FLOW_TOP=235 Scripts/demo/record-flow.sh problem --preview` (or `resolve --preview`). This saves one still to `~/PhantomTraceDemo/preview.png`. Look at it, then delete it. `PHANTOMTRACE_FLOW_TOP` sets the top edge in screen points. Leave it out to use a third of the way down.
5. Record `problem` first, because it leaves the drive mounted. Then, if the shell has moved, `cd /Volumes/PhantomDemo` in the demo Terminal tab again, and record `resolve`. Check frames before keeping the files.

Known limits:

- The first Egress Shells run on a new build can sit on "Conjuring..." for about 15 s with no message while macOS asks whether PhantomTrace may control Terminal. Allow it and run again. If the send fails, the window shows "Do it yourself (...): ... type: cd ~" under the lock table (Requirement 7.5, fixed after these clips were recorded; the recorded clips are unaffected because the send succeeded).
- The Finder sidebar and the PhantomTrace start window show every mounted volume and network location. Other drives' names show unless only the demo image is mounted (the owner accepted this for the 2026-11-13 takes).
- After `resolve` the volume is unmounted but the image is still attached. Reset as below.
- A glow around the cursor or clicks is not drawn. Add it in Remotion if wanted.

## Reset between takes

Egress and Eject change the drive, so reset before each of those takes:

```bash
Scripts/demo/teardown-demo.sh && Scripts/demo/setup-demo.sh
```

Then `cd /Volumes/PhantomDemo` in Terminal again. Teardown stops only the helpers the setup started and ejects only `PhantomDemo`. After PhantomTrace's Eject the volume is gone but the image is still attached; teardown then detaches the image's own disk. If it says the volume is busy, close the demo Terminal window and run it again. Undo for everything: `Scripts/demo/teardown-demo.sh`.

## Recording without the script (QuickTime or Shift+Cmd+5)

Any screen recorder works. Save the file, then convert it to the format the project expects:

```bash
ffmpeg -i my-recording.mov -an -c:v libx264 -pix_fmt yuv420p -crf 18 -r 30 \
  -vf "scale='min(1920,iw)':-2" -movflags +faststart demo/public/clips/s03-trigger.mp4
```

The file name must be exactly `<scene-id>.mp4`. Do not record system sound or your voice here; narration is a separate file per scene.

## Tips

- Start the action about 1 second after recording starts and hold the final state for 2 seconds. You can trim the start later with `trimStartSec` in `scenes.json`.
- Keep each clip short. A scene is as long as its voice-over or its clip, whichever is longer.
- Move the pointer slowly. Do not type passwords on screen.
- No third-party logos, music, or other people's windows in frame.
- Show only the throwaway `PhantomDemo` drive. Never use a real backup drive.

## Hand the clips back

1. Put the `.mp4` files in `demo/public/clips/`.
2. Run `cd demo && npm run sync`. It lists each scene and flags any clip still missing.
3. Preview with `npm run studio`.
4. Tell the assistant the clips are in, and it will check lengths, timing and captions, and render.

Clip files are large, so decide before you commit: this folder is not git-ignored, so small clips can be tracked. Keep the whole set under about 50 MB, or keep the raw clips out of git and commit only the rendered video link.
