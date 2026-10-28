import { fetchNui } from './nui';
import { mockMarket } from '../dev/mocks';
import type { MarketState } from '../types/game';
import type { ActionResult } from '../types/nui';

const MOCK_OK: ActionResult = { ok: true, message: 'Action simulée (navigateur)' };

/** Place de marché (voir server/modules/market/market_service.lua). */
export const marketApi = {
  list: () => fetchNui<MarketState>('marketList', {}, mockMarket),

  /** Met en vente `count` objets portés pour un prix total */
  sell: (container: 'bag' | 'protected', item: string, count: number, price: number) =>
    fetchNui<ActionResult>('marketSell', { container, item, count, price }, MOCK_OK),

  buy: (id: number) => fetchNui<ActionResult>('marketBuy', { id }, MOCK_OK),

  cancel: (id: number) => fetchNui<ActionResult>('marketCancel', { id }, MOCK_OK),

  collect: () => fetchNui<ActionResult>('marketCollect', {}, MOCK_OK),
};
