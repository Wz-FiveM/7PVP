import { useEffect, useState } from 'react';
import { useT } from '../i18n';
import { Logo } from '../components/ui/Logo';
import { Briefing } from './Briefing';
import { TacticalMap } from './TacticalMap';
import { TIPS } from './tips';
import { useEased, useLoadProgress } from './useLoadProgress';

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

/** En dev (npm run dev), un joueur fictif pour voir l'écran complet */
const DEV_HANDOVER: Handover = import.meta.env.DEV ? { name: 'Soldat', players: 12, maxPlayers: 48 } : {};

export function LoadingScreen() {
  const t = useT();
  const progress = useLoadProgress();
  const fraction = useEased(progress.fraction);
  const handover = (window as { nuiHandoverData?: Handover }).nuiHandoverData ?? DEV_HANDOVER;
  const [tipIndex, setTipIndex] = useState(() => Math.floor(Math.random() * TIPS.length));
  const percent = Math.round(fraction * 100);

  useEffect(() => {
    const timer = window.setInterval(() => setTipIndex((i) => (i + 1) % TIPS.length), TIP_DURATION);
    return () => window.clearInterval(timer);
  }, []);

  return (
    <div className="loading">
      <TacticalMap fraction={fraction} />
      <div className="loading__grade" />

      <header className="loading__top">
        <Logo size={150} />
        {handover.players !== undefined && (
          <span className="loading__online">
            {t('{players}/{max} EN LIGNE', { players: handover.players, max: handover.maxPlayers ?? '?' })}
          </span>
        )}
      </header>

      <div className="loading__bottom">
        <Briefing name={handover.name} />

        <div className="loading__status">
          <h1 key={progress.step} className="loading__step">{t(progress.step)}</h1>
          <span className="loading__percent">{percent}<small>%</small></span>
        </div>

        <section className="loading__tip">
          <span className="loading__tip-label">[ {t('Astuce')} ]</span>
          <p key={tipIndex} className="loading__tip-text">{t(TIPS[tipIndex])}</p>
        </section>

        <span className="loading__track"><span style={{ width: `${fraction * 100}%` }} /></span>

        <footer className="loading__footer">
          <span className="loading__log">{progress.log}</span>
          <ul className="loading__keys">
            {KEYS.map(([key, label]) => (
              <li key={key}>
                <kbd>[ {key} ]</kbd> {t(label)}
              </li>
            ))}
          </ul>
        </footer>
      </div>
    </div>
  );
}
