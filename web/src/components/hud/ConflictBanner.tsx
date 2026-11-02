import { useEffect, useState } from 'react';
import { useT } from '../../i18n';
import { useGame } from '../../store/GameContext';
import { CodStreakIcon } from '../cod/CodStreakIcon';
import { ColoredName } from '../ui/ColoredName';

/** Zone de conflit où se trouve le joueur, en bas au milieu : kill leader, ses kills et le compteur. */
export function ConflictBanner() {
  const t = useT();
  const { state } = useGame();
  const [, setTick] = useState(0);
  const conflict = state.conflict;

  useEffect(() => {
    if (!conflict) return undefined;
    const timer = window.setInterval(() => setTick((tick) => tick + 1), 500);
    return () => window.clearInterval(timer);
  }, [conflict]);

  if (!conflict) return null;
  const seconds = Math.max(0, Math.ceil((conflict.endsAt - Date.now()) / 1000));
  const time = `${Math.floor(seconds / 60)}:${String(seconds % 60).padStart(2, '0')}`;
  const { leader } = conflict;

  return (
    <div className={state.hotbarVisible ? 'conflict-banner conflict-banner--raised' : 'conflict-banner'}>
      <div className="conflict-banner__row">
        <span className="mono conflict-banner__tag">{t('KILL LEADER')}</span>
        <span className="mono conflict-banner__time">{time}</span>
      </div>
      <div className="conflict-banner__row">
        <span className="disp conflict-banner__name">
          {leader ? <ColoredName text={leader.name} colors={leader.colors} /> : t('Aucun')}
        </span>
        <span className="conflict-banner__score">
          <CodStreakIcon id="skull" />
          <span className="disp conflict-banner__kills">{leader ? leader.kills : 0}</span>
        </span>
      </div>
    </div>
  );
}
