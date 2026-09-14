import React, { useMemo } from "react";
import { useCurrentFrame } from "remotion";
import * as THREE from "three";
import { seeded } from "../utils";

const createDune = (phase: number) => {
  const geometry = new THREE.PlaneGeometry(22, 12, 54, 24);
  const positions = geometry.attributes.position as THREE.BufferAttribute;
  for (let index = 0; index < positions.count; index += 1) {
    const x = positions.getX(index);
    const y = positions.getY(index);
    positions.setZ(index, Math.sin(x * 0.46 + phase) * 0.34 + Math.cos(y * 0.55) * 0.18);
  }
  positions.needsUpdate = true;
  geometry.computeVertexNormals();
  return geometry;
};

export const DesertScene: React.FC<{ opacity: number }> = ({ opacity }) => {
  const frame = useCurrentFrame();
  const dune = useMemo(() => createDune(0.4), []);
  const contours = useMemo(() => createDune(1.7), []);
  const particles = useMemo(() => {
    const random = seeded(404);
    const values = new Float32Array(170 * 3);
    for (let index = 0; index < 170; index += 1) {
      values[index * 3] = -9 + random() * 18;
      values[index * 3 + 1] = -1.2 + random() * 3.6;
      values[index * 3 + 2] = -1.5 + random() * 7;
    }
    const geometry = new THREE.BufferGeometry();
    geometry.setAttribute("position", new THREE.BufferAttribute(values, 3));
    return geometry;
  }, []);

  return (
    <group name="Desert resistance" position={[Math.sin(frame * 0.006) * 0.2, -1.25, 1.2]}>
      <mesh geometry={dune} rotation={[-Math.PI / 2, 0, 0]}>
        <meshStandardMaterial color="#c8924e" roughness={0.96} transparent opacity={opacity} />
      </mesh>
      <mesh geometry={contours} position={[0, 0.06, 0]} rotation={[-Math.PI / 2, 0, 0]}>
        <meshBasicMaterial color="#f7d89a" wireframe transparent opacity={opacity * 0.26} />
      </mesh>
      <points geometry={particles} rotation={[0, 0, frame * 0.0009]}>
        <pointsMaterial color="#ffd58a" size={0.028} transparent opacity={opacity * 0.62} />
      </points>
    </group>
  );
};
