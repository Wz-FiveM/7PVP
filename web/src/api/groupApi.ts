import { fetchNui } from './nui';
import type { ActionResult } from '../types/nui';

const MOCK_OK: ActionResult = { ok: true, message: 'Action simulée (navigateur)' };

/** Menu Groupe (voir client/modules/group/group.lua). */
export const groupApi = {
  invite: (target: number) => fetchNui<ActionResult>('groupInvite', { target }, MOCK_OK),

  respond: (accept: boolean) => fetchNui<ActionResult>('groupRespond', { accept }, MOCK_OK),

  leave: () => fetchNui<ActionResult>('groupLeave', {}, MOCK_OK),

  kick: (target: number) => fetchNui<ActionResult>('groupKick', { target }, MOCK_OK),
};
