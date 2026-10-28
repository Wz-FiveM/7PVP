import { useGame } from '../../store/GameContext';
import { formatMoney } from '../../utils/format';
import { DEFAULT_MENU_KEY } from '../../utils/keys';
import { Icon } from '../icons/Icon';
import { ZoneChip } from '../ui/ZoneChip';

/** Zone, argent, niveau, retour au lobby et fermeture, en haut à droite du menu. */
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
      <button className="btn btn--small" onClick={actions.leaveToLobby}>
        <Icon name="exit" size={14} strokeWidth={2} />
        Lobby
      </button>
      <button className="menu-status__close" onClick={actions.closeMenu} aria-label="Fermer le menu">
        <span className="mono keycap--solid">{config.menuKey ?? DEFAULT_MENU_KEY}</span>
        <span className="label">Fermer</span>
      </button>
    </div>
  );
}
