import { fetchNui } from './nui';
import { mockAdminPlayers } from '../dev/mocks';
import type { AdminActionPayload, AdminActionResult, AdminPlayer } from '../types/admin';

/** Requêtes du panneau admin (voir client/modules/admin/admin.lua). */
export const adminApi = {
  players: () => fetchNui<AdminPlayer[]>('adminPlayers', {}, mockAdminPlayers),

  action: (payload: AdminActionPayload) =>
    fetchNui<AdminActionResult>('adminAction', payload, { ok: true, message: `Action simulée : ${payload.action}` }),

  close: () => fetchNui<void>('adminClose'),
};
