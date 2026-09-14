import React from "react";
import { ThreeCanvas } from "@remotion/three";
import {
  AbsoluteFill,
  Easing,
  Interactive,
  interpolate,
  interpolateColors,
  useCurrentFrame,
  useVideoConfig,
} from "remotion";
import { FinalOverlay } from "./FinalOverlay";
import { JourneyWorld } from "./JourneyWorld";

export type DoraZoom3DJourneyProps = {
  title: string;
  subtitle: string;
};

export const DoraZoom3DJourney: React.FC<DoraZoom3DJourneyProps> = ({
  title,
  subtitle,
}) => {
  const frame = useCurrentFrame();
  const { width, height } = useVideoConfig();

  return (
    <AbsoluteFill
      style={{
        background: `linear-gradient(180deg, ${interpolateColors(
          frame,
          [0, 520, 680, 860, 1180, 1499],
          ["#dceebd", "#e9c481", "#354a74", "#101b42", "#6fc3c6", "#e7f0ec"],
        )} 0%, #7fae93 100%)`,
        fontFamily:
          '"Avenir Next", "SF Pro Display", "PingFang SC", ui-sans-serif, system-ui, sans-serif',
        overflow: "hidden",
      }}
    >
      <ThreeCanvas
        width={width}
        height={height}
        camera={{ position: [0, 4.2, 8.4], fov: 43, near: 0.1, far: 100 }}
        style={{ backgroundColor: "transparent" }}
      >
        <JourneyWorld />
      </ThreeCanvas>
      <div
        style={{
          position: "absolute",
          inset: 0,
          pointerEvents: "none",
          background:
            "radial-gradient(circle at 50% 42%, transparent 24%, rgba(7,28,37,0.18) 100%), linear-gradient(180deg, rgba(255,255,255,0.04), rgba(9,32,39,0.12))",
        }}
      />
      <Interactive.Div
        name="Opening thought"
        style={{
          position: "absolute",
          left: 96,
          bottom: 84,
          maxWidth: 760,
          color: "rgba(248,252,244,0.88)",
          fontSize: 54,
          fontWeight: 600,
          lineHeight: 1.25,
          letterSpacing: "-0.035em",
          textShadow: "0 4px 28px rgba(6,29,37,0.28)",
          opacity: interpolate(frame, [20, 58, 220, 270], [0, 1, 1, 0], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
            easing: Easing.bezier(0.16, 1, 0.3, 1),
          }),
          translate: interpolate(frame, [20, 64], ["0px 28px", "0px 0px"], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
            easing: Easing.bezier(0.16, 1, 0.3, 1),
          }),
        }}
      >
        目的地不变。注意力会让隐藏的结构显现。
      </Interactive.Div>
      <FinalOverlay title={title} subtitle={subtitle} />
    </AbsoluteFill>
  );
};
