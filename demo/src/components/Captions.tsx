import {interpolate, useCurrentFrame, useVideoConfig} from 'remotion';
import {theme} from '../theme';

/** The narration text as a subtitle bar. Edit the words in scenes.json. */
export const Captions = ({text}: {text: string}) => {
  const frame = useCurrentFrame();
  const {durationInFrames} = useVideoConfig();
  const opacity = interpolate(frame, [0, 10, durationInFrames - 10, durationInFrames], [0, 1, 1, 0], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  return (
    <div
      style={{
        position: 'absolute',
        left: 160,
        right: 160,
        bottom: 56,
        opacity,
        textAlign: 'center',
        fontFamily: theme.font,
        fontSize: 38,
        lineHeight: 1.3,
        color: theme.text,
        background: 'rgba(0,0,0,0.62)',
        borderRadius: 14,
        padding: '14px 28px',
      }}
    >
      {text}
    </div>
  );
};
