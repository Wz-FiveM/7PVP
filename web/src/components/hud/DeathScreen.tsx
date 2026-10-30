import { useCountdown } from '../../hooks/useCountdown';
import { useT } from '../../i18n';
import { useGame } from '../../store/GameContext';
import type { DamageSummary, DeathRecap } from '../../types/game';

/** Écran de mort : compte à rebours en haut, caméra sur le tueur au centre, récapitulatif en bas. */
export function DeathScreen() {
  const t = useT();
  const { state } = useGame();
  const remaining = useCountdown(state.death.seconds, state.death.key);
  const recap = state.death.recap;

  return (
    <div className="death">
      <div className="death__stripes" />
      <div className="death__head">
        <span className="mono death__tag">// {t('SIGNAL PERDU')}</span>
        <h1 className="disp death__title">{t('Éliminé')}</h1>
        <p className="death__text">{t('Le contenu de ton sac est resté sur place. Ton conteneur protégé te suit.')}</p>
        <span className="mono death__timer">{t('RÉAPPARITION DANS {seconds} S', { seconds: String(remaining).padStart(2, '0') })}</span>
      </div>
      <DeathRecapPanel recap={recap} />
    </div>
  );
}

function DeathRecapPanel({ recap }: { recap: DeathRecap }) {
  const t = useT();
  if (!recap.killer) {
    const cause = recap.zombie
      ? t('Dévoré par un zombie')
      : recap.weapon ? t('Cause : {weapon}', { weapon: t(recap.weapon) }) : t('Mort sans tueur identifié');
    return (
      <div className="death__recap">
        <span className="disp death__killer">{cause}</span>
      </div>
    );
  }

  return (
    <div className="death__recap">
      <span className="disp death__killer">
        {t('Tué par')} <span>{recap.killer}</span>
      </span>
      <div className="death__facts mono">
        {recap.weapon && <span>{t('ARME : {weapon}', { weapon: t(recap.weapon).toUpperCase() })}</span>}
        {recap.distance !== undefined && <span>{t('DISTANCE : {distance} M', { distance: recap.distance })}</span>}
      </div>
      <div className="death__stats">
        <RecapStat label={t('Il t\'a infligé')} summary={recap.taken} className="death__stat--taken" />
        <RecapStat label={t('Tu lui as infligé')} summary={recap.dealt} className="death__stat--dealt" />
        <div className="death__stat cut-s">
          <span className="label">{t('Il lui restait')}</span>
          <span className="mono death__stat-value">{t('{health} PV', { health: recap.killerHealth ?? '?' })}</span>
          <span className="mono death__stat-detail">{t('ARMURE {armor}', { armor: recap.killerArmor ?? 0 })}</span>
        </div>
      </div>
    </div>
  );
}

function RecapStat({ label, summary, className }: { label: string; summary?: DamageSummary; className: string }) {
  const t = useT();
  const value = summary ?? { damage: 0, hits: 0, headshots: 0 };
  return (
    <div className={`death__stat cut-s ${className}`}>
      <span className="label">{label}</span>
      <span className="mono death__stat-value">{value.damage}</span>
      <span className="mono death__stat-detail">
        {t('{hits} TOUCHE(S) · {headshots} À LA TÊTE', { hits: value.hits, headshots: value.headshots })}
      </span>
    </div>
  );
}
