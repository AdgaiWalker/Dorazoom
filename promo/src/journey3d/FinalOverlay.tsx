import React from "react";
import { Easing, Interactive, interpolate, useCurrentFrame } from "remotion";
import { BEATS } from "./timeline";

export const FinalOverlay: React.FC<{ title: string; subtitle: string }> = ({
  title,
  subtitle,
}) => {
  const frame = useCurrentFrame();

  return (
    <>
      <div
        style={{
          position: "absolute",
          inset: 0,
          backgroundColor: "#fffdf3",
          opacity: interpolate(
            frame,
            [BEATS.finale.impact - 4, BEATS.finale.impact + 5, BEATS.finale.impact + 26],
            [0, 0.9, 0],
            { extrapolateLeft: "clamp", extrapolateRight: "clamp" },
          ),
        }}
      />
      {[0, 1, 2].map((ring) => (
        <div
          key={ring}
          style={{
            position: "absolute",
            left: "50%",
            top: "50%",
            width: 260 + ring * 180,
            height: 260 + ring * 180,
            marginLeft: -(130 + ring * 90),
            marginTop: -(130 + ring * 90),
            border: "2px solid rgba(255,255,245,0.78)",
            borderRadius: "50%",
            opacity: interpolate(
              frame,
              [BEATS.finale.impact - 6, BEATS.finale.impact, BEATS.finale.impact + 28 + ring * 5],
              [0, 0.82, 0],
              { extrapolateLeft: "clamp", extrapolateRight: "clamp" },
            ),
            scale: interpolate(
              frame,
              [BEATS.finale.impact - 4, BEATS.finale.impact + 34 + ring * 5],
              [0.2, 2.1],
              {
                extrapolateLeft: "clamp",
                extrapolateRight: "clamp",
                easing: Easing.bezier(0.16, 1, 0.3, 1),
              },
            ),
          }}
        />
      ))}
      <Interactive.Div
        name="Final brand lockup"
        style={{
          position: "absolute",
          inset: 0,
          display: "flex",
          flexDirection: "column",
          alignItems: "center",
          justifyContent: "center",
          paddingTop: 20,
          color: "#102d35",
          textAlign: "center",
          opacity: interpolate(frame, [BEATS.finale.impact + 16, BEATS.finale.impact + 44], [0, 1], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
            easing: Easing.bezier(0.16, 1, 0.3, 1),
          }),
          translate: interpolate(frame, [BEATS.finale.impact + 16, BEATS.finale.impact + 50], ["0px 42px", "0px 0px"], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
            easing: Easing.bezier(0.16, 1, 0.3, 1),
          }),
        }}
      >
        <div style={{ fontSize: 30, fontWeight: 700, letterSpacing: "0.1em", marginBottom: 26 }}>
          DoraZoom
        </div>
        <div
          style={{
            maxWidth: 1480,
            fontSize: 112,
            fontWeight: 650,
            lineHeight: 0.98,
            letterSpacing: "-0.065em",
          }}
        >
          {title}
        </div>
        <div
          style={{
            maxWidth: 980,
            marginTop: 34,
            fontSize: 48,
            fontWeight: 500,
            lineHeight: 1.45,
            color: "rgba(16,45,53,0.66)",
          }}
        >
          {subtitle}
        </div>
      </Interactive.Div>
    </>
  );
};
