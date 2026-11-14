import {AbsoluteFill, Img, interpolate, random, spring, staticFile, useCurrentFrame, useVideoConfig} from 'remotion';
import {theme} from '../theme';

type Props = {headline: string; sub: string; foot: string};

const EMBERS = 36;

/**
 * The opening image. Frame 0 is already the finished poster (title, tagline, ghost), so a paused video, a
 * preview, or a platform's auto-chosen frame is never blank. Motion only adds: a glitch settling on the
 * title, a ghost pop, floating embers and fog.
 */
export const Intro = ({headline, sub, foot}: Props) => {
  const frame = useCurrentFrame();
  const {fps, width, height, durationInFrames} = useVideoConfig();
  const t = frame / fps;

  const fadeOut = interpolate(frame, [durationInFrames - 10, durationInFrames], [1, 0], {extrapolateLeft: 'clamp'});

  // Ghost: already in place at frame 0; a small pop, then it floats.
  const ghostIn = spring({frame, fps, config: {damping: 10, stiffness: 120}});
  const bob = Math.sin(t * 1.6) * 16;
  const glow = 0.55 + Math.sin(t * 2.4) * 0.2;

  const letters = headline.split('');

  return (
    <AbsoluteFill style={{background: '#06060a', opacity: fadeOut, overflow: 'hidden'}}>
      {/* Violet haze behind the ghost */}
      <AbsoluteFill
        style={{
          background: `radial-gradient(ellipse 55% 70% at 74% 48%, rgba(120,80,220,${0.38 * glow}) 0%, rgba(30,20,60,0.0) 70%)`,
        }}
      />
      {/* Slow fog bands */}
      {[0, 1, 2].map((i) => (
        <div
          key={i}
          style={{
            position: 'absolute',
            left: -400 + ((t * (22 + i * 9) + i * 500) % (width + 800)),
            top: 200 + i * 260,
            width: 900,
            height: 220,
            borderRadius: 220,
            background: 'rgba(150,140,190,0.06)',
            filter: 'blur(60px)',
          }}
        />
      ))}
      {/* Rising embers */}
      {Array.from({length: EMBERS}, (_, i) => {
        const x = random(`x${i}`) * width;
        const speed = 30 + random(`s${i}`) * 70;
        const y = height + 40 - ((t * speed + random(`y${i}`) * height) % (height + 80));
        const size = 3 + random(`z${i}`) * 6;
        const flicker = 0.35 + 0.65 * Math.abs(Math.sin(t * (1 + random(`f${i}`) * 3) + i));
        return (
          <div
            key={i}
            style={{
              position: 'absolute',
              left: x + Math.sin(t + i) * 20,
              top: y,
              width: size,
              height: size,
              borderRadius: size,
              background: i % 3 === 0 ? '#ffd27a' : '#b9a6ff',
              opacity: flicker * 0.7,
              boxShadow: '0 0 12px currentColor',
            }}
          />
        );
      })}

      {/* The ghost */}
      <Img
        src={staticFile('art/ghost-looking-left-yellow.png')}
        style={{
          position: 'absolute',
          right: 70,
          top: 110,
          height: 800,
          transform: `translateY(${bob}px) scale(${interpolate(ghostIn, [0, 1], [0.94, 1])})`,
          filter: `drop-shadow(0 0 ${46 * glow}px rgba(160,120,255,0.85))`,
        }}
      />

      {/* Title block */}
      <div style={{position: 'absolute', left: 150, top: 300, fontFamily: theme.font, color: theme.text}}>
        <div style={{display: 'flex', fontSize: 146, fontWeight: 800, letterSpacing: -3, lineHeight: 1}}>
          {letters.map((char, i) => {
            // Every letter is visible from frame 0. A colored flicker settles across the word, left to right.
            const start = i * 1.6;
            const glitch = interpolate(frame, [start, start + 10, start + 22], [12, 5, 0], {
              extrapolateLeft: 'clamp',
              extrapolateRight: 'clamp',
            });
            return (
              <span
                key={i}
                style={{
                  display: 'inline-block',
                  textShadow: `${glitch}px 0 rgba(255,60,90,0.8), ${-glitch}px 0 rgba(90,200,255,0.8), 0 0 40px rgba(160,120,255,0.55)`,
                  whiteSpace: 'pre',
                }}
              >
                {char}
              </span>
            );
          })}
        </div>
        <div style={{marginTop: 34, fontSize: 56, color: theme.accent, fontFamily: theme.mono, minHeight: 72}}>
          {sub}
          <span style={{opacity: Math.floor(t * 2.4) % 2 === 0 ? 1 : 0}}>▌</span>
        </div>
        <div style={{marginTop: 70, fontSize: 30, color: theme.muted, letterSpacing: 1}}>{foot}</div>
      </div>

      {/* CRT scanlines and vignette over everything */}
      <AbsoluteFill
        style={{
          background:
            'repeating-linear-gradient(0deg, rgba(0,0,0,0.16) 0px, rgba(0,0,0,0.16) 1px, transparent 1px, transparent 4px)',
          mixBlendMode: 'multiply',
        }}
      />
      <AbsoluteFill style={{background: 'radial-gradient(ellipse at center, transparent 55%, rgba(0,0,0,0.75) 100%)'}} />
    </AbsoluteFill>
  );
};
