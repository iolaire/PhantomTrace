# Look and Feel

Visual reference material for the Platinum Retro Gothic UI. These are design references, not shipped app assets yet. The AppKit UI is built later (see `.kiro/steering/platinum-ui.md`).

## Style summary

- A grey System 7 / Mac OS 9 style window with a pixel-font title plaque, pinstripe title bar, and square close box.
- A black-and-white engraved frame of twisted ribbon, chains, and skulls, with a halftone dot texture.
- The Kiro ghost mascot in colour, glowing purple, carrying a lantern (and a magnifying glass when inspecting), perched over the window edge.
- A small engraved illustration in the lower right of the content area that matches the state.

## Composed mockups (`original/composed/`)

| File | Window title | Meaning |
|---|---|---|
| [composed-phantom trace.jpg](original/composed/composed-phantom%20trace.jpg) | PHANTOM TRACE | Main or scanning window: ghost with magnifying glass and lantern, a CRT showing a dungeon scene |
| [composed-cannot put away.jpg](original/composed/composed-cannot%20put%20away.jpg) | CANNOT PUT AWAY | Blocked state: chained, padlocked drive and floppy, ghost beside them (the "haunting" sprite). The title nods to the classic Mac "Put Away" error |
| [composed-volume released.jpg](original/composed/composed-volume%20released.jpg) | VOLUME RELEASED | Clean or unmounted state (the "banished" sprite): smiling ghost, broken chains and open padlock, open portcullis, drive and floppy freed |

The content area of each mockup is intentionally empty: the lock table, stage buttons, and banners are drawn by the app.

## Base images (`original/base-images/`)

Building blocks used to compose the mockups: the window frame, the CRT diagnostic portal, a shackled volume with padlocks, shattered chains and portcullis, and the ghost in several poses and colours (left green, left red, left yellow, right yellow).

## Notes for implementation

- Spec colour for the window background is platinum grey `#DDDDDD`; the mockups are a mood reference, not a pixel spec.
- The mockups are large JPEGs (about 2 MB each, 2752x1536). The app needs smaller, cropped sprites with transparent backgrounds; export those into the app asset catalog when the UI work starts, and keep these originals as the source.
- Ghost states map to the discovery state machine: idle and scanning, haunting (Blocked), banished (clean and unmounted). Reduce Motion means a static sprite with no glow animation.
- File names contain spaces and one has a double extension (`base-crt diagnostic portal.png.jpg`). Rename them to kebab-case when they move into the app assets.

## Provenance and licensing (to confirm)

How these images were produced and under what terms is not recorded in the repository. Before submission, record their source and license here and in `docs/ProjectLog.md`, because the Rules require all assets to be used within their licenses and forbid unauthorized third-party material. The Kiro ghost mascot is a Kiro brand character; confirm its use is permitted by the hackathon rules.
