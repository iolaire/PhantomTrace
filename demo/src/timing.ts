import config from '../scenes.json';
import manifest from './generated/manifest.json';
import type {SceneDef, SceneMedia} from './types';

export const FPS = config.fps;
export const WIDTH = config.width;
export const HEIGHT = config.height;
/** Seconds of air after the voice ends. Keep in step with scripts/sync.mjs. */
const VOICE_PAD_SEC = 0.6;
const MIN_SCENE_SEC = 3;

export const scenes = config.scenes as SceneDef[];
export const mediaFor = (id: string): SceneMedia => (manifest as Record<string, SceneMedia>)[id];

/** A scene lasts as long as its voice (or its target when there is no voice yet), and never less than its clip. */
export const sceneSeconds = (scene: SceneDef): number => {
  const media = mediaFor(scene.id);
  const trim = scene.trimStartSec ?? 0;
  const voice = media?.audio ? media.audioSec + VOICE_PAD_SEC : scene.targetSec;
  const clip = media?.clip ? Math.max(0, media.clipSec - trim) : 0;
  return Math.max(voice, clip, scene.minSec ?? MIN_SCENE_SEC);
};

export const sceneFrames = (scene: SceneDef): number => Math.ceil(sceneSeconds(scene) * FPS);

export const totalFrames = (): number => scenes.reduce((sum, scene) => sum + sceneFrames(scene), 0);
