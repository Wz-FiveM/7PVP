import { fetchNui } from './nui';
import type { ActionResult } from '../types/nui';

const MOCK_OK: ActionResult = { ok: true, message: 'Action simulée (navigateur)' };

/** Menu Crew (voir client/modules/crew/crew.lua). */
export const crewApi = {
  create: (tag: string, name: string) => fetchNui<ActionResult>('crewCreate', { tag, name }, MOCK_OK),

  invite: (target: number) => fetchNui<ActionResult>('crewInvite', { target }, MOCK_OK),

  respond: (accept: boolean) => fetchNui<ActionResult>('crewRespond', { accept }, MOCK_OK),

  leave: () => fetchNui<ActionResult>('crewLeave', {}, MOCK_OK),

  kick: (key: number) => fetchNui<ActionResult>('crewKick', { key }, MOCK_OK),

  transfer: (key: number) => fetchNui<ActionResult>('crewTransfer', { key }, MOCK_OK),

  disband: () => fetchNui<ActionResult>('crewDisband', {}, MOCK_OK),
};
