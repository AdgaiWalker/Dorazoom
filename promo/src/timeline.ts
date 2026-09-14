export const FPS = 30;
export const WIDTH = 1920;
export const HEIGHT = 1080;

export const SHOTS = {
  open: { from: 0, dur: 75 },
  teach: { from: 75, dur: 300 },
  ai: { from: 375, dur: 300 },
  record: { from: 675, dur: 180 },
  close: { from: 855, dur: 135 },
} as const;

export const DURATION =
  SHOTS.close.from + SHOTS.close.dur;
