import React from "react";
import { AbsoluteFill, interpolate, useCurrentFrame } from "remotion";
import { RED, SANS } from "./tokens";

export const Open: React.FC = () => {
  const f = useCurrentFrame();
  const inn = interpolate(f, [8, 22], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  return (
    <AbsoluteFill
      style={{
        backgroundColor: "#0b0c0e",
        display: "flex",
        flexDirection: "column",
        alignItems: "center",
        justifyContent: "center",
        fontFamily: SANS,
        color: "white",
      }}
    >
      <div
        style={{
          width: 10,
          height: 10,
          background: RED,
          borderRadius: 2,
          marginBottom: 28,
          opacity: inn,
        }}
      />
      <div
        style={{
          fontSize: 64,
          fontWeight: 560,
          letterSpacing: "-0.04em",
          opacity: inn,
          transform: `translateY(${(1 - inn) * 12}px)`,
        }}
      >
        你一指，大家看到同一处
      </div>
    </AbsoluteFill>
  );
};

export const Close: React.FC = () => {
  const f = useCurrentFrame();
  const inn = interpolate(f, [6, 20], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  const sub = interpolate(f, [28, 40], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  return (
    <AbsoluteFill
      style={{
        backgroundColor: "#0b0c0e",
        display: "flex",
        flexDirection: "column",
        alignItems: "center",
        justifyContent: "center",
        fontFamily: SANS,
        color: "white",
      }}
    >
      <div
        style={{
          fontSize: 80,
          fontWeight: 650,
          letterSpacing: "-0.05em",
          opacity: inn,
        }}
      >
        DoraZoom
      </div>
      <div
        style={{
          marginTop: 22,
          fontSize: 28,
          color: "#9ca3af",
          letterSpacing: "0.18em",
          opacity: sub,
        }}
      >
        指 · 记下 · 交出去
      </div>
    </AbsoluteFill>
  );
};
