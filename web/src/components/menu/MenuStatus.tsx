import { useT } from '../../i18n';
import { useGame } from '../../store/GameContext';
import { formatMoney, formatPoints } from '../../utils/format';
import { DEFAULT_MENU_KEY } from '../../utils/keys';
import { Icon } from '../icons/Icon';
import { ZoneChip } from '../ui/ZoneChip';

/** Zone, argent, niveau, retour au lobby et fermeture, en haut à droite du menu. */
export function MenuStatus() {
  const t = useT();
  const { state, actions } = useGame();
  const { player, zone, config } = state;
  const progress = player ? ((player.xp % config.xpPerLevel) / config.xpPerLevel) * 100 : 0;

  return (
    <div className="menu-status">
      <ZoneChip zone={zone} detailed />
      {player && (
        <>
          <span className="mono menu-status__money">{formatMoney(player.money)}</span>
          <span className="mono menu-status__points" title={t(config.shopPoints?.label ?? 'Points boutique')}>
            <Icon name="gem" size={16} strokeWidth={2} />
            {formatPoints(player.shopPoints ?? 0)}
          </span>
          <span className="menu-status__level">
            <span className="disp">{t('Niv. {level}', { level: player.level })}</span>
            <span className="menu-status__xp">
              <span style={{ width: `${progress}%` }} />
            </span>
          </span>
        </>
      )}
      <button className="btn btn--small" onClick={actions.leaveToLobby}>
        <Icon name="exit" size={14} strokeWidth={2} />
        {t('Lobby')}
      </button>
      <button className="menu-status__close" onClick={actions.closeMenu} aria-label={t('Fermer le menu')}>
        <span className="mono keycap--solid">{config.menuKey ?? DEFAULT_MENU_KEY}</span>
        <span className="label">{t('Fermer')}</span>
      </button>
    </div>
  );
}
