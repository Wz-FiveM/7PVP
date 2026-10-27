import type { CSSProperties } from 'react';
import { rem } from '../../utils/scale';

interface SegmentBarProps {
  value: number;
  max: number;
  segments?: number;
  /** Couleur des segments pleins (variable CSS ou couleur) */
  color?: string;
  /** Les derniers segments passent en hazard à partir de ce ratio (ex : sac presque plein) */
  warnFrom?: number;
  /** Hauteur des segments en px à 1080p */
  height?: number;
}

/** Jauge découpée en segments (poids, santé, armure). */
export function SegmentBar({ value, max, segments = 20, color, warnFrom, height }: SegmentBarProps) {
  const ratio = max > 0 ? Math.min(1, value / max) : 0;
  const filled = Math.round(ratio * segments);
  const warnStart = warnFrom !== undefined ? Math.round(warnFrom * segments) : segments;

  const style = {
    gridTemplateColumns: `repeat(${segments}, minmax(0, 1fr))`,
    '--segment-color': color,
  } as CSSProperties;

  return (
    <div className="segments" style={style} role="meter" aria-valuenow={value} aria-valuemin={0} aria-valuemax={max}>
      {Array.from({ length: segments }, (_, i) => {
        let className = 'segments__cell';
        if (i < filled) className += ' segments__cell--on';
        else if (i >= warnStart) className += ' segments__cell--warn';
        return <span key={i} className={className} style={height ? { height: rem(height) } : undefined} />;
      })}
    </div>
  );
}
