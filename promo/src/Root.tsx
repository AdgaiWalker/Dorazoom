import React from "react";
import { Composition, Folder } from "remotion";
import { DoraZoomPromo, DURATION, FPS, HEIGHT, WIDTH } from "./DoraZoomPromo";
import { DoraZoom3DJourney } from "./journey3d/DoraZoom3DJourney";

export const Root: React.FC = () => {
  return (
    <>
      <Composition
        id="DoraZoomPromo"
        component={DoraZoomPromo}
        durationInFrames={DURATION}
        fps={FPS}
        width={WIDTH}
        height={HEIGHT}
        defaultProps={{ bgm: true }}
      />
      <Folder name="Website-3D-Journey">
        <Composition
          id="DoraZoom3DJourney"
          component={DoraZoom3DJourney}
          durationInFrames={1500}
          fps={30}
          width={1920}
          height={1080}
          defaultProps={{
            title: "注意力揭开世界",
            subtitle: "目的地不变，经历会改变梦想抵达世界的方式。",
          }}
        />
      </Folder>
    </>
  );
};
