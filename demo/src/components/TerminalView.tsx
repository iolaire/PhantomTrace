import {interpolate, useCurrentFrame, useVideoConfig} from 'remotion';
import {theme} from '../theme';
import type {TerminalLine} from '../types';

const CHARS_PER_SEC = 40;
const LINE_DELAY_SEC = 0.25;

/** A terminal that types each command and then prints its output. Text comes from scenes.json. */
export const TerminalView = ({title, lines}: {title: string; lines: TerminalLine[]}) => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const now = frame / fps;

  // Work out when each line starts: commands are typed, output lines appear one after another.
  let cursor = 0.6;
  const timed = lines.map((line) => {
    const start = cursor;
    if (line.t === 'cmd') cursor += (line.text?.length ?? 0) / CHARS_PER_SEC + 0.5;
    else cursor += LINE_DELAY_SEC;
    return {line, start};
  });

  return (
    <div
      style={{
        position: 'absolute',
        left: 160,
        right: 160,
        top: 120,
        bottom: 190,
        background: theme.panel,
        borderRadius: 16,
        boxShadow: '0 24px 70px rgba(0,0,0,0.6)',
        overflow: 'hidden',
        fontFamily: theme.mono,
      }}
    >
      <div style={{height: 52, background: '#25252f', display: 'flex', alignItems: 'center', padding: '0 20px', gap: 10}}>
        {['#ff5f57', '#febc2e', '#28c840'].map((color) => (
          <div key={color} style={{width: 16, height: 16, borderRadius: 8, background: color}} />
        ))}
        <div style={{flex: 1, textAlign: 'center', color: theme.muted, fontSize: 22, fontFamily: theme.font}}>{title}</div>
      </div>
      <div style={{padding: '28px 36px', fontSize: 28, lineHeight: 1.5, color: theme.text, whiteSpace: 'pre-wrap'}}>
        {timed.map(({line, start}, index) => {
          if (now < start) return null;
          if (line.t === 'gap') return <div key={index} style={{height: 20}} />;
          const text = line.text ?? '';
          if (line.t === 'out') {
            return (
              <div key={index} style={{color: theme.muted, wordBreak: 'break-all'}}>
                {text}
              </div>
            );
          }
          const shown = Math.floor(interpolate(now - start, [0, text.length / CHARS_PER_SEC], [0, text.length], {
            extrapolateLeft: 'clamp',
            extrapolateRight: 'clamp',
          }));
          return (
            <div key={index}>
              <span style={{color: theme.accent}}>$ </span>
              {text.slice(0, shown)}
            </div>
          );
        })}
      </div>
    </div>
  );
};
