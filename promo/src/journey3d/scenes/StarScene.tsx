import React, { useMemo } from "react";
import { useCurrentFrame } from "remotion";
import * as THREE from "three";
import { getPlanePosition } from "../PaperPlane";
import { seeded } from "../utils";

export const StarScene: React.FC<{ opacity: number }> = ({ opacity }) => {
  const frame = useCurrentFrame();
  const [planeX, planeY] = getPlanePosition(frame);
  const stars = useMemo(() => {
    const random = seeded(733);
    return Array.from({ length: 92 }, () => ({
      x: -8 + random() * 16,
      y: -2.2 + random() * 7.4,
      z: -2 + random() * 7,
      size: 0.018 + random() * 0.035,
    }));
  }, []);

  const pointGeometry = useMemo(() => {
    const values = new Float32Array(stars.length * 3);
    stars.forEach((star, index) => {
      values[index * 3] = star.x;
      values[index * 3 + 1] = star.y;
      values[index * 3 + 2] = star.z;
    });
    const geometry = new THREE.BufferGeometry();
    geometry.setAttribute("position", new THREE.BufferAttribute(values, 3));
    return geometry;
  }, [stars]);

  const connectionGeometry = useMemo(() => {
    const values: number[] = [];
    stars.forEach((star, index) => {
      if (index === 0) return;
      const previous = stars[index - 1];
      const nearPlane = Math.hypot(star.x - planeX, star.y - planeY) < 2.55;
      const nearEachOther = Math.hypot(star.x - previous.x, star.y - previous.y) < 2.1;
      if (nearPlane && nearEachOther) {
        values.push(previous.x, previous.y, previous.z, star.x, star.y, star.z);
      }
    });
    const geometry = new THREE.BufferGeometry();
    geometry.setAttribute("position", new THREE.Float32BufferAttribute(values, 3));
    return geometry;
  }, [planeX, planeY, stars]);

  return (
    <group name="Constellations revealed by attention" rotation={[0, frame * 0.00025, 0]}>
      <points geometry={pointGeometry}>
        <pointsMaterial
          color="#dff5ff"
          size={0.055}
          sizeAttenuation
          transparent
          opacity={opacity * 0.95}
        />
      </points>
      <lineSegments geometry={connectionGeometry}>
        <lineBasicMaterial color="#a9dcff" transparent opacity={opacity * 0.5} />
      </lineSegments>
      <mesh position={[0, -2.2, 1]} rotation={[-Math.PI / 2, 0, 0]}>
        <ringGeometry args={[3.2, 3.23, 80]} />
        <meshBasicMaterial color="#7cbcec" transparent opacity={opacity * 0.18} side={THREE.DoubleSide} />
      </mesh>
    </group>
  );
};
