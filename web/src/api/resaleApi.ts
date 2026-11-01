import { fetchNui } from './nui';
import { mockResale } from '../dev/mocks';
import type { ResaleState } from '../types/game';
import type { ActionResult } from '../types/nui';

/** Revente au receleur (voir server/modules/resale/resale_service.lua). */
export const resaleApi = {
  list: () => fetchNui<ResaleState>('resaleList', {}, mockResale),

  /** Vend `count` objets portés au prix du receleur */
  sell: (container: 'bag' | 'protected', item: string, count: number) =>
    fetchNui<ActionResult>('resaleSell', { container, item, count }, { ok: true, message: 'Vente simulée (navigateur)' }),
};
