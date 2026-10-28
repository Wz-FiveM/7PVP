import { fetchNui } from './nui';
import { mockAdminPlayers, mockLootAdmin } from '../dev/mocks';
import type { AdminActionPayload, AdminActionResult, AdminPlayer, LootAdminData, LootTableData } from '../types/admin';

/** Requêtes du panneau admin (voir client/modules/admin/admin.lua). */
export const adminApi = {
  players: () => fetchNui<AdminPlayer[]>('adminPlayers', {}, mockAdminPlayers),

  action: (payload: AdminActionPayload) =>
    fetchNui<AdminActionResult>('adminAction', payload, { ok: true, message: `Action simulée : ${payload.action}` }),

  /** Onglet « Butin » : tables, zones PvE et objets */
  loot: () => fetchNui<LootAdminData>('adminLoot', {}, mockLootAdmin),

  lootSave: (name: string, table: Pick<LootTableData, 'money' | 'drops'>) =>
    fetchNui<AdminActionResult>('adminLootSave', { name, table }, { ok: true, message: 'Butin enregistré (simulé)' }),

  lootReset: (name: string) =>
    fetchNui<AdminActionResult>('adminLootReset', { name }, { ok: true, message: 'Butin remis par défaut (simulé)' }),

  lootZones: (zones: Record<string, string>) =>
    fetchNui<AdminActionResult>('adminLootZones', { zones }, { ok: true, message: 'Zones enregistrées (simulé)' }),

  close: () => fetchNui<void>('adminClose'),
};
