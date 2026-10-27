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
    <div className="status cut">
      <span className="mono status__money">{formatMoney(bagMoney)}</span>
      <span className="label">Dans le sac</span>
      <div className="status__level">
        <span className="disp">Niv. {player.level}</span>
        <span className="status__xp">
          <span style={{ width: `${progress}%` }} />
        </span>
      </div>
    </div>
  );
}
