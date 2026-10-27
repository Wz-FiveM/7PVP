import type { OverlayValue, Rgb, SchemaEntry } from '../../../types/appearance';
import { Slider } from './Slider';
import { Stepper } from './Stepper';
import { Swatches } from './Swatches';

interface OverlayControlProps {
  entry: SchemaEntry;
  value: OverlayValue;
  count: number;
  /** Couleurs proposées si le calque en a (cheveux ou maquillage) */
  colors?: Rgb[];
  onChange: (value: OverlayValue) => void;
}

/** Calque de la tête : style (ou aucun), intensité, couleur. */
export function OverlayControl({ entry, value, count, colors, onChange }: OverlayControlProps) {
  const active = value.style >= 0;

  return (
    <div className="ctl-group">
      <Stepper
        label={entry.label}
        value={value.style}
        count={count}
        allowNone
        onChange={(style) => onChange({ ...value, style })}
      />
      {active && (
        <Slider
          label="Intensité"
          value={value.opacity}
          min={0}
          max={1}
          format={(v) => `${Math.round(v * 100)}%`}
          onChange={(opacity) => onChange({ ...value, opacity })}
        />
      )}
      {active && colors && (
        <Swatches label="Couleur" colors={colors} value={value.color} onChange={(color) => onChange({ ...value, color })} />
      )}
    </div>
  );
}
