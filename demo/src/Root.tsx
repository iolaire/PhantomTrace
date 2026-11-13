import {Composition, Folder} from 'remotion';
import {Demo} from './Demo';
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
