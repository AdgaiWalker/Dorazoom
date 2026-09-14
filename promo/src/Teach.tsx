import React from "react";
import { AbsoluteFill, Easing, interpolate, Sequence, useCurrentFrame } from "remotion";
import { Caption } from "./Caption";
import { INK, MUTED, PAPER, RED, SANS } from "./tokens";

const TARGET = { cx: 980, cy: 392 };

export const Teach: React.FC<{ duration: number }> = ({ duration }) => {
  const f = useCurrentFrame();
  const zoom = interpolate(f, [30, 36, 41], [1, 2.15, 2.05], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
    easing: Easing.bezier(0.55, 0, 0.7, 1),
  });
  const cx = interpolate(f, [30, 36], [960, TARGET.cx], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
    easing: Easing.in(Easing.quad),
  });
  const cy = interpolate(f, [30, 36], [540, TARGET.cy], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
    easing: Easing.in(Easing.quad),
  });
  const vignette = interpolate(f, [30, 50], [0.18, 0.62], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  const circle = interpolate(f, [48, 78], [1, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  const other = interpolate(f, [110, 150], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
    easing: Easing.out(Easing.cubic),
  });
  const otherX = interpolate(f, [110, 150], [180, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
    easing: Easing.out(Easing.cubic),
  });

  return (
    <AbsoluteFill style={{ backgroundColor: "#1a1c1f", overflow: "hidden" }}>
      <div
        style={{
          position: "absolute",
          width: 1920,
          height: 1080,
          transform: `translate(${960 - cx * zoom}px, ${540 - cy * zoom}px) scale(${zoom})`,
          transformOrigin: "0 0",
        }}
      >
        <MathPaper />
        <svg
          width={1920}
          height={1080}
          style={{ position: "absolute", inset: 0 }}
        >
          <ellipse
            cx={TARGET.cx}
            cy={TARGET.cy}
            rx={520}
            ry={70}
            pathLength={1}
            fill="none"
            stroke={RED}
            strokeWidth={6}
            strokeDasharray={1}
            strokeDashoffset={circle}
            strokeLinecap="round"
          />
          <ellipse
            cx={TARGET.cx + otherX}
            cy={TARGET.cy + 6}
            rx={534}
            ry={80}
            pathLength={1}
            fill="none"
            stroke="rgba(255,255,255,0.72)"
            strokeWidth={3}
            opacity={other}
          />
        </svg>
      </div>
      <AbsoluteFill
        style={{
          background: `radial-gradient(circle at 50% 48%, transparent 28%, rgba(0,0,0,${vignette}) 78%)`,
          pointerEvents: "none",
        }}
      />
      <Sequence from={150} durationInFrames={Math.max(duration - 150, 1)}>
        <Caption text="全班看见同一步" duration={duration - 150} />
      </Sequence>
    </AbsoluteFill>
  );
};

const MathPaper: React.FC = () => {
  return (
    <div
      style={{
        width: 1920,
        height: 1080,
        background: PAPER,
        color: INK,
        fontFamily: SANS,
        padding: "72px 160px",
        boxSizing: "border-box",
      }}
    >
      <div style={{ fontSize: 18, letterSpacing: "0.18em", color: MUTED }}>
        网课 · 高二几何
      </div>
      <div style={{ fontSize: 44, fontWeight: 650, marginTop: 18 }}>
        在 △ABC 中，AB = AC，D 为 BC 中点。求证：AD ⊥ BC。
      </div>
      <div style={{ marginTop: 56, display: "flex", flexDirection: "column", gap: 28 }}>
        <Step n="1" text="连结 AD。因为 AB = AC，所以 △ABD 与 △ACD 有两边对应相等。" />
        <Step
          n="2"
          text="又 BD = DC，故 △ABD ≌ △ACD（SSS）。因此 ∠ADB = ∠ADC = 90°。"
          hot
        />
        <Step n="3" text="所以 AD ⊥ BC。证毕。" />
      </div>
    </div>
  );
};

const Step: React.FC<{ n: string; text: string; hot?: boolean }> = ({
  n,
  text,
  hot,
}) => (
  <div
    style={{
      display: "flex",
      gap: 20,
      alignItems: "flex-start",
      padding: "22px 28px",
      borderRadius: 16,
      background: hot ? "rgba(255,59,48,0.06)" : "transparent",
    }}
  >
    <div
      style={{
        width: 44,
        height: 44,
        borderRadius: 999,
        background: hot ? RED : "#E5E1D6",
        color: hot ? "white" : INK,
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        fontWeight: 700,
        flexShrink: 0,
      }}
    >
      {n}
    </div>
    <div style={{ fontSize: 32, lineHeight: 1.45, paddingTop: 4 }}>{text}</div>
  </div>
);
