// Makes machine-voice stand-ins with the macOS `say` command, so the timing can be checked before you record.
// They go in public/audio/placeholder/ (git-ignored). Your own files in public/audio/<scene-id>.wav|mp3|m4a win.
//   npm run vo:placeholder              only scenes that have no placeholder yet
//   npm run vo:placeholder -- --all     redo every scene (after editing narration text)
import {execFileSync} from 'node:child_process';
import {mkdirSync, mkdtempSync, rmSync, existsSync} from 'node:fs';
import {tmpdir} from 'node:os';
import path from 'node:path';
import {config, root} from './lib.mjs';

const all = process.argv.includes('--all');
const voice = process.env.PHANTOMTRACE_VO_VOICE || 'Samantha';
const rate = process.env.PHANTOMTRACE_VO_RATE || '165'; // words per minute
const outDir = path.join(root, 'public', 'audio', 'placeholder');
mkdirSync(outDir, {recursive: true});
const work = mkdtempSync(path.join(tmpdir(), 'pt-vo-'));

try {
  for (const scene of config.scenes) {
    const target = path.join(outDir, `${scene.id}.mp3`);
    if (!all && existsSync(target)) continue;
    const aiff = path.join(work, `${scene.id}.aiff`);
    // The text is passed as an argument array, never through a shell.
    execFileSync('say', ['-v', voice, '-r', rate, '-o', aiff, '--', scene.narration]);
    execFileSync('ffmpeg', ['-y', '-loglevel', 'error', '-i', aiff, '-ar', '44100', '-b:a', '128k', target]);
    console.log(`made ${path.relative(root, target)}`);
  }
} finally {
  rmSync(work, {recursive: true, force: true});
}
console.log('Next: npm run sync');
