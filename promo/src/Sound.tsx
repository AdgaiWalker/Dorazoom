import React from "react";
import { Audio, Sequence, staticFile } from "remotion";
import { SHOTS } from "./timeline";

const s = (name: string) => staticFile(`sfx/${name}`);

export const Sound: React.FC<{ bgm: boolean }> = ({ bgm }) => {
  return (
    <>
      {bgm ? (
        <Audio src={s("bgm-tech-house.mp3")} volume={0.28} />
      ) : null}
      <Sequence from={SHOTS.open.from} name="open-soft">
        <Audio src={s("transition-soft.mp3")} volume={0.35} />
      </Sequence>
      <Sequence from={SHOTS.teach.from + 30} name="crash-zoom">
        <Audio src={s("impact-zoom-quick.mp3")} volume={0.55} />
      </Sequence>
      <Sequence from={SHOTS.teach.from + 48} name="pen">
        <Audio src={s("sweep-short.mp3")} volume={0.4} />
      </Sequence>
      <Sequence from={SHOTS.teach.from + 110} name="align">
        <Audio src={s("transition-snap.mp3")} volume={0.45} />
      </Sequence>
      <Sequence from={SHOTS.ai.from + 6} name="select">
        <Audio src={s("sweep-fast-small.mp3")} volume={0.38} />
      </Sequence>
      <Sequence from={SHOTS.ai.from + 38} name="shutter">
        <Audio src={s("camera-shutter-hard.mp3")} volume={0.55} />
      </Sequence>
      <Sequence from={SHOTS.ai.from + 62} name="shot-fly">
        <Audio src={s("air-woosh-quick.mp3")} volume={0.5} />
      </Sequence>
      <Sequence from={SHOTS.ai.from + 100} name="paste">
        <Audio src={s("transition-snap.mp3")} volume={0.48} />
      </Sequence>
      <Sequence from={SHOTS.ai.from + 148} name="slam">
        <Audio src={s("impact-cine-big.mp3")} volume={0.62} />
      </Sequence>
      <Sequence from={SHOTS.record.from + 42} name="export">
        <Audio src={s("camera-shutter-hard.mp3")} volume={0.45} />
      </Sequence>
      <Sequence from={SHOTS.close.from} durationInFrames={40} name="riser">
        <Audio src={s("riser-cine.mp3")} volume={0.4} />
      </Sequence>
      <Sequence from={SHOTS.close.from + 20} name="mark">
        <Audio src={s("impact-cine-big.mp3")} volume={0.5} />
      </Sequence>
      <Sequence from={SHOTS.close.from + 28} name="sparkle">
        <Audio src={s("sparkle.mp3")} volume={0.35} />
      </Sequence>
    </>
  );
};
