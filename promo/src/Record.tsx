import React from "react";
import { AbsoluteFill, Easing, interpolate, Sequence, useCurrentFrame } from "remotion";
import { Caption } from "./Caption";
import { INK, PAPER, RED, SANS } from "./tokens";

export const Record: React.FC<{ duration: number }> = ({ duration }) => {
  const f = useCurrentFrame();
  const recOut = interpolate(f, [38, 48], [1, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  const player = interpolate(f, [42, 48, 56], [0, 1.04, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
    easing: Easing.out(Easing.cubic),
  });
  const head = interpolate(f, [56, duration - 12], [0.12, 0.62], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  return (
    <AbsoluteFill style={{ backgroundColor: "#0b0c0e", fontFamily: SANS }}>
      <div style={{ position: "absolute", inset: 0, opacity: recOut }}>
        <Tape />
        <div
          style={{
            position: "absolute",
            top: 48,
            left: 56,
            display: "flex",
            alignItems: "center",
            gap: 10,
            color: "white",
            fontSize: 22,
            letterSpacing: "0.08em",
          }}
        >
          <div style={{ width: 14, height: 14, borderRadius: 99, background: RED }} />
          REC
        </div>
      </div>
      <div
        style={{
          position: "absolute",
          inset: 0,
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          opacity: player > 0 ? 1 : 0,
          transform: `scale(${Math.max(player, 0.001)})`,
        }}
      >
        <div
          style={{
            width: 1280,
            background: "#16181c",
            borderRadius: 20,
            overflow: "hidden",
            boxShadow: "0 30px 80px rgba(0,0,0,0.5)",
          }}
        >
          <div style={{ height: 640, position: "relative" }}>
            <Tape compact />
          </div>
          <div style={{ padding: "18px 22px 22px", color: "#e5e7eb" }}>
            <div style={{ fontSize: 18, color: "#9ca3af" }}>导出 · 几何课-步骤二.mov</div>
            <div
              style={{
                marginTop: 14,
                height: 6,
                borderRadius: 99,
                background: "#2a2e35",
                position: "relative",
              }}
            >
              <div
                style={{
                  position: "absolute",
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: `${head * 100}%`,
                  background: RED,
                  borderRadius: 99,
                }}
              />
            </div>
          </div>
        </div>
      </div>
      <Sequence from={60} durationInFrames={Math.max(duration - 60, 1)}>
        <Caption text="圈画留在成片里" duration={duration - 60} />
      </Sequence>
    </AbsoluteFill>
  );
};

const Tape: React.FC<{ compact?: boolean }> = ({ compact }) => (
  <div
    style={{
      width: "100%",
      height: "100%",
      background: PAPER,
      color: INK,
      padding: compact ? "48px 64px" : "120px 180px",
      boxSizing: "border-box",
      position: "relative",
    }}
  >
    <div style={{ fontSize: compact ? 22 : 28, color: "#6b7280" }}>步骤 2</div>
    <div style={{ fontSize: compact ? 36 : 48, fontWeight: 650, marginTop: 12, maxWidth: 900 }}>
      △ABD ≌ △ACD，所以 ∠ADB = 90°。
    </div>
    <svg
      width="100%"
      height="100%"
      style={{ position: "absolute", inset: 0 }}
      viewBox="0 0 1280 640"
      preserveAspectRatio="none"
    >
      <ellipse
        cx={640}
        cy={148}
        rx={520}
        ry={72}
        fill="none"
        stroke={RED}
        strokeWidth={8}
      />
    </svg>
  </div>
);
