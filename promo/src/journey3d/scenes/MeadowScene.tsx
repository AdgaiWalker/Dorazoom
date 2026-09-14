import React, { useMemo } from "react";
import { useCurrentFrame } from "remotion";
import * as THREE from "three";
import { seeded } from "../utils";

const createRollingTerrain = (garden: boolean) => {
  const geometry = new THREE.PlaneGeometry(22, 13, 58, 32);
  const positions = geometry.attributes.position as THREE.BufferAttribute;
  for (let index = 0; index < positions.count; index += 1) {
    const x = positions.getX(index);
    const y = positions.getY(index);
    const broad = Math.sin(x * 0.42) * (garden ? 0.32 : 0.22);
    const crossing = Math.cos(y * 0.55 + x * 0.12) * (garden ? 0.2 : 0.12);
    const path = Math.exp(-Math.pow(x * 0.22 + y * 0.08, 2)) * (garden ? -0.24 : -0.1);
    positions.setZ(index, broad + crossing + path);
  }
  positions.needsUpdate = true;
  geometry.computeVertexNormals();
  return geometry;
};

export const MeadowScene: React.FC<{ opacity: number; garden?: boolean }> = ({
  opacity,
  garden = false,
}) => {
  const frame = useCurrentFrame();
  const grass = useMemo(() => {
    const random = seeded(garden ? 922 : 114);
    const values: number[] = [];
    for (let index = 0; index < 190; index += 1) {
      const x = -9 + random() * 18;
      const z = -2 + random() * 7.5;
      const height = 0.15 + random() * (garden ? 0.72 : 0.48);
      values.push(x, -1.58, z, x + (random() - 0.5) * 0.06, -1.58 + height, z);
    }
    const geometry = new THREE.BufferGeometry();
    geometry.setAttribute("position", new THREE.Float32BufferAttribute(values, 3));
    return geometry;
  }, [garden]);

  const flowers = useMemo(() => {
    const random = seeded(1804);
    const values = new Float32Array(44 * 3);
    for (let index = 0; index < 44; index += 1) {
      values[index * 3] = -8 + random() * 16;
      values[index * 3 + 1] = -1.05 + random() * 0.24;
      values[index * 3 + 2] = -1 + random() * 5.5;
    }
    const geometry = new THREE.BufferGeometry();
    geometry.setAttribute("position", new THREE.BufferAttribute(values, 3));
    return geometry;
  }, []);
  const terrain = useMemo(() => createRollingTerrain(garden), [garden]);

  return (
    <group name={garden ? "Dream garden growth" : "Original meadow"}>
      <mesh geometry={terrain} position={[0, -1.7, 1.5]} rotation={[-Math.PI / 2, 0, 0]}>
        <meshStandardMaterial
          color={garden ? "#527d5d" : "#71985f"}
          roughness={0.94}
          transparent
          opacity={opacity}
          wireframe={false}
          side={THREE.DoubleSide}
        />
      </mesh>
      <lineSegments geometry={grass} rotation={[0, 0, Math.sin(frame * 0.025) * 0.005]}>
        <lineBasicMaterial
          color={garden ? "#e6f1c7" : "#dbe7a8"}
          transparent
          opacity={opacity * 0.9}
        />
      </lineSegments>
      {garden ? (
        <points geometry={flowers}>
          <pointsMaterial color="#f5d477" size={0.055} transparent opacity={opacity * 0.9} />
        </points>
      ) : null}
      <mesh geometry={terrain} position={[0, -1.675, 1.5]} rotation={[-Math.PI / 2, 0, 0]}>
        <meshBasicMaterial color="#d9f3e5" wireframe transparent opacity={opacity * 0.25} />
      </mesh>
      {!garden ? (
        <mesh position={[-5.7, 3.1, -2.6]}>
          <circleGeometry args={[0.55, 64]} />
          <meshBasicMaterial color="#fff0a9" transparent opacity={opacity * 0.88} />
        </mesh>
      ) : null}
    </group>
  );
};
