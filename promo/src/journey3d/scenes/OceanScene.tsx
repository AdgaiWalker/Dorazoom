import React, { useMemo } from "react";
import { useCurrentFrame } from "remotion";
import * as THREE from "three";

const createOcean = (frame: number) => {
  const geometry = new THREE.PlaneGeometry(22, 13, 52, 26);
  const positions = geometry.attributes.position as THREE.BufferAttribute;
  for (let index = 0; index < positions.count; index += 1) {
    const x = positions.getX(index);
    const y = positions.getY(index);
    const wave = Math.sin(x * 0.74 + frame * 0.024) * 0.12 + Math.cos(y * 0.65 - frame * 0.016) * 0.08;
    positions.setZ(index, wave);
  }
  positions.needsUpdate = true;
  geometry.computeVertexNormals();
  return geometry;
};

export const OceanScene: React.FC<{ opacity: number }> = ({ opacity }) => {
  const frame = useCurrentFrame();
  const ocean = useMemo(() => createOcean(frame), [frame]);

  return (
    <group name="Ocean response" position={[0, -1.48, 1.2]}>
      <mesh geometry={ocean} rotation={[-Math.PI / 2, 0, 0]}>
        <meshPhysicalMaterial
          color="#3ea6b5"
          roughness={0.16}
          metalness={0.06}
          transmission={0.18}
          transparent
          opacity={opacity * 0.8}
          side={THREE.DoubleSide}
        />
      </mesh>
      <mesh geometry={ocean} position={[0, 0.035, 0]} rotation={[-Math.PI / 2, 0, 0]}>
        <meshBasicMaterial color="#c6fff5" wireframe transparent opacity={opacity * 0.25} />
      </mesh>
      {Array.from({ length: 7 }, (_, index) => (
        <mesh
          key={index}
          position={[-4.5 + index * 1.5, 0.12 + Math.sin(frame * 0.03 + index) * 0.08, 1.2 + index * 0.18]}
          rotation={[-Math.PI / 2, 0, frame * 0.001]}
        >
          <ringGeometry args={[0.2 + index * 0.05, 0.215 + index * 0.05, 48]} />
          <meshBasicMaterial color="#d9fff8" transparent opacity={opacity * 0.36} side={THREE.DoubleSide} />
        </mesh>
      ))}
    </group>
  );
};
