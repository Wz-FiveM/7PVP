import { useGame } from '../../store/GameContext';
import { weightOf } from '../../utils/inventory';
import { SegmentBar } from '../ui/SegmentBar';

/** Santé, armure et poids du sac, en bas à gauche. */
export function Vitals() {
  const { state } = useGame();
  const { vitals, player, config } = state;
  const bagWeight = player ? weightOf(player.inventory.bag, config) : 0;

  return (
    <div className="vitals">
      <div className="vital">
        <div className="vital__row">
          <span className="disp vital__label">Santé</span>
          <span className="mono">{vitals.health}</span>
        </div>
        <SegmentBar value={vitals.health} max={vitals.maxHealth} segments={10} height={8} />
      </div>
      <div className="vital">
        <div className="vital__row">
          <span className="disp vital__label">Armure</span>
          <span className="mono">{vitals.armor}</span>
        </div>
        <SegmentBar value={vitals.armor} max={100} segments={10} color="var(--brume)" height={8} />
      </div>
      <span className="mono muted vitals__weight">
        SAC {bagWeight.toFixed(1)} / {config.containers.bag.capacity.toFixed(1)} KG
      </span>
    </div>
  );
}
