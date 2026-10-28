import { fetchNui } from './nui';
import type { ActionResult } from '../types/nui';

/** Menu du Freeroam (voir client/modules/freeroam/freeroam.lua). */
export const freeroamApi = {
  close: () => fetchNui<void>('freeroamClose'),

  action: (action: string, data: Record<string, unknown> = {}) =>
    fetchNui<ActionResult & { pvp?: boolean }>('freeroamAction', { action, ...data }, {
      ok: true,
      message: `Action simulée : ${action}`,
      pvp: action === 'pvp' ? true : undefined,
    }),
};
