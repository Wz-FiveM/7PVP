import { fetchNui } from './nui';
import type { ActionResult } from '../types/nui';

const MOCK_OK: ActionResult = { ok: true };

/** Fenêtre d'échange entre joueurs (voir client/modules/trade/trade.lua). */
export const tradeApi = {
  /** `count` : quantité totale proposée, 0 retire l'objet de l'offre */
  offer: (item: string, count: number) => fetchNui<ActionResult>('tradeOffer', { item, count }, MOCK_OK),

  ready: (ready: boolean) => fetchNui<ActionResult>('tradeReady', { ready }, MOCK_OK),

  confirm: () => fetchNui<ActionResult>('tradeConfirm', {}, MOCK_OK),

  cancel: () => fetchNui<ActionResult>('tradeCancel', {}, { ok: true, message: 'Échange annulé.' }),
};
