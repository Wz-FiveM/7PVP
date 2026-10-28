import { ItemTile } from '../components/inventory/ItemTile';
import { Panel, PanelHeader } from '../components/ui/Panel';
import { useGame } from '../store/GameContext';
import type { ItemType } from '../types/game';
import { formatMoney } from '../utils/format';
import '../components/inventory/inventory.css';
import './pages.css';

const SECTIONS: { type: ItemType; label: string }[] = [
  { type: 'weapon', label: 'Armes' },
  { type: 'ammo', label: 'Munitions' },
  { type: 'attachment', label: 'Accessoires' },
  { type: 'consumable', label: 'Soins & équipement' },
];

export function ShopPage() {
  const { state, actions } = useGame();
  const { config, player, menu } = state;
  const money = player?.money ?? 0;

  // Config.Shop est indexé à partir de 1 côté Lua
  const entries = config.shop.map((entry, i) => ({ entry, index: i + 1 }));

  return (
    <>
      {!menu.inSafe && (
        <p className="hint cut-s">La boutique n'est accessible qu'en zone safe. Rejoins un abri pour acheter.</p>
      )}
      {SECTIONS.map((section) => {
        const list = entries.filter(({ entry }) => config.items[entry.item]?.type === section.type);
        if (list.length === 0) return null;
        return (
          <Panel key={section.type}>
            <PanelHeader
              title={section.label}
              aside={section.type === 'weapon' ? `SOLDE ${formatMoney(money)}` : undefined}
            />
            <div className="tile-grid shop__grid">
              {list.map(({ entry, index }) => {
                const item = config.items[entry.item];
                const locked = (player?.level ?? 1) < (entry.level ?? 1);
                return (
                  <ItemTile
                    key={index}
                    name={entry.item}
                    item={entry.count > 1 ? { ...item, label: `${item.label} x${entry.count}` } : item}
                    corner={locked ? `NIV. ${entry.level}` : formatMoney(entry.price)}
                    disabled={locked || !menu.inSafe || money < entry.price}
                    onClick={() => actions.buy(index)}
                  />
                );
              })}
            </div>
          </Panel>
        );
      })}
    </>
  );
}
