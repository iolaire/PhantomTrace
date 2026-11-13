import {theme} from '../theme';

/** Shown when a scene needs a clip you have not recorded yet. It tells you what to record. */
export const Slate = ({id, record}: {id: string; record: string}) => (
  <div
    style={{
      position: 'absolute',
      inset: 0,
      display: 'flex',
      flexDirection: 'column',
      alignItems: 'center',
      justifyContent: 'center',
      gap: 24,
      padding: 160,
      textAlign: 'center',
      fontFamily: theme.font,
      color: theme.text,
    }}
  >
    <div style={{fontSize: 30, color: theme.warn, letterSpacing: 4}}>NO CLIP YET</div>
    <div style={{fontSize: 60, fontWeight: 700}}>{id}</div>
    <div style={{fontSize: 34, color: theme.muted, maxWidth: 1200}}>{record}</div>
    <div style={{fontSize: 28, fontFamily: theme.mono, color: theme.accent}}>
      Scripts/demo/record-clip.sh {id} 12
    </div>
  </div>
);
