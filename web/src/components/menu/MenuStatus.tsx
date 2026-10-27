import { useGame } from '../../store/GameContext';
import { formatMoney } from '../../utils/format';
import { ZoneChip } from '../ui/ZoneChip';

/** Zone, argent et niveau, en haut à droite du menu. */
export function MenuStatus() {
  const { state, actions } = useGame();
  const { player, zone, config } = state;
  const progress = player ? ((player.xp % config.xpPerLevel) / config.xpPerLevel) * 100 : 0;

  return (
    <div className="menu-status">
      <ZoneChip zone={zone} detailed />
      {player && (
        <>
          <span className="mono menu-status__money">{formatMoney(player.money)}</span>
          <span className="menu-status__level">
            <span className="disp">Niv. {player.level}</span>
            <span className="menu-status__xp">
              <span style={{ width: `${progress}%` }} />
            </span>
          </span>
        </>
      )}
      <button className="btn btn--small mono cut-s" onClick={actions.closeMenu} aria-label="Fermer le menu">
        [ÉCHAP]
      </button>
    </div>
  );
}
