import { useCallback, useEffect, useMemo, useState } from 'react';
import { marketApi } from '../api/marketApi';
import { ItemIcon } from '../components/inventory/ItemIcon';
import { Panel } from '../components/ui/Panel';
import { useGame } from '../store/GameContext';
import type { ItemType, MarketListing, MarketState } from '../types/game';
import type { ActionResult } from '../types/nui';
import { formatMoney } from '../utils/format';
import { entriesOf, itemLabel } from '../utils/inventory';
import './pages.css';
import './market.css';

/** catalog : objets en vente ; sell : nouvelle offre ; mine : mes offres */
type MarketView = 'catalog' | 'sell' | 'mine';

/** Sections du catalogue, dans l'ordre */
const SECTIONS: { type: ItemType; label: string }[] = [
  { type: 'weapon', label: 'Armes' },
  { type: 'ammo', label: 'Munitions' },
  { type: 'attachment', label: 'Accessoires' },
  { type: 'consumable', label: 'Soins et équipement' },
  { type: 'vehicle', label: 'Véhicules' },
  { type: 'material', label: 'Matériaux' },
];

const TYPE_LABELS: Partial<Record<ItemType, string>> = {
  weapon: 'Arme',
  ammo: 'Munitions',
  attachment: 'Accessoire',
  consumable: 'Soin',
  vehicle: 'Véhicule',
  material: 'Matériau',
};

/** Toutes les offres d'un même objet */
interface ItemGroup {
  item: string;
  offers: MarketListing[];
  /** prix unitaire le plus bas */
  lowest: number;
}

interface SellChoice {
  container: 'bag' | 'protected';
  item: string;
  max: number;
}

const EMPTY: MarketState = { listings: [], balance: 0, fee: 0.05, maxListings: 10 };

const unitPrice = (listing: MarketListing) => listing.price / Math.max(1, listing.count);

