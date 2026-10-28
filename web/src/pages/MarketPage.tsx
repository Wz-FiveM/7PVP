import { useCallback, useEffect, useMemo, useState } from 'react';
import { marketApi } from '../api/marketApi';
import { ItemIcon } from '../components/inventory/ItemIcon';
import { Panel } from '../components/ui/Panel';
import { useGame } from '../store/GameContext';
import type { ItemType, MarketState } from '../types/game';
import type { ActionResult } from '../types/nui';
import { formatMoney } from '../utils/format';
import { entriesOf, itemLabel } from '../utils/inventory';
import './pages.css';

type MarketTab = 'buy' | 'sell' | 'mine';

const TABS: { id: MarketTab; label: string }[] = [
  { id: 'buy', label: 'Acheter' },
  { id: 'sell', label: 'Vendre' },
  { id: 'mine', label: 'Mes annonces' },
];

const FILTERS: { type: ItemType | 'all'; label: string }[] = [
  { type: 'all', label: 'Tout' },
  { type: 'weapon', label: 'Armes' },
  { type: 'attachment', label: 'Accessoires' },
  { type: 'ammo', label: 'Munitions' },
  { type: 'consumable', label: 'Soins' },
  { type: 'material', label: 'Matériaux' },
];

interface SellChoice {
  container: 'bag' | 'protected';
  item: string;
  max: number;
}

const EMPTY: MarketState = { listings: [], balance: 0, fee: 0.05, maxListings: 10 };

/** Place de marché entre joueurs, auprès du commissaire-priseur de la zone safe. */
export function MarketPage() {
  const { state, actions } = useGame();
  const { config, player, menu } = state;
  const [market, setMarket] = useState<MarketState>(EMPTY);
  const [tab, setTab] = useState<MarketTab>('buy');
  const [filter, setFilter] = useState<ItemType | 'all'>('all');
  const [search, setSearch] = useState('');
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

  const visible = useMemo(() => {
    const query = search.trim().toLowerCase();
    return market.listings.filter((listing) => {
      const item = config.items[listing.item];
      if (!item || listing.mine) return false;
      if (filter !== 'all' && item.type !== filter) return false;
      return !query || item.label.toLowerCase().includes(query);
    });
  }, [market.listings, config.items, filter, search]);

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
    }
  };

  return (
    <div className="market">
      {!atMarket && (
        <p className="hint cut-s">Les échanges se font auprès du commissaire-priseur, en zone safe (repère sur la carte).</p>
      )}

      <div className="market__top">
        <div className="market__tabs">
          {TABS.map((item) => (
            <button
              key={item.id}
              className={item.id === tab ? 'btn btn--small btn--active cut-s' : 'btn btn--small cut-s'}
              onClick={() => setTab(item.id)}
            >
              {item.label}
              {item.id === 'mine' && ` (${mine.length}/${market.maxListings})`}
            </button>
          ))}
        </div>
        <div className="market__balance">
          <span className="label">À récupérer</span>
          <span className="mono market__balance-value">{formatMoney(market.balance)}</span>
          <button
            className="btn btn--primary btn--small cut-s"
            disabled={!atMarket || market.balance <= 0}
            onClick={() => run(marketApi.collect())}
          >
            Récupérer
          </button>
        </div>
      </div>

      {tab === 'buy' && (
        <>
          <div className="market__filters">
            <input
              className="field market__search"
              value={search}
              onChange={(event) => setSearch(event.target.value)}
              placeholder="Rechercher un objet"
            />
            {FILTERS.map((item) => (
              <button
                key={item.type}
                className={item.type === filter ? 'btn btn--small btn--active cut-s' : 'btn btn--small cut-s'}
                onClick={() => setFilter(item.type)}
              >
                {item.label}
              </button>
            ))}
          </div>
          {visible.length === 0 && <p className="muted market__empty">Aucune annonce pour le moment.</p>}
          {visible.map((listing) => {
            const item = config.items[listing.item];
            const affordable = (player?.money ?? 0) >= listing.price;
            return (
              <Panel key={listing.id} className="market-row">
                <span className="market-row__icon cut-s">
                  <ItemIcon name={listing.item} type={item.type} />
                </span>
                <span className="market-row__info">
                  <span className="disp market-row__name">
                    {item.label} <span className="mono muted">x{listing.count}</span>
                  </span>
                  <span className="muted market-row__seller">Vendu par {listing.sellerName}</span>
                </span>
                <span className="mono market-row__price">{formatMoney(listing.price)}</span>
                <button
                  className="btn btn--primary btn--small cut-s"
                  disabled={!atMarket || !affordable}
                  onClick={() => run(marketApi.buy(listing.id))}
                >
                  Acheter
                </button>
              </Panel>
            );
          })}
        </>
      )}

      {tab === 'sell' && (
        <div className="market__sell">
          <div className="market__sellable">
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
                  className="btn btn--primary btn--small cut-s"
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

      {tab === 'mine' && (
        <>
          {mine.length === 0 && <p className="muted market__empty">Tu n'as aucune annonce en cours.</p>}
          {mine.map((listing) => {
            const item = config.items[listing.item];
            if (!item) return null;
            return (
              <Panel key={listing.id} className="market-row">
                <span className="market-row__icon cut-s">
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
                  className="btn btn--danger btn--small cut-s"
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
