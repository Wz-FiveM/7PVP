import { useEffect, useRef, useState, type FormEvent } from 'react';
import { useT } from '../../i18n';

interface QuantityModalProps {
  title: string;
  max: number;
  confirmLabel: string;
  onConfirm: (count: number) => void;
  onCancel: () => void;
}

export function QuantityModal({ title, max, confirmLabel, onConfirm, onCancel }: QuantityModalProps) {
  const t = useT();
  const [count, setCount] = useState(max);
  const inputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    inputRef.current?.select();
  }, []);

  // Échap ferme la fenêtre sans fermer tout le menu (écouteur en phase de capture)
  useEffect(() => {
    const onKeyDown = (event: KeyboardEvent) => {
      if (event.key !== 'Escape') return;
      event.preventDefault();
      onCancel();
    };
    window.addEventListener('keydown', onKeyDown, true);
    return () => window.removeEventListener('keydown', onKeyDown, true);
  }, [onCancel]);

  const clamp = (value: number) => Math.min(max, Math.max(1, Math.floor(value) || 1));

  const handleSubmit = (event: FormEvent) => {
    event.preventDefault();
    onConfirm(clamp(count));
  };

  return (
    <div className="modal-backdrop" onMouseDown={onCancel}>
      <form className="modal cut" onSubmit={handleSubmit} onMouseDown={(event) => event.stopPropagation()}>
        <h2 className="modal__title">{title}</h2>
        <input
          type="range"
          min={1}
          max={max}
          value={count}
          onChange={(event) => setCount(clamp(Number(event.target.value)))}
        />
        <div className="modal__row">
          {/* Champ numérique avec nos propres boutons − / + (les flèches natives sont masquées) */}
          <div className="qty">
            <button
              type="button"
              className="qty__btn"
              onClick={() => setCount(clamp(count - 1))}
              disabled={count <= 1}
              aria-label={t('Diminuer')}
            >
              −
            </button>
            <input
              ref={inputRef}
              className="qty__input mono"
              type="number"
              min={1}
              max={max}
              value={count}
              onChange={(event) => setCount(Number(event.target.value))}
              onBlur={() => setCount(clamp(count))}
            />
            <button
              type="button"
              className="qty__btn"
              onClick={() => setCount(clamp(count + 1))}
              disabled={count >= max}
              aria-label={t('Augmenter')}
            >
              +
            </button>
          </div>
          <span className="modal__max">/ {max}</span>
          <button type="button" className="btn btn--small cut-s" onClick={() => setCount(max)}>
            {t('Tout')}
          </button>
        </div>
        <div className="modal__actions">
          <button type="button" className="btn cut-s" onClick={onCancel}>
            {t('Annuler')}
          </button>
          <button type="submit" className="btn btn--primary cut-s">
            {confirmLabel}
          </button>
        </div>
      </form>
    </div>
  );
}
