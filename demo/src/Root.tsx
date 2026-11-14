import {Composition, Folder, Sequence, Still} from 'remotion';
import {Demo} from './Demo';
import {Intro} from './components/Intro';
import {SceneView} from './scenes/SceneView';
import {FPS, HEIGHT, WIDTH, sceneFrames, scenes, totalFrames} from './timing';
import type {DemoProps} from './types';

const defaultProps: DemoProps = {showCaptions: true, showCallouts: true};

export const RemotionRoot = () => (
  <>
    {/* The whole video, every scene in order. */}
    <Composition
      id="Demo"
      component={Demo}
      durationInFrames={totalFrames()}
      fps={FPS}
      width={WIDTH}
      height={HEIGHT}
      defaultProps={defaultProps}
    />
    {/* The video thumbnail: the opening image after the glitch has settled. Render it with `npm run thumbnail`. */}
    <Still
      id="Thumbnail"
      component={() => (
        <Sequence from={-90}>
          <Intro {...(scenes[0].titleCard as {headline: string; sub: string; foot: string})} />
        </Sequence>
      )}
      width={WIDTH}
      height={HEIGHT}
    />
    {/* One composition per scene, so each can be previewed or rendered alone. */}
    <Folder name="Scenes">
      {scenes.map((scene) => (
        <Composition
          key={scene.id}
          id={scene.id}
          component={() => <SceneView scene={scene} {...defaultProps} />}
          durationInFrames={sceneFrames(scene)}
          fps={FPS}
          width={WIDTH}
          height={HEIGHT}
        />
      ))}
    </Folder>
  </>
);
