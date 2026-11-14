export type TerminalLine = {t: 'cmd' | 'out' | 'gap'; text?: string};

export type Callout = {text: string; atSec: number};

export type SceneDef = {
  id: string;
  title: string;
  visual: 'still' | 'clip' | 'terminal' | 'title' | 'intro';
  still?: string;
  terminal?: {title: string; lines: TerminalLine[]};
  titleCard?: {headline: string; sub: string; foot: string};
  narration: string;
  targetSec: number;
  /** The scene lasts at least this long, even if the voice is shorter. */
  minSec?: number;
  callouts: Callout[];
  /** What shows when the clip ends before the voice does: its last frame (default) or the scene's still. */
  afterClip?: 'hold' | 'still';
  /** Seconds to cut from the start of the clip. */
  trimStartSec?: number;
  record: string;
};

export type SceneMedia = {
  audio: string | null;
  audioOwn: boolean;
  audioSec: number;
  clip: string | null;
  clipSec: number;
  still: string | null;
};

export type DemoProps = {
  showCaptions: boolean;
  showCallouts: boolean;
};
