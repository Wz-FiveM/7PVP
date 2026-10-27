import type { CSSProperties } from 'react';

interface SliderProps {
  label: string;
  value: number;
  min: number;
  max: number;
  step?: number;
  /** Libellés aux deux extrémités (ex : Mère / Père) */
  ends?: [string, string];
  format?: (value: number) => string;
  onChange: (value: number) => void;
}

export function Slider({ label, value, min, max, step = 0.01, ends, format, onChange }: SliderProps) {
  const progress = ((value - min) / (max - min)) * 100;

  return (
    <label className="ctl">
      <span className="ctl__row">
        <span className="ctl__label">{label}</span>
        <span className="mono ctl__value">{format ? format(value) : value.toFixed(2)}</span>
      </span>
      <input
        className="slider"
        type="range"
        min={min}
        max={max}
        step={step}
        value={value}
        style={{ '--progress': `${progress}%` } as CSSProperties}
        onChange={(event) => onChange(Number(event.target.value))}
      />
      {ends && (
        <span className="ctl__ends mono">
          <span>{ends[0]}</span>
          <span>{ends[1]}</span>
        </span>
      )}
    </label>
  );
}
