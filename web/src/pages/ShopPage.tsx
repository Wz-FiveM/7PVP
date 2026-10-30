import { ItemTile } from '../components/inventory/ItemTile';
import { Panel, PanelHeader } from '../components/ui/Panel';
import { useT } from '../i18n';
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
  { type: 'vehicle', label: 'Véhicules' },
];

export function ShopPage() {
  const t = useT();
  const { state, actions } = useGame();
  const { config, player, menu } = state;
  const money = player?.money ?? 0;

  // Config.Shop est indexé à partir de 1 côté Lua
  const entries = config.shop.map((entry, i) => ({ entry, index: i + 1 }));

  return (
    <>
      {!menu.near.shop && (
        <p className="hint cut-s">{t('Achats auprès de l\'armurier, en zone safe (repère rouge sur la carte).')}</p>
      )}
      {SECTIONS.map((section) => {
        const list = entries.filter(({ entry }) => config.items[entry.item]?.type === section.type);
        if (list.length === 0) return null;
        return (
          <Panel key={section.type}>
            <PanelHeader
              title={t(section.label)}
              aside={section.type === 'weapon' ? t('SOLDE {money}', { money: formatMoney(money) }) : undefined}
            />
            <div className="tile-grid shop__grid">
              {list.map(({ entry, index }) => {
                const item = config.items[entry.item];
                const locked = (player?.level ?? 1) < (entry.level ?? 1);
                return (
                  <ItemTile
                    key={index}
                    name={entry.item}
                    item={entry.count > 1 ? { ...item, label: `${t(item.label)} x${entry.count}` } : item}
                    corner={locked ? t('NIV. {level}', { level: entry.level ?? 1 }) : formatMoney(entry.price)}
                    disabled={locked || !menu.near.shop || money < entry.price}
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
