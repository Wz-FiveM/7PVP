import { useEffect, useState } from 'react';
import { useT } from '../i18n';
import { Logo } from '../components/ui/Logo';
import { SegmentBar } from '../components/ui/SegmentBar';
import { TIPS } from './tips';
import { useLoadProgress } from './useLoadProgress';

/** Infos envoyées par le serveur à la connexion (server/modules/connection) */
interface Handover {
  name?: string;
  players?: number;
  maxPlayers?: number;
}

const TIP_DURATION = 7000;

const KEYS: [string, string][] = [
  ['TAB', 'Inventaire'],
  ['1 – 7', 'Raccourcis'],
  ['T', 'Chat'],
  ['E', 'Ramasser'],
];

export function LoadingScreen() {
  const t = useT();
  const progress = useLoadProgress();
  const handover = (window as { nuiHandoverData?: Handover }).nuiHandoverData ?? {};
  const [tipIndex, setTipIndex] = useState(() => Math.floor(Math.random() * TIPS.length));
  const percent = Math.round(progress.fraction * 100);

  useEffect(() => {
    const timer = window.setInterval(() => setTipIndex((i) => (i + 1) % TIPS.length), TIP_DURATION);
    return () => window.clearInterval(timer);
  }, []);

  return (
    <div className="loading">
      <div className="loading__stripes" />

      <main className="loading__center">
        <Logo size={260} />
        <p className="mono loading__welcome">
          {handover.name ? t('BIENVENUE, {name}', { name: handover.name.toUpperCase() }) : t('CONNEXION AU SERVEUR')}
          {handover.players !== undefined && (
            <span className="loading__players">
              {' '}· {t('{players}/{max} EN LIGNE', { players: handover.players, max: handover.maxPlayers ?? '?' })}
            </span>
          )}
        </p>
      </main>

      <section className="loading__tip cut">
        <span className="label loading__tip-label">{t('Astuce')}</span>
        <p key={tipIndex} className="loading__tip-text">{t(TIPS[tipIndex])}</p>
      </section>

      <footer className="loading__footer">
        <div className="loading__progress">
          <div className="loading__progress-row">
            <span className="disp loading__step">{t(progress.step)}</span>
            <span className="mono loading__percent">{percent}%</span>
          </div>
          <SegmentBar value={progress.fraction} max={1} segments={40} color="var(--signal)" height={6} />
          <span className="mono loading__log">{progress.log}</span>
        </div>
        <ul className="loading__keys">
          {KEYS.map(([key, label]) => (
            <li key={key}>
              <kbd className="keycap">[{key}]</kbd> {t(label)}
            </li>
          ))}
        </ul>
      </footer>
    </div>
  );
}
