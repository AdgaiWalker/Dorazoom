"use client";

import type { HTMLAttributes, ReactNode } from "react";
import { useEffect, useRef, useState } from "react";

interface MagnetProps extends HTMLAttributes<HTMLDivElement> {
  children: ReactNode;
  padding?: number;
  disabled?: boolean;
  magnetStrength?: number;
  wrapperClassName?: string;
  innerClassName?: string;
}

export default function Magnet({
  children,
  padding = 72,
  disabled = false,
  magnetStrength = 8,
  wrapperClassName = "",
  innerClassName = "",
  ...props
}: MagnetProps) {
  const [active, setActive] = useState(false);
  const [position, setPosition] = useState({ x: 0, y: 0 });
  const magnetRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const handlePointerMove = (event: PointerEvent) => {
      const magnet = magnetRef.current;
      const reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
      if (!magnet || disabled || reduced || event.pointerType === "touch") {
        setActive(false);
        setPosition({ x: 0, y: 0 });
        return;
      }

      const { left, top, width, height } = magnet.getBoundingClientRect();
      const centerX = left + width / 2;
      const centerY = top + height / 2;
      const nearby = Math.abs(centerX - event.clientX) < width / 2 + padding
        && Math.abs(centerY - event.clientY) < height / 2 + padding;

      setActive(nearby);
      setPosition(nearby
        ? { x: (event.clientX - centerX) / magnetStrength, y: (event.clientY - centerY) / magnetStrength }
        : { x: 0, y: 0 });
    };

    window.addEventListener("pointermove", handlePointerMove, { passive: true });
    return () => window.removeEventListener("pointermove", handlePointerMove);
  }, [disabled, magnetStrength, padding]);

  return (
    <div ref={magnetRef} className={wrapperClassName} {...props}>
      <div
        className={innerClassName}
        style={{
          transform: `translate3d(${position.x}px, ${position.y}px, 0)`,
          transition: active
            ? "transform 260ms cubic-bezier(.2,.8,.2,1)"
            : "transform 420ms cubic-bezier(.2,.8,.2,1)",
          willChange: "transform",
        }}
      >
        {children}
      </div>
    </div>
  );
}
