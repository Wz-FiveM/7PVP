import { useGame } from '../../store/GameContext';
import { entriesOf } from '../../utils/inventory';
import { formatMoney } from '../../utils/format';

/** Argent porté (sac) et niveau, en haut à droite. */
export function StatusPanel() {
  const { state } = useGame();
  const { player, config } = state;
  if (!player) return null;

  // En jeu, on affiche l'argent à risque : celui du sac
  const bagMoney = entriesOf(player.inventory.bag).find(([name]) => name === 'money')?.[1] ?? 0;
  const progress = ((player.xp % config.xpPerLevel) / config.xpPerLevel) * 100;

  return (
    <div className="status">
      <span className="mono status__money">{formatMoney(bagMoney)}</span>
      <span className="label">Dans le sac</span>
      {state.clock && (
        <span className={state.clock.night ? 'mono status__clock status__clock--night' : 'mono status__clock'}>
          {String(state.clock.hour).padStart(2, '0')}:{String(state.clock.minute).padStart(2, '0')}
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
