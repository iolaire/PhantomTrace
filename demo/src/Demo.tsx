import {Series} from 'remotion';
import {SceneView} from './scenes/SceneView';
import {sceneFrames, scenes} from './timing';
import type {DemoProps} from './types';

export const Demo = ({showCaptions, showCallouts}: DemoProps) => (
  <Series>
    {scenes.map((scene) => (
      <Series.Sequence key={scene.id} durationInFrames={sceneFrames(scene)}>
        <SceneView scene={scene} showCaptions={showCaptions} showCallouts={showCallouts} />
      </Series.Sequence>
    ))}
  </Series>
);
