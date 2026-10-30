import { fetchNui } from './nui';
import { mockAdminPlayers, mockFreeroamAdmin, mockLootAdmin } from '../dev/mocks';
import type {
  AdminActionPayload,
  AdminActionResult,
  AdminPlayer,
  FreeroamAdminData,
  FreeroamSetting,
  LootAdminData,
  LootTableData,
  MapPoint,
} from '../types/admin';

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

  /** Onglets « Freeroam » et « Positions » : véhicules et positions des modes de jeu, courses poursuite en cours */
  freeroam: () => fetchNui<FreeroamAdminData>('adminFreeroam', {}, mockFreeroamAdmin),

  /** `kind` : le client vérifie les modèles de véhicule avant l'envoi */
  freeroamSave: (setting: Pick<FreeroamSetting, 'name' | 'kind' | 'value'>) =>
    fetchNui<AdminActionResult>(
      'adminFreeroamSave',
      { name: setting.name, kind: setting.kind, value: setting.value },
      { ok: true, message: 'Réglage enregistré (simulé)' },
    ),

  freeroamReset: (name: string) =>
    fetchNui<AdminActionResult>('adminFreeroamReset', { name }, { ok: true, message: 'Réglage remis par défaut (simulé)' }),

  /** Position actuelle de l'admin (bouton « Ma position ») */
  position: () =>
    fetchNui<{ ok: boolean; point?: MapPoint }>('adminPosition', {}, { ok: true, point: { x: 215.3, y: -930.1, z: 30.7, w: 145 } }),

  close: () => fetchNui<void>('adminClose'),
};
