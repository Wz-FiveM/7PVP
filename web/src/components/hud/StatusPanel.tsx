import { useEffect, useState } from 'react';
import { useT } from '../../i18n';
import { useGame } from '../../store/GameContext';
import { formatMoney } from '../../utils/format';

const pad = (value: number) => String(value).padStart(2, '0');

/** Heure réelle (celle du joueur), mise à jour chaque seconde. */
function useRealTime(): Date {
  const [now, setNow] = useState(() => new Date());
  useEffect(() => {
    const timer = window.setInterval(() => setNow(new Date()), 1000);
    return () => window.clearInterval(timer);
  }, []);
  return now;
}

/** Heure réelle, heure du jeu et niveau, en haut à droite. */
export function StatusPanel() {
  const t = useT();
  const { state } = useGame();
  const { player, config } = state;
  const now = useRealTime();
  if (!player) return null;

  const progress = ((player.xp % config.xpPerLevel) / config.xpPerLevel) * 100;

  return (
    <div className="status">
      <span className="mono status__time">
        {pad(now.getHours())}:{pad(now.getMinutes())}
      </span>
      {state.clock && (
        <span className={state.clock.night ? 'mono status__clock status__clock--night' : 'mono status__clock'}>
          {t('EN JEU {time}', { time: `${pad(state.clock.hour)}:${pad(state.clock.minute)}` })}
          {state.clock.night && ` · ${t('NUIT')}`}
        </span>
      )}
      {player.streak > 0 && (
        <span className="mono status__streak">
          {t('SÉRIE ×{streak}', { streak: player.streak })}
          {player.bounty > 0 && <span className="status__bounty"> · {t('PRIME {amount}', { amount: formatMoney(player.bounty) })}</span>}
        </span>
      )}
      <div className="status__level">
        <span className="disp">{t('Niv. {level}', { level: player.level })}</span>
        <span className="status__xp">
          <span style={{ width: `${progress}%` }} />
        </span>
      </div>
    </div>
  );
}
