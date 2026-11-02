import { useEffect, useState } from 'react';
import { useT } from '../../i18n';
import { useGame } from '../../store/GameContext';
import { ColoredName } from '../ui/ColoredName';

/** Zone de conflit où se trouve le joueur, en bas au milieu : team leader, ses kills et le compteur. */
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
      <div className="conflict-banner__head">
        <span className="disp conflict-banner__label">{t(conflict.label)}</span>
        <span className="mono conflict-banner__time">{time}</span>
      </div>
      {leader ? (
        <div className="conflict-banner__leader">
          <span className="mono conflict-banner__tag">{t('TEAM LEADER')}</span>
          <span className="conflict-banner__name">
            <ColoredName text={leader.name} colors={leader.colors} />
          </span>
          <span className="mono conflict-banner__kills">
            {leader.kills > 1 ? t('{kills} KILLS', { kills: leader.kills }) : t('{kills} KILL', { kills: leader.kills })}
          </span>
        </div>
      ) : (
        <div className="conflict-banner__leader">
          <span className="mono conflict-banner__tag">{t('TEAM LEADER')}</span>
          <span className="conflict-banner__empty">{t('Aucun kill pour l\'instant')}</span>
        </div>
      )}
      {leader && (
        <span className="mono conflict-banner__mine">
          {conflict.leading ? t('Tu es en tête') : t('Tes kills : {kills}', { kills: conflict.kills })}
        </span>
      )}
    </div>
  );
}
