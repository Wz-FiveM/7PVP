import { useT } from '../../../i18n';

interface StepperProps {
  label: string;
  /** Index courant */
  value: number;
  /** Nombre de choix (les index vont de 0 à count - 1) */
  count: number;
  /** Ajoute un choix « Aucun » (valeur -1) avant le premier */
  allowNone?: boolean;
  /** Libellé affiché pour une valeur (par défaut : numéro / total) */
  format?: (value: number) => string;
  onChange: (value: number) => void;
}

/** Sélecteur ‹ valeur › qui boucle sur les choix disponibles. */
export function Stepper({ label, value, count, allowNone, format, onChange }: StepperProps) {
  const t = useT();
  const min = allowNone ? -1 : 0;
  const max = Math.max(min, count - 1);
  const disabled = max === min && !allowNone;

  const step = (delta: number) => {
    let next = value + delta;
    if (next > max) next = min;
    if (next < min) next = max;
    onChange(next);
  };

  const display = value < 0 ? t('Aucun') : format ? format(value) : `${value + 1} / ${Math.max(count, 1)}`;

  return (
    <div className="ctl">
      <span className="ctl__label">{label}</span>
      <div className="stepper">
        <button className="stepper__btn" onClick={() => step(-1)} disabled={disabled} aria-label={t('{label} précédent', { label })}>
          ‹
        </button>
        <span className="mono stepper__value">{display}</span>
        <button className="stepper__btn" onClick={() => step(1)} disabled={disabled} aria-label={t('{label} suivant', { label })}>
          ›
        </button>
      </div>
    </div>
  );
}
