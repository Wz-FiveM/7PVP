import { useGame } from '../../store/GameContext';
import { itemLabel } from '../../utils/inventory';

/** Arme en main et munitions (chargeur / réserve), en bas à droite. */
export function AmmoCounter() {
  const { state } = useGame();
  const { vitals, config } = state;
  if (!vitals.weapon) return null;

  const item = config.items[vitals.weapon];
  if (!item) return null;

  return (
    <div className="ammo cut">
      <span className="disp ammo__weapon">
        {item.label}
        {item.ammo && ` · ${itemLabel(config, item.ammo)}`}
      </span>
      {item.ammo && (
        <span className="mono ammo__count">
          {vitals.clip} <span className="ammo__reserve">/ {vitals.reserve}</span>
        </span>
      )}
    </div>
  );
}
