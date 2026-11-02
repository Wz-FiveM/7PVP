import { useCallback, useEffect, useState } from 'react';
import { gameApi } from '../api/gameApi';
import { BuyModal } from '../components/inventory/BuyModal';
import { ItemIcon } from '../components/inventory/ItemIcon';
import { Panel, PanelHeader } from '../components/ui/Panel';
import { useT } from '../i18n';
import { useGame } from '../store/GameContext';
import type { BlackMarketOffer, BlackMarketState } from '../types/game';
import { formatMoney } from '../utils/format';
import { lotsThatFit } from '../utils/inventory';
import '../components/inventory/inventory.css';
import './pages.css';
import './resale.css';

const REFRESH_MS = 4000;

/** Marchand noir ambulant : lots limités, partagés entre tous les joueurs. */
export function BlackMarketPage() {
  const t = useT();
  const { state, actions } = useGame();
  const { config, player } = state;
  const [market, setMarket] = useState<BlackMarketState | null>(null);
  const [busy, setBusy] = useState(false);
  /** Lot dont on choisit la quantité (index 1-based) */
  const [buying, setBuying] = useState<number | null>(null);
  const closeBuying = useCallback(() => setBuying(null), []);

  const refresh = useCallback(async () => {
    const result = await gameApi.blackMarketList();
    if (result) setMarket(result);
  }, []);

  useEffect(() => {
    refresh();
    const timer = window.setInterval(refresh, REFRESH_MS);
    return () => window.clearInterval(timer);
  }, [refresh]);

  const buy = async (index: number, lots: number) => {
    setBusy(true);
    const result = await gameApi.blackMarketBuy(index, lots);
    if (result?.message) actions.notify(result.message, result.ok ? 'success' : 'error');
    await refresh();
    setBusy(false);
  };

  if (!market) return null;
  if (!market.open) return <p className="muted market__empty">{t('Le marchand noir est parti.')}</p>;

  const money = player?.money ?? 0;
  const pending = buying !== null ? market.stock[buying - 1] : null;

  /** Lots restants que le joueur peut payer et porter */
  const maxLots = (offer: BlackMarketOffer) =>
    Math.min(offer.left, Math.floor(money / offer.price), lotsThatFit(config, player, offer.item, offer.count));

  /** Achète directement s'il n'y a qu'un lot possible (le serveur explique un refus), sinon demande la quantité. */
  const startBuy = (offer: BlackMarketOffer, index: number) => {
    if (maxLots(offer) > 1) setBuying(index);
    else buy(index, 1);
  };

  return (
    <div className="resale">
      <p className="muted resale__note">
        {t('Stock partagé entre tous les joueurs. Parti dans {minutes} min.', { minutes: Math.ceil((market.endsIn ?? 0) / 60) })}
      </p>
      {!market.near && <p className="hint cut-s">{t('Le marchand noir est trop loin.')}</p>}
      <Panel>
        <PanelHeader title={t('Marchand noir')} />
        <ul className="resale__rows">
          {market.stock.map((offer, index) => {
            const item = config.items[offer.item];
            if (!item) return null;
            return (
              <li key={offer.item} className="resale-row">
                <span className="market-row__icon">
                  <ItemIcon name={offer.item} type={item.type} />
                </span>
                <span className="resale-row__info">
                  <span className="disp resale-row__name">{offer.count} x {t(item.label)}</span>
                  <span className="mono muted resale-row__stock">{t('Lots restants : {left}', { left: offer.left })}</span>
                </span>
                <button
                  className="btn btn--primary btn--small resale-row__sell"
                  disabled={busy || !market.near || offer.left <= 0 || money < offer.price}
                  onClick={() => startBuy(offer, index + 1)}
                >
                  {t('Acheter · {price}', { price: formatMoney(offer.price) })}
                </button>
              </li>
            );
          })}
        </ul>
      </Panel>
      {pending && buying !== null && (
        <BuyModal
          item={pending.item}
          count={pending.count}
          price={pending.price}
          max={maxLots(pending)}
          onConfirm={(lots) => {
            buy(buying, lots);
            closeBuying();
          }}
          onCancel={closeBuying}
        />
      )}
    </div>
  );
}
