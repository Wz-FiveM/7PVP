import { useT } from '../../i18n';
import { useGame } from '../../store/GameContext';
import { DEFAULT_MENU_KEY } from '../../utils/keys';
import './freeroam.css';

/** Badge du Freeroam en jeu : mode, état du PvP et touche du menu. */
export function FreeroamHud() {
  const t = useT();
  const { state } = useGame();
  return (
    <div className="freeroam-hud">
      <span className="disp freeroam-hud__title">Freeroam</span>
      <span className={state.freeroam.pvp ? 'mono freeroam-hud__pvp freeroam-hud__pvp--on' : 'mono freeroam-hud__pvp'}>
        {state.freeroam.pvp ? t('PVP ACTIVÉ') : t('PVP DÉSACTIVÉ')}
      </span>
      <span className="mono freeroam-hud__hint">
        {t('{key} : ARMES, VÉHICULES, PVP', { key: state.config.menuKey ?? DEFAULT_MENU_KEY })}
      </span>
    </div>
  );
}
