import React from "react";
import { AbsoluteFill, Sequence } from "remotion";
import { AIBuild } from "./AIBuild";
import { Close, Open } from "./OpenClose";
import { Record } from "./Record";
import { Sound } from "./Sound";
import { Teach } from "./Teach";
import { DURATION, FPS, HEIGHT, SHOTS, WIDTH } from "./timeline";

export { DURATION, FPS, HEIGHT, WIDTH };

export const DoraZoomPromo: React.FC<{ bgm: boolean }> = ({ bgm }) => {
  return (
    <AbsoluteFill style={{ backgroundColor: "#0b0c0e" }}>
      <Sequence from={SHOTS.open.from} durationInFrames={SHOTS.open.dur}>
        <Open />
      </Sequence>
      <Sequence from={SHOTS.teach.from} durationInFrames={SHOTS.teach.dur}>
        <Teach duration={SHOTS.teach.dur} />
      </Sequence>
      <Sequence from={SHOTS.ai.from} durationInFrames={SHOTS.ai.dur}>
        <AIBuild duration={SHOTS.ai.dur} />
      </Sequence>
      <Sequence from={SHOTS.record.from} durationInFrames={SHOTS.record.dur}>
        <Record duration={SHOTS.record.dur} />
      </Sequence>
      <Sequence from={SHOTS.close.from} durationInFrames={SHOTS.close.dur}>
        <Close />
      </Sequence>
      <Sound bgm={bgm} />
    </AbsoluteFill>
  );
};
