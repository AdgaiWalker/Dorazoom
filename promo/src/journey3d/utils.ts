import { interpolate } from "remotion";
import * as THREE from "three";

export const clamp01 = (value: number) => Math.min(1, Math.max(0, value));

export const fadeWindow = (
  frame: number,
  start: number,
  end: number,
  fade = 48,
) =>
  interpolate(
    frame,
    [start, start + fade, end - fade, end],
    [0, 1, 1, 0],
    { extrapolateLeft: "clamp", extrapolateRight: "clamp" },
  );

export const seeded = (seed: number) => {
  let value = seed >>> 0;
  return () => {
    value += 0x6d2b79f5;
    let t = value;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
};

export const lineGeometry = (points: Array<[number, number, number]>) => {
  const geometry = new THREE.BufferGeometry();
  geometry.setFromPoints(points.map(([x, y, z]) => new THREE.Vector3(x, y, z)));
  return geometry;
};

export const color = (value: string) => new THREE.Color(value);
