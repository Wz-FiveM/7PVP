import type { CSSProperties } from 'react';
import { useT } from '../../i18n';
import { useGame } from '../../store/GameContext';
import type { MinimapAnchor } from '../../types/game';
import { capacityOf, weightOf } from '../../utils/inventory';
import { SegmentBar } from '../ui/SegmentBar';

/**
 * Collé à droite de la minimap GTA, aligné sur son bas.
 * Sans minimap (masquée ou position inconnue), le CSS le place en bas à gauche.
 */
function besideMinimap(minimap: MinimapAnchor | null): CSSProperties | undefined {
  if (!minimap?.visible) return undefined;
  return {
    left: `calc(${minimap.right * 100}% + 0.75rem)`,
    bottom: `${(1 - minimap.bottom) * 100}%`,
  };
}

/** En dessous de cette part de la santé, le chiffre et la barre passent en hazard */
const LOW_HEALTH = 0.25;

/** Santé en grand chiffre, armure et santé soudées l'une sur l'autre, poids du sac. */
export function Vitals() {
  const t = useT();
  const { state } = useGame();
  const { vitals, player, config, minimap } = state;
  const bagWeight = player ? weightOf(player.inventory.bag, config) : 0;
  const low = vitals.health <= vitals.maxHealth * LOW_HEALTH;

  return (
    <div className={low ? 'vitals vitals--low' : 'vitals'} style={besideMinimap(minimap)}>
      <span className="disp vitals__health">{vitals.health}</span>
      <div className="vitals__bars">
        <div className="vitals__head">
          <span className="mono vitals__weight">
            {t('SAC {weight} / {capacity} KG', { weight: bagWeight.toFixed(1), capacity: capacityOf(config, player, 'bag').toFixed(1) })}
          </span>
          <span className="disp vitals__armor">{vitals.armor} {t('Armure')}</span>
        </div>
        <SegmentBar value={vitals.armor} max={100} segments={10} color="var(--armure)" height={5} />
        <SegmentBar value={vitals.health} max={vitals.maxHealth} segments={10} color={low ? 'var(--hazard)' : undefined} height={13} />
      </div>
    </div>
  );
}
