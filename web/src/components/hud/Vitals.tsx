import type { CSSProperties } from 'react';
import { useGame } from '../../store/GameContext';
import type { MinimapAnchor } from '../../types/game';
import { weightOf } from '../../utils/inventory';
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

/** Santé, armure et poids du sac. */
export function Vitals() {
  const { state } = useGame();
  const { vitals, player, config, minimap } = state;
  const bagWeight = player ? weightOf(player.inventory.bag, config) : 0;

  return (
    <div className="vitals" style={besideMinimap(minimap)}>
      <div className="vital">
        <div className="vital__row">
          <span className="disp vital__label">Santé</span>
          <span className="mono">{vitals.health}</span>
        </div>
        <SegmentBar value={vitals.health} max={vitals.maxHealth} segments={10} height={6} />
      </div>
      <div className="vital">
        <div className="vital__row">
          <span className="disp vital__label">Armure</span>
          <span className="mono">{vitals.armor}</span>
        </div>
        <SegmentBar value={vitals.armor} max={100} segments={10} color="var(--brume)" height={6} />
      </div>
      <span className="mono muted vitals__weight">
        SAC {bagWeight.toFixed(1)} / {config.containers.bag.capacity.toFixed(1)} KG
      </span>
    </div>
  );
}
