import { useT } from '../../../i18n';
import type { DrawableLimit, DrawableValue } from '../../../types/appearance';
import { Stepper } from './Stepper';

interface DrawableControlProps {
  label: string;
  value: DrawableValue;
  limit: DrawableLimit;
  /** Accessoires : le modèle peut être retiré (-1) */
  allowNone?: boolean;
  onChange: (value: DrawableValue) => void;
}

/** Vêtement ou accessoire : modèle puis variante (texture). */
export function DrawableControl({ label, value, limit, allowNone, onChange }: DrawableControlProps) {
  const t = useT();
  return (
    <div className="ctl-group">
      <Stepper
        label={label}
        value={value.drawable}
        count={limit.drawables}
        allowNone={allowNone}
        // Changer de modèle remet la variante à zéro : chaque modèle a ses propres variantes
        onChange={(drawable) => onChange({ drawable, texture: 0 })}
      />
      {value.drawable >= 0 && limit.textures > 1 && (
        <Stepper
          label={t('Variante')}
          value={value.texture}
          count={limit.textures}
          onChange={(texture) => onChange({ ...value, texture })}
        />
      )}
    </div>
  );
}
