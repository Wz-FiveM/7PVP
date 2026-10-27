import type { Rgb } from '../../../types/appearance';

interface SwatchesProps {
  label: string;
  colors: Rgb[];
  value: number;
  onChange: (index: number) => void;
}

/** Nuancier des couleurs du jeu (cheveux ou maquillage). */
export function Swatches({ label, colors, value, onChange }: SwatchesProps) {
  return (
    <div className="ctl">
      <span className="ctl__row">
        <span className="ctl__label">{label}</span>
        <span className="mono ctl__value">{value + 1}</span>
      </span>
      <div className="swatches" role="radiogroup" aria-label={label}>
        {colors.map(([r, g, b], i) => (
          <button
            key={i}
            role="radio"
            aria-checked={i === value}
            aria-label={`${label} ${i + 1}`}
            className={i === value ? 'swatch swatch--active' : 'swatch'}
            style={{ background: `rgb(${r}, ${g}, ${b})` }}
            onClick={() => onChange(i)}
          />
        ))}
      </div>
    </div>
  );
}
