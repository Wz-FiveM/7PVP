import { useGame } from '../../store/GameContext';
import { entriesOf } from '../../utils/inventory';
import { ItemIcon } from '../inventory/ItemIcon';
import { Brackets } from '../ui/Brackets';

/** Raccourcis 1 à 7, en bas au centre, visibles tant que TAB est maintenu. L'arme en main est encadrée. */
export function HotbarHud() {
  const { state } = useGame();
  const { player, config, vitals, hotbarVisible } = state;
  if (!player || !hotbarVisible) return null;

  const owned = new Map<string, number>();
  for (const stacks of [player.inventory.bag, player.inventory.protected]) {
    for (const [name, count] of entriesOf(stacks)) owned.set(name, (owned.get(name) ?? 0) + count);
  }

  return (
    <div className="hotbar">
      {Array.from({ length: config.shortcutSlots }, (_, i) => {
        const slot = i + 1;
        const name = player.inventory.shortcuts[i] || null;
        const item = name ? config.items[name] : undefined;
        const count = name ? owned.get(name) ?? 0 : 0;
        const active = Boolean(name) && name === vitals.weapon;

        return (
          <div key={slot} className={active ? 'hotbar__slot hotbar__slot--active' : 'hotbar__slot'}>
            <div className={`hotbar__tile cut-s ${!item ? 'hotbar__tile--empty' : ''} ${item && count === 0 ? 'hotbar__tile--missing' : ''}`}>
              {item && name && <ItemIcon name={name} type={item.type} />}
              <span className="mono hotbar__key">{slot}</span>
              {item?.type === 'consumable' && <span className="mono hotbar__count">x{count}</span>}
            </div>
            {active && <Brackets />}
          </div>
        );
      })}
    </div>
  );
}
