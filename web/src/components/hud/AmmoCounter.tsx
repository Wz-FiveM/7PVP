import { useT } from '../../i18n';
import { useGame } from '../../store/GameContext';
import { itemLabel } from '../../utils/inventory';

/** Arme en main et munitions (chargeur / réserve), en bas à droite. */
export function AmmoCounter() {
  const t = useT();
  const { state } = useGame();
  const { vitals, config } = state;
  if (!vitals.weapon) return null;

  const item = config.items[vitals.weapon];
  if (!item) return null;

  return (
    <div className="ammo">
      <span className="disp ammo__weapon">
        {t(item.label)}
        {item.ammo && ` · ${itemLabel(config, item.ammo)}`}
      </span>
      {item.ammo && (
        <span className="ammo__count">
          <span className="disp ammo__clip">{vitals.clip}</span>
          <span className="mono ammo__reserve">/ {vitals.reserve}</span>
        </span>
      )}
    </div>
  );
}
