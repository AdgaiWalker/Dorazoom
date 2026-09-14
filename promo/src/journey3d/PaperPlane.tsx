import React, { useMemo } from "react";
import { interpolate, useCurrentFrame } from "remotion";
import * as THREE from "three";
import { BEATS } from "./timeline";
import { clamp01, seeded } from "./utils";

const wingGeometry = (side: -1 | 1) => {
  const geometry = new THREE.BufferGeometry();
  const positions = new Float32Array([
    1.55, 0, 0,
    -0.62, 0.13, 0,
    -0.92, -0.02, side * 1.08,
    1.55, 0, 0,
    -1.22, -0.08, side * 0.12,
    -0.92, -0.02, side * 1.08,
  ]);
  geometry.setAttribute("position", new THREE.BufferAttribute(positions, 3));
  geometry.computeVertexNormals();
  return geometry;
};

const creaseGeometry = () => {
  const points = [
    new THREE.Vector3(-1.2, 0.02, 0),
    new THREE.Vector3(1.55, 0.02, 0),
    new THREE.Vector3(-0.92, 0.02, 1.08),
    new THREE.Vector3(1.55, 0.02, 0),
    new THREE.Vector3(-0.92, 0.02, -1.08),
  ];
  return new THREE.BufferGeometry().setFromPoints(points);
};

export const getPlanePosition = (frame: number): [number, number, number] => {
  if (frame < BEATS.finale.start) {
    return [
      interpolate(frame, [0, BEATS.finale.start], [-4.9, 3.25], {
        extrapolateLeft: "clamp",
        extrapolateRight: "clamp",
      }),
      0.42 + Math.sin(frame * 0.028) * 0.28,
      0.5 + Math.sin(frame * 0.013) * 0.24,
    ];
  }

  if (frame < BEATS.finale.turn) {
    const t = interpolate(frame, [BEATS.finale.start, BEATS.finale.turn], [0, 1], {
      extrapolateLeft: "clamp",
      extrapolateRight: "clamp",
    });
    return [3.25 + t * 0.8, 0.42 + t * 1.6, 0.5 - t * 4.4];
  }

  const loop = interpolate(frame, [BEATS.finale.turn, BEATS.finale.impact], [0, Math.PI], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  const approach = interpolate(frame, [BEATS.finale.turn, BEATS.finale.impact], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  return [
    3.9 * Math.cos(loop) * (1 - approach),
    1.75 + Math.sin(loop * 2) * 0.7 - approach * 1.25,
    -3.9 + approach * 11,
  ];
};

export const PaperPlane: React.FC = () => {
  const frame = useCurrentFrame();
  const leftWing = useMemo(() => wingGeometry(-1), []);
  const rightWing = useMemo(() => wingGeometry(1), []);
  const creases = useMemo(() => creaseGeometry(), []);
  const stars = useMemo(() => {
    const random = seeded(114);
    const values = new Float32Array(24 * 3);
    for (let index = 0; index < 24; index += 1) {
      values[index * 3] = -0.8 + random() * 1.8;
      values[index * 3 + 1] = -0.03 + random() * 0.2;
      values[index * 3 + 2] = -0.62 + random() * 1.24;
    }
    const geometry = new THREE.BufferGeometry();
    geometry.setAttribute("position", new THREE.BufferAttribute(values, 3));
    return geometry;
  }, []);

  const [x, y, z] = getPlanePosition(frame);
  const desert = clamp01(
    interpolate(frame, [270, 390, 570, 630], [0, 1, 1, 0], {
      extrapolateLeft: "clamp",
      extrapolateRight: "clamp",
    }),
  );
  const space = clamp01(
    interpolate(frame, [570, 690, 840, 930], [0, 1, 1, 0], {
      extrapolateLeft: "clamp",
      extrapolateRight: "clamp",
    }),
  );
  const water = clamp01(
    interpolate(frame, [870, 990, 1140, 1200], [0, 1, 1, 0], {
      extrapolateLeft: "clamp",
      extrapolateRight: "clamp",
    }),
  );
  const impactFade = interpolate(frame, [BEATS.finale.impact, BEATS.finale.impact + 18], [1, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  const wingBend = Math.sin(frame * 0.18) * 0.035 + desert * Math.sin(frame * 0.34) * 0.08;
  const finaleRoll = interpolate(frame, [BEATS.finale.start, BEATS.finale.impact], [0, Math.PI * 2.15], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  const approachScale = interpolate(frame, [BEATS.finale.turn, BEATS.finale.impact], [1, 3.4], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  return (
    <group
      name="Same paper airplane topology"
      position={[x, y, z]}
      rotation={[
        -0.42 + Math.sin(frame * 0.025) * 0.055,
        -0.12,
        Math.sin(frame * 0.038) * 0.1 + finaleRoll,
      ]}
      scale={approachScale * impactFade * 1.28}
    >
      <mesh geometry={leftWing} rotation={[wingBend, 0, 0]}>
        <meshPhysicalMaterial
          color={desert > 0.5 ? "#d7a35b" : water > 0.5 ? "#c8f5ed" : "#f7f1e4"}
          roughness={0.78 - water * 0.65}
          metalness={water * 0.08}
          transmission={water * 0.35}
          transparent
          opacity={(1 - space * 0.62) * impactFade}
          side={THREE.DoubleSide}
        />
      </mesh>
      <mesh geometry={rightWing} rotation={[-wingBend, 0, 0]}>
        <meshPhysicalMaterial
          color={desert > 0.5 ? "#e3b86d" : water > 0.5 ? "#d8fff7" : "#fffaf0"}
          roughness={0.72 - water * 0.6}
          transmission={water * 0.42}
          transparent
          opacity={(1 - space * 0.62) * impactFade}
          side={THREE.DoubleSide}
        />
      </mesh>
      <lineSegments geometry={creases}>
        <lineBasicMaterial color="#8ca3aa" transparent opacity={(0.42 + space * 0.5) * impactFade} />
      </lineSegments>
      <points geometry={stars} visible={space > 0.01}>
        <pointsMaterial color="#e6f8ff" size={0.045} transparent opacity={space * impactFade} />
      </points>
      <mesh geometry={leftWing} visible={space > 0.01}>
        <meshBasicMaterial color="#bfe8ff" wireframe transparent opacity={space * 0.8 * impactFade} />
      </mesh>
      <mesh geometry={rightWing} visible={space > 0.01}>
        <meshBasicMaterial color="#d5f1ff" wireframe transparent opacity={space * 0.8 * impactFade} />
      </mesh>
    </group>
  );
};
