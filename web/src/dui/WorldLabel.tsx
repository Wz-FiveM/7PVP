import { useEffect, useState } from 'react';
import { Icon, type IconName } from '../components/icons/Icon';

/** Contenu envoyé par Lua avec SendDuiMessage */
export interface WorldLabelData {
  title: string;
  subtitle?: string;
  /** couleur de la D.A : hazard (orange), abri (bleu), toxine (vert), critique (jaune) */
  accent?: 'hazard' | 'abri' | 'toxine' | 'critique';
  icon?: IconName;
  /** 0 à 1 : barre de progression (ex : ouverture d'un largage) */
  progress?: number;
}

/** Exemple affiché dans le navigateur (npm run dev), hors du jeu */
const PREVIEW: WorldLabelData = {
  title: 'Largage aérien',
  subtitle: 'Ouverture dans 48 s',
  accent: 'critique',
  icon: 'crate',
  progress: 0.2,
};

const isBrowser = !('invokeNative' in window);

/** Étiquette 3D (largage, PNJ de la zone safe...) dans le style Frontline. */
export function WorldLabel() {
  const [data, setData] = useState<WorldLabelData | null>(isBrowser ? PREVIEW : null);

  useEffect(() => {
    const onMessage = (event: MessageEvent) => {
      const payload = typeof event.data === 'string' ? safeParse(event.data) : event.data;
      if (payload && typeof payload.title === 'string') setData(payload as WorldLabelData);
    };
    window.addEventListener('message', onMessage);
    return () => window.removeEventListener('message', onMessage);
  }, []);

  if (!data) return null;
  const accent = data.accent ?? 'hazard';

  return (
    <div className={`world-label world-label--${accent} cut`}>
      {data.icon && (
        <span className="world-label__icon cut-s">
          <Icon name={data.icon} size={34} strokeWidth={2} />
        </span>
      )}
      <span className="world-label__text">
        <span className="disp world-label__title">{data.title}</span>
        {data.subtitle && <span className="world-label__subtitle">{data.subtitle}</span>}
        {data.progress !== undefined && (
          <span className="world-label__bar">
            <span style={{ width: `${Math.round(Math.min(1, Math.max(0, data.progress)) * 100)}%` }} />
          </span>
        )}
      </span>
    </div>
  );
}

function safeParse(text: string): unknown {
  try {
    return JSON.parse(text);
  } catch {
    return null;
  }
}
