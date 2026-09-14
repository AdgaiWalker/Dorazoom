import React from "react";
import { interpolate, interpolateColors, useCurrentFrame } from "remotion";
import { PaperPlane } from "./PaperPlane";
import { BEATS } from "./timeline";
import { fadeWindow } from "./utils";
import { DesertScene } from "./scenes/DesertScene";
import { GardenScene } from "./scenes/GardenScene";
import { MeadowScene } from "./scenes/MeadowScene";
import { OceanScene } from "./scenes/OceanScene";
import { StarScene } from "./scenes/StarScene";

export const JourneyWorld: React.FC = () => {
  const frame = useCurrentFrame();
  const meadowOpacity = fadeWindow(frame, BEATS.meadow.start, BEATS.meadow.end, 60);
  const desertOpacity = fadeWindow(frame, BEATS.desert.start, BEATS.desert.end, 60);
  const starsOpacity = fadeWindow(frame, BEATS.stars.start, BEATS.stars.end, 60);
  const oceanOpacity = fadeWindow(frame, BEATS.ocean.start, BEATS.ocean.end, 60);
  const gardenOpacity = interpolate(frame, [BEATS.garden.start, BEATS.garden.start + 90], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  const sky = interpolateColors(
    frame,
    [0, 300, 520, 660, 840, 1080, 1200, 1320, 1499],
    ["#cfe8ad", "#efcf91", "#e5ba72", "#273962", "#101b42", "#48a8b8", "#74c2c2", "#aed9c4", "#dcecf3"],
  );

  return (
    <>
      <fog attach="fog" args={[sky, 13, 30]} />
      <ambientLight intensity={1.25} color="#e9f4ff" />
      <directionalLight
        position={[-6 + Math.sin(frame * 0.003) * 2, 8, 6]}
        intensity={2.2}
        color={frame > 520 && frame < 940 ? "#a9d3ff" : "#fff1c9"}
      />
      <pointLight position={[2, 2, 3]} intensity={1.6} color="#d8f6ff" />
      <MeadowScene opacity={meadowOpacity} />
      <DesertScene opacity={desertOpacity} />
      <StarScene opacity={starsOpacity} />
      <OceanScene opacity={oceanOpacity} />
      <GardenScene opacity={gardenOpacity} />
      <PaperPlane />
    </>
  );
};
