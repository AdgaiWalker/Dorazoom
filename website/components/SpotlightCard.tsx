"use client";

import type { HTMLAttributes, PropsWithChildren, PointerEventHandler } from "react";
import { useRef } from "react";

interface SpotlightCardProps extends PropsWithChildren, HTMLAttributes<HTMLDivElement> {
  spotlightColor?: string;
}

export default function SpotlightCard({
  children,
  className = "",
  spotlightColor = "rgba(255, 255, 255, 0.22)",
  onPointerMove,
  ...props
}: SpotlightCardProps) {
  const cardRef = useRef<HTMLDivElement>(null);

  const handlePointerMove: PointerEventHandler<HTMLDivElement> = (event) => {
    const card = cardRef.current;
    if (!card || window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;

    const rect = card.getBoundingClientRect();
    card.style.setProperty("--mouse-x", `${event.clientX - rect.left}px`);
    card.style.setProperty("--mouse-y", `${event.clientY - rect.top}px`);
    card.style.setProperty("--spotlight-color", spotlightColor);
    onPointerMove?.(event);
  };

  return (
    <div
      ref={cardRef}
      className={`card-spotlight ${className}`}
      onPointerMove={handlePointerMove}
      {...props}
    >
      {children}
    </div>
  );
}
