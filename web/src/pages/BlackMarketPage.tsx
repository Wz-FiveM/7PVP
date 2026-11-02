import { useCallback, useEffect, useState } from 'react';
import { gameApi } from '../api/gameApi';
import { ItemIcon } from '../components/inventory/ItemIcon';
import { Panel, PanelHeader } from '../components/ui/Panel';
import { useT } from '../i18n';
import { useGame } from '../store/GameContext';
import type { BlackMarketState } from '../types/game';
import { formatMoney } from '../utils/format';
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

  const refresh = useCallback(async () => {
    const result = await gameApi.blackMarketList();
    if (result) setMarket(result);
  }, []);

  useEffect(() => {
    refresh();
    const timer = window.setInterval(refresh, REFRESH_MS);
    return () => window.clearInterval(timer);
  }, [refresh]);

  const buy = async (index: number) => {
    setBusy(true);
    const result = await gameApi.blackMarketBuy(index);
    if (result?.message) actions.notify(result.message, result.ok ? 'success' : 'error');
    await refresh();
    setBusy(false);
  };

  if (!market) return null;
  if (!market.open) return <p className="muted market__empty">{t('Le marchand noir est parti.')}</p>;

  const money = player?.money ?? 0;
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
                  <span className="mono muted resale-row__stock">{t('{left} lots restants', { left: offer.left })}</span>
                </span>
                <button
                  className="btn btn--primary btn--small resale-row__sell"
                  disabled={busy || !market.near || offer.left <= 0 || money < offer.price}
                  onClick={() => buy(index + 1)}
                >
                  {t('Acheter · {price}', { price: formatMoney(offer.price) })}
                </button>
              </li>
            );
          })}
        </ul>
      </Panel>
    </div>
  );
}
