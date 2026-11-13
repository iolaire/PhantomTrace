import {execFileSync} from 'node:child_process';
import {existsSync, readFileSync} from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';

export const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
export const config = JSON.parse(readFileSync(path.join(root, 'scenes.json'), 'utf8'));

export const AUDIO_EXTENSIONS = ['wav', 'mp3', 'm4a', 'aac'];

/** Your own recording wins over the machine-voice placeholder. Returns a path under public/, or null. */
export function findAudio(id) {
  for (const ext of AUDIO_EXTENSIONS) {
    const own = `audio/${id}.${ext}`;
    if (existsSync(path.join(root, 'public', own))) return {src: own, own: true};
  }
  const placeholder = `audio/placeholder/${id}.mp3`;
  if (existsSync(path.join(root, 'public', placeholder))) return {src: placeholder, own: false};
  return null;
}

export function findClip(id) {
  const clip = `clips/${id}.mp4`;
  return existsSync(path.join(root, 'public', clip)) ? clip : null;
}

/** Media length in seconds, from ffprobe. */
export function probeSeconds(file) {
  const out = execFileSync(
    'ffprobe',
    ['-v', 'error', '-show_entries', 'format=duration', '-of', 'default=nw=1:nk=1', file],
    {encoding: 'utf8'},
  );
  const seconds = Number.parseFloat(out.trim());
  return Number.isFinite(seconds) ? seconds : 0;
}

export function wordCount(text) {
  return text.trim().split(/\s+/).filter(Boolean).length;
}
