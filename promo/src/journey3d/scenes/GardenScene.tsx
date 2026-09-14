import React, { useMemo } from "react";
import { useCurrentFrame } from "remotion";
import * as THREE from "three";
import { seeded } from "../utils";
import { MeadowScene } from "./MeadowScene";

export const GardenScene: React.FC<{ opacity: number }> = ({ opacity }) => {
  const frame = useCurrentFrame();
  const vines = useMemo(() => {
    const random = seeded(2048);
    return Array.from({ length: 9 }, (_, vine) => {
      const points: Array<[number, number, number]> = [];
      const baseX = -7 + vine * 1.8 + random() * 0.5;
      for (let index = 0; index < 12; index += 1) {
        points.push([
          baseX + Math.sin(index * 0.62 + vine) * 0.26,
          -1.48 + index * 0.25,
          1.5 + Math.cos(index * 0.4 + vine) * 0.22,
        ]);
      }
      const geometry = new THREE.BufferGeometry();
      geometry.setFromPoints(points.map(([x, y, z]) => new THREE.Vector3(x, y, z)));
      return geometry;
    });
  }, []);

  return (
    <group name="Changed beginning, dream garden">
      <MeadowScene opacity={opacity} garden />
      {vines.map((geometry, index) => (
        <lineSegments key={index} geometry={geometry} scale={[1, Math.min(1, Math.max(0, (frame - 1140 - index * 9) / 90)), 1]}>
          <lineBasicMaterial
            color={index % 3 === 0 ? "#f2d17c" : "#c9eff3"}
            transparent
            opacity={opacity * 0.78}
          />
        </lineSegments>
      ))}
      <mesh position={[0, -1.54, 1.2]} rotation={[-Math.PI / 2, 0, 0]}>
        <ringGeometry args={[1.4, 4.4, 100]} />
        <meshBasicMaterial color="#bff5ec" transparent opacity={opacity * 0.15} side={THREE.DoubleSide} />
      </mesh>
    </group>
  );
};
