import { useCountdown } from '../../hooks/useCountdown';
import { useGame } from '../../store/GameContext';
import type { DamageSummary, DeathRecap } from '../../types/game';

/** Écran de mort : compte à rebours en haut, caméra sur le tueur au centre, récapitulatif en bas. */
export function DeathScreen() {
  const { state } = useGame();
  const remaining = useCountdown(state.death.seconds, state.death.key);
  const recap = state.death.recap;

  return (
    <div className="death">
      <div className="death__stripes" />
      <div className="death__head">
        <span className="mono death__tag">// SIGNAL PERDU</span>
        <h1 className="disp death__title">Éliminé</h1>
        <p className="death__text">Le contenu de ton sac est resté sur place. Ton conteneur protégé te suit.</p>
        <span className="mono death__timer">RÉAPPARITION DANS {String(remaining).padStart(2, '0')} S</span>
      </div>
      <DeathRecapPanel recap={recap} />
    </div>
  );
}

function DeathRecapPanel({ recap }: { recap: DeathRecap }) {
  if (!recap.killer) {
    const cause = recap.zombie ? 'Dévoré par un zombie' : recap.weapon ? `Cause : ${recap.weapon}` : 'Mort sans tueur identifié';
    return (
      <div className="death__recap">
        <span className="disp death__killer">{cause}</span>
      </div>
    );
  }

  return (
    <div className="death__recap">
      <span className="disp death__killer">
        Tué par <span>{recap.killer}</span>
      </span>
      <div className="death__facts mono">
        {recap.weapon && <span>ARME : {recap.weapon.toUpperCase()}</span>}
        {recap.distance !== undefined && <span>DISTANCE : {recap.distance} M</span>}
      </div>
      <div className="death__stats">
        <RecapStat label="Il t'a infligé" summary={recap.taken} className="death__stat--taken" />
        <RecapStat label="Tu lui as infligé" summary={recap.dealt} className="death__stat--dealt" />
        <div className="death__stat cut-s">
          <span className="label">Il lui restait</span>
          <span className="mono death__stat-value">{recap.killerHealth ?? '?'} PV</span>
          <span className="mono death__stat-detail">ARMURE {recap.killerArmor ?? 0}</span>
        </div>
      </div>
    </div>
  );
}

function RecapStat({ label, summary, className }: { label: string; summary?: DamageSummary; className: string }) {
  const value = summary ?? { damage: 0, hits: 0, headshots: 0 };
  return (
    <div className={`death__stat cut-s ${className}`}>
      <span className="label">{label}</span>
      <span className="mono death__stat-value">{value.damage}</span>
      <span className="mono death__stat-detail">
        {value.hits} TOUCHE(S) · {value.headshots} À LA TÊTE
      </span>
    </div>
  );
}
