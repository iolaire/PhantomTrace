import {interpolate, spring, useCurrentFrame, useVideoConfig} from 'remotion';
import {theme} from '../theme';

export const TitleCard = ({headline, sub, foot}: {headline: string; sub: string; foot: string}) => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const rise = spring({frame, fps, config: {damping: 200}, durationInFrames: 30});
  return (
    <div
      style={{
        position: 'absolute',
        inset: 0,
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        justifyContent: 'center',
        gap: 28,
        fontFamily: theme.font,
        color: theme.text,
        opacity: interpolate(rise, [0, 1], [0, 1]),
        transform: `translateY(${interpolate(rise, [0, 1], [30, 0])}px)`,
        textAlign: 'center',
      }}
    >
      <div style={{fontSize: 120, fontWeight: 800, letterSpacing: -2}}>{headline}</div>
      <div style={{fontSize: 44, color: theme.accent, maxWidth: 1300}}>{sub}</div>
      <div style={{fontSize: 30, color: theme.muted, marginTop: 40}}>{foot}</div>
    </div>
  );
};
