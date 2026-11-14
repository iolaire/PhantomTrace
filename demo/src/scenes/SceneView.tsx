import {AbsoluteFill, Img, Sequence, interpolate, staticFile, useCurrentFrame, useVideoConfig} from 'remotion';
import {Audio, Video} from '@remotion/media';
import {Callouts} from '../components/Callouts';
import {Captions} from '../components/Captions';
import {Slate} from '../components/Slate';
import {TerminalView} from '../components/TerminalView';
import {TitleCard} from '../components/TitleCard';
import {theme} from '../theme';
import {mediaFor} from '../timing';
import type {DemoProps, SceneDef} from '../types';

type Props = DemoProps & {scene: SceneDef};

/** A still (a screenshot) framed on the canvas, with a slow push-in so it is not frozen. */
const StillLayer = ({src}: {src: string}) => {
  const frame = useCurrentFrame();
  const {durationInFrames} = useVideoConfig();
  const scale = interpolate(frame, [0, durationInFrames], [1, 1.04]);
  return (
    <AbsoluteFill style={{alignItems: 'center', justifyContent: 'center', paddingBottom: 150}}>
      <Img
        src={staticFile(src)}
        style={{
          maxWidth: '78%',
          maxHeight: '72%',
          transform: `scale(${scale})`,
        }}
      />
    </AbsoluteFill>
  );
};

/** One scene = visuals + one narration file + optional captions and callouts. */
export const SceneView = ({scene, showCaptions, showCallouts}: Props) => {
  const {fps} = useVideoConfig();
  const media = mediaFor(scene.id);
  const trimFrames = Math.round((scene.trimStartSec ?? 0) * fps);

  let visual;
  if (scene.visual === 'terminal' && scene.terminal) {
    visual = <TerminalView title={scene.terminal.title} lines={scene.terminal.lines} />;
  } else if (scene.visual === 'title' && scene.titleCard) {
    visual = <TitleCard {...scene.titleCard} />;
  } else if (media?.clip) {
    // When the clip ends before the voice does, the last frame stays on screen, or (afterClip "still")
    // the scene's screenshot takes over.
    const clipFrames = Math.max(1, Math.round(media.clipSec * fps) - trimFrames);
    const clip = (
      <AbsoluteFill style={{paddingBottom: 150}}>
        <Video
          src={staticFile(media.clip)}
          trimBefore={trimFrames}
          muted
          style={{width: '100%', height: '100%', objectFit: 'contain'}}
        />
      </AbsoluteFill>
    );
    visual =
      scene.afterClip === 'still' && media.still ? (
        <>
          <Sequence durationInFrames={clipFrames}>{clip}</Sequence>
          <Sequence from={clipFrames}>
            <StillLayer src={media.still} />
          </Sequence>
        </>
      ) : (
        clip
      );
  } else if (media?.still) {
    visual = <StillLayer src={media.still} />;
  } else {
    visual = <Slate id={scene.id} record={scene.record} />;
  }

  return (
    <AbsoluteFill style={{background: theme.background}}>
      {visual}
      {showCallouts && scene.callouts.length > 0 ? <Callouts callouts={scene.callouts} /> : null}
      {showCaptions ? <Captions text={scene.narration} /> : null}
      {media?.audio ? <Audio src={staticFile(media.audio)} /> : null}
    </AbsoluteFill>
  );
};
