import { useCallback, useEffect, useState } from 'react';
import { resaleApi } from '../api/resaleApi';
import { ItemIcon } from '../components/inventory/ItemIcon';
import { Panel, PanelHeader } from '../components/ui/Panel';
import { useT } from '../i18n';
import { useGame } from '../store/GameContext';
import type { ItemType } from '../types/game';
import { formatMoney } from '../utils/format';
import { entriesOf } from '../utils/inventory';
import './pages.css';
import './resale.css';

/** Sections de la page, dans l'ordre */
const SECTIONS: { type: ItemType; label: string }[] = [
  { type: 'weapon', label: 'Armes' },
  { type: 'ammo', label: 'Munitions' },
  { type: 'attachment', label: 'Accessoires' },
  { type: 'consumable', label: 'Soins et équipement' },
  { type: 'vehicle', label: 'Véhicules' },
  { type: 'case', label: 'Caisses' },
  { type: 'material', label: 'Matériaux' },
];

/** Revente au receleur : les objets portés qu'il reprend, avec leur prix par unité. */
export function ResalePage() {
  const t = useT();
  const { state, actions } = useGame();
  const { config, player, menu } = state;
  const [prices, setPrices] = useState<Record<string, number>>({});
  /** Quantité choisie par ligne (conteneur:objet) */
  const [counts, setCounts] = useState<Record<string, number>>({});
  const [busy, setBusy] = useState(false);
  const atResale = Boolean(menu.near.resale);

  const refresh = useCallback(async () => {
    const result = await resaleApi.list();
    if (result) setPrices(result.prices ?? {});
  }, []);

  useEffect(() => {
    refresh();
  }, [refresh]);

  // Objets portés que le receleur reprend : sac et conteneur protégé
  const entries = player
    ? (['bag', 'protected'] as const).flatMap((container) =>
        entriesOf(player.inventory[container])
          .filter(([name]) => config.items[name] && prices[name] > 0)
          .map(([name, max]) => ({ container, item: name, max, key: `${container}:${name}` })),
      )
    : [];

  const sell = async (container: 'bag' | 'protected', item: string, count: number, key: string) => {
    setBusy(true);
    const result = await resaleApi.sell(container, item, count);
    if (result?.message) actions.notify(result.message, result.ok ? 'success' : 'error');
    // Un prix a pu changer entre-temps
    await refresh();
    if (result?.ok) setCounts((current) => ({ ...current, [key]: 1 }));
    setBusy(false);
  };

  return (
    <div className="resale">
      {!atResale && (
        <p className="hint cut-s">{t('Le receleur reprend tes objets en zone safe (repère sur la carte).')}</p>
      )}
      <p className="muted resale__note">
        {t('Objets portés seulement (sac et conteneur protégé). L\'argent arrive dans ton sac, les accessoires fixés sur une arme vendue aussi.')}
      </p>

      {entries.length === 0 && <p className="muted market__empty">{t('Tu ne portes rien que le receleur reprend.')}</p>}

      {SECTIONS.map((section) => {
        const list = entries.filter((entry) => config.items[entry.item].type === section.type);
        if (list.length === 0) return null;
        return (
          <Panel key={section.type}>
            <PanelHeader title={t(section.label)} />
            <ul className="resale__rows">
              {list.map((entry) => {
                const item = config.items[entry.item];
                const count = Math.min(entry.max, counts[entry.key] ?? 1);
                const total = prices[entry.item] * count;
                return (
                  <li key={entry.key} className="resale-row">
                    <span className="market-row__icon">
                      <ItemIcon name={entry.item} type={item.type} />
                    </span>
                    <span className="resale-row__info">
                      <span className="disp resale-row__name">{t(item.label)}</span>
                      <span className="mono muted resale-row__stock">
                        x{entry.max}
                        {entry.container === 'protected' && ` · ${t('protégé')}`}
                        {' · '}
                        {t('{price} / unité', { price: formatMoney(prices[entry.item]) })}
                      </span>
                    </span>
                    <input
                      className="field resale-row__count"
                      type="number"
                      min={1}
                      max={entry.max}
                      value={count}
                      aria-label={t('Quantité (max {max})', { max: entry.max })}
                      onChange={(event) =>
                        setCounts({
                          ...counts,
                          [entry.key]: Math.min(entry.max, Math.max(1, Math.floor(Number(event.target.value) || 1))),
                        })
                      }
                    />
                    <button
                      className="btn btn--small"
                      disabled={count === entry.max}
                      onClick={() => setCounts({ ...counts, [entry.key]: entry.max })}
                    >
                      {t('Tout')}
                    </button>
                    <button
                      className="btn btn--primary btn--small resale-row__sell"
                      disabled={!atResale || busy}
                      onClick={() => sell(entry.container, entry.item, count, entry.key)}
                    >
                      {t('Vendre · {price}', { price: formatMoney(total) })}
                    </button>
                  </li>
                );
              })}
            </ul>
          </Panel>
        );
      })}
    </div>
  );
}
