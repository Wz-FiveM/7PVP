import { useEffect, useState } from 'react';
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
          EN JEU {pad(state.clock.hour)}:{pad(state.clock.minute)}
          {state.clock.night && ' · NUIT'}
        </span>
      )}
      {player.streak > 0 && (
        <span className="mono status__streak">
          SÉRIE ×{player.streak}
          {player.bounty > 0 && <span className="status__bounty"> · PRIME {formatMoney(player.bounty)}</span>}
        </span>
      )}
      <div className="status__level">
        <span className="disp">Niv. {player.level}</span>
        <span className="status__xp">
          <span style={{ width: `${progress}%` }} />
        </span>
      </div>
    </div>
  );
}