/** Place de marché entre joueurs : catalogue par objet, offres triées par prix, auprès du commissaire-priseur. */
export function MarketPage() {
  const { state, actions } = useGame();
  const { config, player, menu } = state;
  const [market, setMarket] = useState<MarketState>(EMPTY);
  const [view, setView] = useState<MarketView>('catalog');
  const [search, setSearch] = useState('');
  const [openItem, setOpenItem] = useState<string | null>(null);
  const [selectedOffer, setSelectedOffer] = useState<number | null>(null);
  const [choice, setChoice] = useState<SellChoice | null>(null);
  const [count, setCount] = useState(1);
  const [price, setPrice] = useState('');
  const atMarket = Boolean(menu.near.market);

  const refresh = useCallback(async () => {
    const result = await marketApi.list();
    if (result) setMarket({ ...EMPTY, ...result, listings: Array.isArray(result.listings) ? result.listings : [] });
  }, []);

  useEffect(() => {
    refresh();
  }, [refresh]);

  const run = async (request: Promise<ActionResult>) => {
    const result = await request;
    if (result?.message) actions.notify(result.message, result.ok ? 'success' : 'error');
    if (result?.ok) refresh();
    return result?.ok ?? false;
  };

  // Offres des autres joueurs, regroupées par objet et filtrées par la recherche
  const groups = useMemo(() => {
    const query = search.trim().toLowerCase();
    const byItem = new Map<string, ItemGroup>();
    for (const listing of market.listings) {
      const item = config.items[listing.item];
      if (!item || listing.mine) continue;
      if (query && !item.label.toLowerCase().includes(query)) continue;
      const group = byItem.get(listing.item) ?? { item: listing.item, offers: [], lowest: Infinity };
      group.offers.push(listing);
      group.lowest = Math.min(group.lowest, unitPrice(listing));
      byItem.set(listing.item, group);
    }
    for (const group of byItem.values()) group.offers.sort((a, b) => unitPrice(a) - unitPrice(b));
    return [...byItem.values()].sort((a, b) =>
      config.items[a.item].label.localeCompare(config.items[b.item].label, 'fr'),
    );
  }, [market.listings, config.items, search]);

  const opened = groups.find((group) => group.item === openItem) ?? null;
  const mine = market.listings.filter((listing) => listing.mine);

  // Objets portés vendables : sac et conteneur protégé, sans l'argent
  const sellable = player
    ? (['bag', 'protected'] as const).flatMap((container) =>
        entriesOf(player.inventory[container])
          .filter(([name]) => config.items[name] && config.items[name].type !== 'money')
          .map(([name, max]) => ({ container, item: name, max })),
      )
    : [];

  const totalPrice = Math.max(0, Math.floor(Number(price) || 0));
  const earned = Math.floor(totalPrice * (1 - market.fee));

  const submitSale = async () => {
    if (!choice || totalPrice <= 0) return;
    const ok = await run(marketApi.sell(choice.container, choice.item, count, totalPrice));
    if (ok) {
      setChoice(null);
      setPrice('');
      setCount(1);
      setView('mine');
    }
  };

  const buy = async (listing: MarketListing) => {
    if (await run(marketApi.buy(listing.id))) setSelectedOffer(null);
  };

  return (
    <div className="market">
      {!atMarket && (
        <p className="hint cut-s">Les échanges se font auprès du commissaire-priseur, en zone safe (repère sur la carte).</p>
      )}

      <div className="market-bar">
        <label className="market-bar__search">
          <span className="disp market-bar__search-label">Rechercher</span>
          <input
            className="market-bar__input"
            value={search}
            onChange={(event) => {
              setSearch(event.target.value);
              setView('catalog');
            }}
            placeholder="Nom d'un objet…"
          />
        </label>
        <button
          className={view === 'sell' ? 'btn btn--active market-bar__button' : 'btn btn--primary market-bar__button'}
          onClick={() => setView(view === 'sell' ? 'catalog' : 'sell')}
        >
          Nouvelle offre
        </button>
        <button
          className={view === 'mine' ? 'btn btn--active market-bar__button' : 'btn market-bar__button'}
          onClick={() => setView(view === 'mine' ? 'catalog' : 'mine')}
        >
          Mes offres ({mine.length}/{market.maxListings})
        </button>
      </div>

      <div className="market-balance">
        <span className="label">Ventes à récupérer</span>
        <span className="mono market-balance__value">{formatMoney(market.balance)}</span>
        <button
          className="btn btn--small"
          disabled={!atMarket || market.balance <= 0}
          onClick={() => run(marketApi.collect())}
        >
          Récupérer
        </button>
      </div>

      {view === 'catalog' && (
        <div className={opened ? 'market-catalog market-catalog--open' : 'market-catalog'}>
          <div className="market-catalog__sections">
            {groups.length === 0 && (
              <p className="muted market__empty">{search ? 'Aucune offre pour cette recherche.' : 'Aucune offre pour le moment.'}</p>
            )}
            {SECTIONS.map((section) => {
              const list = groups.filter((group) => config.items[group.item].type === section.type);
              if (list.length === 0) return null;
              return (
                <section key={section.type} className="market-section">
                  <h2 className="disp market-section__title">{section.label}</h2>
                  <div className="market-grid">
                    {list.map((group) => {
                      const item = config.items[group.item];
                      return (
                        <button
                          key={group.item}
                          className={group.item === openItem ? 'market-card market-card--open' : 'market-card'}
                          onClick={() => {
                            setOpenItem(group.item === openItem ? null : group.item);
                            setSelectedOffer(null);
                          }}
                        >
                          <span className="market-card__image">
                            <ItemIcon name={group.item} type={item.type} />
                          </span>
                          <span className="disp market-card__name">{item.label}</span>
                          <span className="market-card__type">
                            {TYPE_LABELS[item.type] ?? item.type} · dès {formatMoney(Math.round(group.lowest))}
                          </span>
                          <span className="mono market-card__offers">
                            Voir {group.offers.length} offre{group.offers.length > 1 ? 's' : ''}
                          </span>
                        </button>
                      );
                    })}
                  </div>
                </section>
              );
            })}
          </div>

          {opened && (
            <aside className="market-offers">
              <header className="market-offers__header">
                <span className="disp">Offres</span>
                <span className="muted">{itemLabel(config, opened.item)}</span>
              </header>
              <ul className="market-offers__list">
                {opened.offers.map((listing) => {
                  const selected = listing.id === selectedOffer;
                  const affordable = (player?.money ?? 0) >= listing.price;
                  return (
                    <li key={listing.id}>
                      <button
                        className={selected ? 'market-offer market-offer--selected' : 'market-offer'}
                        onClick={() => setSelectedOffer(selected ? null : listing.id)}
                      >
                        <span className="disp market-offer__seller">{listing.sellerName}</span>
                        <span className="mono market-offer__count">x{listing.count}</span>
                        <span className="mono market-offer__price">{formatMoney(listing.price)}</span>
                      </button>
                      {selected && (
                        <div className="market-offer__buy">
                          {listing.count > 1 && (
                            <span className="mono muted">{formatMoney(Math.round(unitPrice(listing)))} / unité</span>
                          )}
                          <button
                            className="btn btn--primary btn--small"
                            disabled={!atMarket || !affordable}
                            onClick={() => buy(listing)}
                          >
                            {affordable ? `Acheter · ${formatMoney(listing.price)}` : 'Pas assez d\'argent'}
                          </button>
                        </div>
                      )}
                    </li>
                  );
                })}
              </ul>
            </aside>
          )}
        </div>
      )}

      {view === 'sell' && (
        <div className="market__sell">
          <div className="market__sellable">
            {sellable.length === 0 && <p className="muted market__empty">Tu ne portes rien à vendre.</p>}
            {sellable.map((entry) => {
              const item = config.items[entry.item];
              const selected = choice?.item === entry.item && choice.container === entry.container;
              return (
                <button
                  key={`${entry.container}:${entry.item}`}
                  className={selected ? 'market-pick market-pick--selected cut-s' : 'market-pick cut-s'}
                  onClick={() => {
                    setChoice(entry);
                    setCount(1);
                  }}
                >
                  <ItemIcon name={entry.item} type={item.type} />
                  <span className="market-pick__label">{item.label}</span>
                  <span className="mono market-pick__count">
                    x{entry.max}
                    {entry.container === 'protected' && ' · protégé'}
                  </span>
                </button>
              );
            })}
          </div>

          <Panel className="market-form">
            {choice ? (
              <>
                <span className="disp market-form__title">{itemLabel(config, choice.item)}</span>
                <label className="market-form__field">
                  <span className="label">Quantité (max {choice.max})</span>
                  <input
                    className="field"
                    type="number"
                    min={1}
                    max={choice.max}
                    value={count}
                    onChange={(event) => setCount(Math.min(choice.max, Math.max(1, Math.floor(Number(event.target.value) || 1))))}
                  />
                </label>
                <label className="market-form__field">
                  <span className="label">Prix total du lot ($)</span>
                  <input
                    className="field"
                    inputMode="numeric"
                    value={price}
                    onChange={(event) => setPrice(event.target.value.replace(/\D/g, ''))}
                    placeholder="ex : 1500"
                  />
                </label>
                <span className="mono muted market-form__earned">
                  TU RECEVRAS {formatMoney(earned)} (TAXE {Math.round(market.fee * 100)} %)
                </span>
                <button
                  className="btn btn--primary btn--small"
                  disabled={!atMarket || totalPrice <= 0 || mine.length >= market.maxListings}
                  onClick={submitSale}
                >
                  Mettre en vente
                </button>
              </>
            ) : (
              <p className="muted">Choisis un objet porté (sac ou conteneur protégé) à mettre en vente.</p>
            )}
          </Panel>
        </div>
      )}

      {view === 'mine' && (
        <>
          {mine.length === 0 && <p className="muted market__empty">Tu n'as aucune offre en cours.</p>}
          {mine.map((listing) => {
            const item = config.items[listing.item];
            if (!item) return null;
            return (
              <Panel key={listing.id} className="market-row">
                <span className="market-row__icon">
                  <ItemIcon name={listing.item} type={item.type} />
                </span>
                <span className="market-row__info">
                  <span className="disp market-row__name">
                    {item.label} <span className="mono muted">x{listing.count}</span>
                  </span>
                  <span className="muted market-row__seller">En vente</span>
                </span>
                <span className="mono market-row__price">{formatMoney(listing.price)}</span>
                <button
                  className="btn btn--danger btn--small"
                  disabled={!atMarket}
                  onClick={() => run(marketApi.cancel(listing.id))}
                >
                  Retirer
                </button>
              </Panel>
            );
          })}
        </>
      )}
    </div>
  );
}
