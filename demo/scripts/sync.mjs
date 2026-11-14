// Scans public/ for your clips and voice-over, measures them, and writes src/generated/manifest.json.
// Run it after adding or replacing a file (the studio and render scripts run it for you).
import {copyFileSync, existsSync, mkdirSync, writeFileSync} from 'node:fs';
import path from 'node:path';
import {config, findAudio, findClip, probeSeconds, root, wordCount} from './lib.mjs';

const stillsSource = path.resolve(root, '..', 'docs', 'screenshots');
const stillsTarget = path.join(root, 'public', 'stills');
mkdirSync(stillsTarget, {recursive: true});
mkdirSync(path.join(root, 'src', 'generated'), {recursive: true});

// Art for the opening image, from the project's own look-and-feel files (transparent PNGs).
const artSource = path.resolve(root, '..', 'docs', 'LookAndFeel', 'use');
const artTarget = path.join(root, 'public', 'art');
mkdirSync(artTarget, {recursive: true});
for (const file of ['ghost-looking-left-yellow.png']) {
  const from = path.join(artSource, file);
  if (existsSync(from)) copyFileSync(from, path.join(artTarget, file));
  else console.warn(`warning: opening art ${file} not found in docs/LookAndFeel/use`);
}

const manifest = {};
let total = 0;
const pad = 0.6; // seconds of air after the voice

for (const scene of config.scenes) {
  const entry = {audio: null, audioOwn: false, audioSec: 0, clip: null, clipSec: 0, still: null};

  if (scene.still) {
    const from = path.join(stillsSource, scene.still);
    if (existsSync(from)) {
      copyFileSync(from, path.join(stillsTarget, scene.still));
      entry.still = `stills/${scene.still}`;
    } else {
      console.warn(`warning: ${scene.id}: still docs/screenshots/${scene.still} not found`);
    }
  }
  const audio = findAudio(scene.id);
  if (audio) {
    entry.audio = audio.src;
    entry.audioOwn = audio.own;
    entry.audioSec = probeSeconds(path.join(root, 'public', audio.src));
  }
  const clip = findClip(scene.id);
  if (clip) {
    entry.clip = clip;
    entry.clipSec = probeSeconds(path.join(root, 'public', clip));
  }
  manifest[scene.id] = entry;

  const sec = Math.max(entry.audio ? entry.audioSec + pad : scene.targetSec, entry.clipSec, scene.minSec ?? 3);
  total += sec;
  const words = wordCount(scene.narration);
  const note = [
    entry.clip ? `clip ${entry.clipSec.toFixed(1)}s` : scene.visual === 'clip' ? 'NO CLIP (slate)' : 'no clip',
    entry.audio ? `${entry.audioOwn ? 'your voice' : 'placeholder voice'} ${entry.audioSec.toFixed(1)}s` : 'no audio',
    `${words} words`,
  ].join(', ');
  console.log(`${scene.id.padEnd(14)} ${sec.toFixed(1).padStart(5)}s  ${note}`);
}

writeFileSync(path.join(root, 'src', 'generated', 'manifest.json'), `${JSON.stringify(manifest, null, 2)}\n`);
console.log(`Total ${total.toFixed(1)}s (limit ${config.maxTotalSeconds}s; the contest limit is 180s)`);
if (total > config.maxTotalSeconds) {
  console.warn(`warning: the video is over ${config.maxTotalSeconds}s. Shorten narration or trim clips.`);
}
