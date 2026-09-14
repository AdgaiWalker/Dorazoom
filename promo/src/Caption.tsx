import React from "react";
import { interpolate, useCurrentFrame } from "remotion";
import { SANS } from "./tokens";

export const Caption: React.FC<{
  text: string;
  duration: number;
}> = ({ text, duration }) => {
  const frame = useCurrentFrame();
  const inn = interpolate(frame, [0, 10], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  const out = interpolate(frame, [duration - 10, duration], [1, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  return (
    <div
      style={{
        position: "absolute",
        left: 0,
        right: 0,
        bottom: 64,
        textAlign: "center",
        fontFamily: SANS,
        fontSize: 56,
        fontWeight: 560,
        letterSpacing: "-0.03em",
        color: "white",
        opacity: inn * out,
        transform: `translateY(${(1 - inn) * 10}px)`,
        textShadow: "0 2px 24px rgba(0,0,0,0.45)",
        pointerEvents: "none",
      }}
    >
      {text}
    </div>
  );
};
