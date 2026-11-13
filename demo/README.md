# PhantomTrace demo video (Remotion)

The demo video for the Kiroween 2026 submission, built with [Remotion](https://www.remotion.dev) (React that renders to video). This folder is separate from the Swift package: the app has no Node dependency, and nothing here ships in the app.

Everything is driven by one file, `scenes.json`. One scene = one short narration file + one short screen clip (or a screenshot, a terminal replay, or a title card). Change a scene without touching the others.

## Quick start

```bash
cd demo
npm install
npm run vo:placeholder   # machine-voice stand-ins so you can check timing (macOS `say`)
npm run studio           # live preview in the browser
```

Other commands:

| Command | What it does |
|---|---|
| `npm run sync` | Scans `public/` for your clips and voice files, measures them, writes `src/generated/manifest.json`. The studio and render scripts run it for you. |
| `npm run guide` | Rewrites `NARRATION.md` from `scenes.json`. |
| `npm run render` | Renders the whole video to `out/phantomtrace-demo.mp4`. |
| `npm run render:scene -- s04-reveal out/s04.mp4` | Renders one scene. |
| `npm run typecheck` | Type-checks the project. |

## Your voice, your clips

How to collect the clips (what to show, setup, reset, handing them back): [CLIPS.md](CLIPS.md).

- Voice: save `public/audio/<scene-id>.wav` (or `.mp3`, `.m4a`, `.aac`). It replaces the placeholder for that scene. Delete it to go back. Full steps and the text for each scene: [NARRATION.md](NARRATION.md).
- Clips: `Scripts/demo/record-clip.sh <scene-id> 12` records 12 seconds of the screen and saves `public/clips/<scene-id>.mp4`. Re-record one scene at any time. Scenes with no clip show a slate that says what to record.
- Length: a scene lasts as long as its voice plus 0.6 s, or its clip if longer. `npm run sync` prints each scene and the total, and warns above 175 s (the contest limit is 180 s).
- Trim a clip's start with `trimStartSec` on that scene. Turn captions and callouts off with the `showCaptions` and `showCallouts` props in the studio sidebar.

## Layout

```
demo/
  scenes.json        # the script: ids, narration text, visuals, labels, recording notes
  NARRATION.md       # generated guide to the narration (edit scenes.json, not this)
  public/clips/      # your screen recordings, <scene-id>.mp4
  public/audio/      # your voice, <scene-id>.wav; placeholder/ holds the machine voice (git-ignored)
  src/               # Remotion code: Root (compositions), Demo (all scenes), scenes/, components/
  scripts/           # sync, placeholder voice, guide
```

Screenshots come from `../docs/screenshots` (copied to `public/stills/` by `npm run sync`).

## Notes

- Fonts: system fonts only, so there is no font license to track.
- The machine voice is only for timing. Record your own before you submit.
- Remotion is free for individuals and small teams; check the [Remotion license](https://www.remotion.dev/license) if that does not describe you.
- Third-party packages (dev tooling only, pinned in `package.json`): remotion, @remotion/cli, @remotion/media, react, react-dom, typescript, @types/react.
