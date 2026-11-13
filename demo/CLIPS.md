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
| Optional | `s01-problem` | Select the drive in Finder, press Cmd+E. Let Finder's refusal dialog sit for 3 s. | 6 to 8 s |
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

## Reset between takes

Egress and Eject change the drive, so reset before each of those takes:

```bash
Scripts/demo/teardown-demo.sh && Scripts/demo/setup-demo.sh
```

Then `cd /Volumes/PhantomDemo` in Terminal again. Teardown stops only the helpers the setup started and ejects only `PhantomDemo`. If it says the volume is busy, close the demo Terminal window and run it again. Undo for everything: `Scripts/demo/teardown-demo.sh`.

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
