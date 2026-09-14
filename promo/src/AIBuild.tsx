import React from "react";
import {
  AbsoluteFill,
  Easing,
  interpolate,
  Sequence,
  useCurrentFrame,
} from "remotion";
import { Caption } from "./Caption";
import { INK, MONO, RED, SANS } from "./tokens";

const BTN = { x: 124, y: 400, w: 364, h: 52 };
const PAD = 10;
const SEL = {
  x: BTN.x - PAD,
  y: BTN.y - PAD,
  w: BTN.w + PAD * 2,
  h: BTN.h + PAD * 2,
};
const PASTE = { x: 1172, y: 176, w: 200, h: 96 };

export const AIBuild: React.FC<{ duration: number }> = ({ duration }) => {
  const f = useCurrentFrame();

  const selT = interpolate(f, [6, 34], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
    easing: Easing.out(Easing.cubic),
  });
  const gray = interpolate(f, [6, 16, 58, 78], [0, 1, 1, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  const flash = interpolate(f, [38, 40, 46], [0, 1, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  const fly = interpolate(f, [62, 102], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
    easing: Easing.bezier(0.22, 0.9, 0.28, 1),
  });
  const pastePop = interpolate(f, [100, 108], [0.86, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
    easing: Easing.out(Easing.back(1.6)),
  });
  const slam = interpolate(f, [148, 154], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
    easing: Easing.in(Easing.quad),
  });
  const slamScale = interpolate(f, [148, 154, 162], [2.35, 0.97, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  const shake =
    f >= 154 && f < 160
      ? Math.sin((f - 154) * 4.2) * 9 * Math.exp(-(f - 154) / 1.8)
      : 0;

  const sw = SEL.w * selT;
  const sh = SEL.h * selT;
  const sx = SEL.x + (SEL.w - sw) / 2;
  const sy = SEL.y + (SEL.h - sh) / 2;

  const cropX = interpolate(fly, [0, 1], [SEL.x, PASTE.x]);
  const cropY = interpolate(fly, [0, 1], [SEL.y, PASTE.y]);
  const cropW = interpolate(fly, [0, 1], [SEL.w, PASTE.w]);
  const cropH = interpolate(fly, [0, 1], [SEL.h, PASTE.h]);
  const cropOn = f >= 40 && f < 102;

  return (
    <AbsoluteFill style={{ backgroundColor: "#0e1013", fontFamily: SANS }}>
      <Desk pasted={fly > 0.92} generating={f > 108 && slam < 0.2} pastePop={pastePop} />

      {gray > 0.01 ? (
        <div
          style={{
            position: "absolute",
            inset: 0,
            filter: "grayscale(1) brightness(0.55)",
            opacity: gray,
            clipPath: hole(sx, sy, sw, sh),
          }}
        >
          <Desk pasted={false} generating={false} pastePop={1} />
        </div>
      ) : null}

      {selT > 0 && slam < 0.3 ? (
        <div
          style={{
            position: "absolute",
            left: sx,
            top: sy,
            width: Math.max(sw, 1),
            height: Math.max(sh, 1),
            border: `2px solid ${RED}`,
            boxShadow: "0 0 0 1px rgba(255,255,255,0.35)",
            pointerEvents: "none",
            opacity: interpolate(f, [70, 90], [1, 0], {
              extrapolateLeft: "clamp",
              extrapolateRight: "clamp",
            }),
          }}
        />
      ) : null}

      {cropOn ? <Crop x={cropX} y={cropY} w={cropW} h={cropH} /> : null}

      {flash > 0 ? (
        <AbsoluteFill style={{ background: "white", opacity: flash * 0.72 }} />
      ) : null}

      {slam > 0 ? (
        <div
          style={{
            position: "absolute",
            inset: 0,
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            transform: `translateX(${shake}px) scale(${slamScale})`,
            background: "rgba(14,16,19,0.55)",
          }}
        >
          <ResultPage />
        </div>
      ) : null}

      <Sequence from={168} durationInFrames={Math.max(duration - 168, 1)}>
        <Caption text="圈住的，变成了页面" duration={duration - 168} />
      </Sequence>
    </AbsoluteFill>
  );
};

function hole(x: number, y: number, w: number, h: number) {
  return `path(evenodd, "M0 0H1920V1080H0Z M${x} ${y}H${x + w}V${y + h}H${x}Z")`;
}

const Desk: React.FC<{ pasted: boolean; generating: boolean; pastePop: number }> = ({
  pasted,
  generating,
  pastePop,
}) => (
  <div style={{ position: "absolute", inset: 0, display: "flex" }}>
    <div style={{ width: "58%", padding: 36 }}>
      <Browser />
    </div>
    <div style={{ flex: 1, padding: "36px 28px 36px 0" }}>
      <Chat pasted={pasted} generating={generating} pastePop={pastePop} />
    </div>
  </div>
);

const Browser: React.FC = () => (
  <div
    style={{
      height: "100%",
      background: "#f6f7f9",
      borderRadius: 16,
      overflow: "hidden",
      color: INK,
      position: "relative",
    }}
  >
    <div
      style={{
        height: 44,
        background: "#e8eaed",
        display: "flex",
        alignItems: "center",
        gap: 8,
        padding: "0 16px",
      }}
    >
      <Dot c="#ff5f57" />
      <Dot c="#febc2e" />
      <Dot c="#28c840" />
      <div
        style={{
          marginLeft: 16,
          flex: 1,
          height: 22,
          borderRadius: 6,
          background: "white",
          fontSize: 13,
          color: "#6b7280",
          display: "flex",
          alignItems: "center",
          paddingLeft: 10,
          fontFamily: MONO,
        }}
      >
        localhost:5173
      </div>
    </div>
    <div style={{ padding: 48 }}>
      <div style={{ fontSize: 18, color: "#6b7280" }}>Acme / Pricing</div>
      <div style={{ fontSize: 48, fontWeight: 650, marginTop: 8 }}>选一个开始用</div>
      <div
        style={{
          marginTop: 40,
          width: 420,
          background: "white",
          borderRadius: 20,
          padding: 28,
          boxShadow: "0 12px 40px rgba(0,0,0,0.08)",
        }}
      >
        <div style={{ fontSize: 16, color: "#6b7280" }}>Pro</div>
        <div style={{ fontSize: 42, fontWeight: 700 }}>¥ 29 / 月</div>
        <div
          style={{
            marginTop: 28,
            height: 52,
            borderRadius: 12,
            background: "#111827",
            color: "white",
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            fontSize: 20,
            fontWeight: 600,
          }}
        >
          开始试用
        </div>
      </div>
    </div>
  </div>
);

const Chat: React.FC<{ pasted: boolean; generating: boolean; pastePop: number }> = ({
  pasted,
  generating,
  pastePop,
}) => (
  <div
    style={{
      height: "100%",
      background: "#171a1f",
      borderRadius: 16,
      padding: 28,
      color: "#e5e7eb",
      display: "flex",
      flexDirection: "column",
    }}
  >
    <div style={{ fontSize: 14, letterSpacing: "0.12em", color: "#9ca3af" }}>
      PROMPT
    </div>
    <div style={{ marginTop: 18, fontSize: 22, lineHeight: 1.5, color: "#d1d5db" }}>
      按圈出的按钮复现这个前端。只要这一个 CTA。
    </div>
    <div
      style={{
        marginTop: 22,
        minHeight: 132,
        borderRadius: 12,
        border: pasted ? "1px solid #374151" : "1px dashed #374151",
        background: "#111318",
        padding: 12,
      }}
    >
      {pasted ? (
        <div
          style={{
            width: 200,
            height: 96,
            borderRadius: 8,
            overflow: "hidden",
            boxShadow: "0 0 0 1px #fff",
            transform: `scale(${pastePop})`,
            transformOrigin: "top left",
          }}
        >
          <CropInner />
        </div>
      ) : (
        <div style={{ fontSize: 16, color: "#4b5563", padding: 8 }}>
          ⌘V 粘贴截图
        </div>
      )}
    </div>
    <div
      style={{
        marginTop: "auto",
        fontSize: 16,
        color: "#6b7280",
        fontFamily: MONO,
        opacity: generating ? 1 : 0,
      }}
    >
      生成中…
    </div>
  </div>
);

const Crop: React.FC<{ x: number; y: number; w: number; h: number }> = ({
  x,
  y,
  w,
  h,
}) => (
  <div
    style={{
      position: "absolute",
      left: x,
      top: y,
      width: w,
      height: h,
      overflow: "hidden",
      borderRadius: 6,
      boxShadow: "0 12px 40px rgba(0,0,0,0.45), 0 0 0 2px #fff",
    }}
  >
    <CropInner />
  </div>
);

const CropInner: React.FC = () => (
  <div
    style={{
      width: "100%",
      height: "100%",
      background: "#111827",
      color: "white",
      display: "flex",
      alignItems: "center",
      justifyContent: "center",
      fontSize: 22,
      fontWeight: 650,
      fontFamily: SANS,
    }}
  >
    开始试用
  </div>
);

const ResultPage: React.FC = () => (
  <div
    style={{
      width: 1120,
      height: 720,
      background: "#f6f7f9",
      borderRadius: 16,
      overflow: "hidden",
      boxShadow: "0 30px 80px rgba(0,0,0,0.5)",
      color: INK,
      fontFamily: SANS,
    }}
  >
    <div
      style={{
        height: 44,
        background: "#e8eaed",
        display: "flex",
        alignItems: "center",
        gap: 8,
        padding: "0 16px",
      }}
    >
      <Dot c="#ff5f57" />
      <Dot c="#febc2e" />
      <Dot c="#28c840" />
      <div
        style={{
          marginLeft: 16,
          flex: 1,
          height: 22,
          borderRadius: 6,
          background: "white",
          fontSize: 13,
          color: "#6b7280",
          display: "flex",
          alignItems: "center",
          paddingLeft: 10,
          fontFamily: MONO,
        }}
      >
        localhost:5173
      </div>
    </div>
    <div
      style={{
        height: 676,
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
      }}
    >
      <div
        style={{
          width: 440,
          background: "white",
          borderRadius: 20,
          padding: 36,
          boxShadow: "0 12px 40px rgba(0,0,0,0.08)",
        }}
      >
        <div style={{ fontSize: 16, color: "#6b7280" }}>Pro</div>
        <div style={{ fontSize: 42, fontWeight: 700 }}>¥ 29 / 月</div>
        <div
          style={{
            marginTop: 28,
            height: 56,
            borderRadius: 12,
            background: "#111827",
            color: "white",
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            fontSize: 22,
            fontWeight: 650,
            outline: `3px solid ${RED}`,
            outlineOffset: 6,
          }}
        >
          开始试用
        </div>
      </div>
    </div>
  </div>
);

const Dot: React.FC<{ c: string }> = ({ c }) => (
  <div style={{ width: 12, height: 12, borderRadius: 99, background: c }} />
);
