import { useT } from '../../i18n';
import { useGame } from '../../store/GameContext';
import './freeroam.css';

/** Badge du Freeroam en jeu : mode de jeu en cours (Freeroam libre, CVC, 1VS1...). */
export function FreeroamHud() {
  const t = useT();
  const { state } = useGame();
  const { activity, pvp } = state.freeroam;
  return (
    <div className="freeroam-hud">
      <span className="disp freeroam-hud__title">{activity ? t(activity.label) : 'Freeroam'}</span>
      <span className="mono freeroam-hud__info">{activity ? t(activity.tagline).toUpperCase() : t('MODE LIBRE')}</span>
      {/* Hors mode de jeu : on peut prendre des balles uniquement si le PvP est activé */}
      {!activity && pvp && <span className="mono freeroam-hud__pvp">{t('PVP ACTIVÉ')}</span>}
    </div>
  );
}
