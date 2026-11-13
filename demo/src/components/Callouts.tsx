import {interpolate, spring, useCurrentFrame, useVideoConfig} from 'remotion';
import {theme} from '../theme';
import type {Callout} from '../types';

/** Small labels that pop in at the second given in scenes.json. */
export const Callouts = ({callouts}: {callouts: Callout[]}) => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  return (
    <div style={{position: 'absolute', left: 60, top: 56, display: 'flex', flexDirection: 'column', gap: 12}}>
      {callouts.map((callout) => {
        const start = Math.round(callout.atSec * fps);
        if (frame < start) return null;
        const pop = spring({frame: frame - start, fps, config: {damping: 200}, durationInFrames: 14});
        return (
          <div
            key={callout.text}
            style={{
              alignSelf: 'flex-start',
              opacity: interpolate(pop, [0, 1], [0, 1]),
              transform: `translateY(${interpolate(pop, [0, 1], [-14, 0])}px)`,
              fontFamily: theme.font,
              fontSize: 32,
              fontWeight: 600,
              color: '#0d0d12',
              background: theme.accent,
              borderRadius: 999,
              padding: '10px 24px',
            }}
          >
            {callout.text}
          </div>
        );
      })}
    </div>
  );
};
