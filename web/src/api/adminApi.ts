import { fetchNui } from './nui';
import { mockAdminPlayers, mockFreeroamAdmin, mockLootAdmin, mockResaleAdmin, mockShopAdmin } from '../dev/mocks';
import type {
  AdminActionPayload,
  AdminActionResult,
  AdminPlayer,
  CodMapData,
  FreeroamAdminData,
  FreeroamSetting,
  LootAdminData,
  LootTableData,
  MapPoint,
  ResaleAdminData,
  ShopAdminData,
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

  /** Onglet « Boutique » : prix de l'armurier */
  shop: () => fetchNui<ShopAdminData>('adminShop', {}, mockShopAdmin),

  /** `prices` : seulement les prix modifiés */
  shopSave: (prices: Record<string, number>) =>
    fetchNui<AdminActionResult>('adminShopSave', { prices }, { ok: true, message: 'Prix enregistrés (simulé)' }),

  shopReset: () =>
    fetchNui<AdminActionResult>('adminShopReset', {}, { ok: true, message: 'Prix remis par défaut (simulé)' }),

  /** Onglet « Revente » : prix du receleur */
  resale: () => fetchNui<ResaleAdminData>('adminResale', {}, mockResaleAdmin),

  /** `prices` : seulement les prix modifiés */
  resaleSave: (prices: Record<string, number>) =>
    fetchNui<AdminActionResult>('adminResaleSave', { prices }, { ok: true, message: 'Prix enregistrés (simulé)' }),

  resaleReset: () =>
    fetchNui<AdminActionResult>('adminResaleReset', {}, { ok: true, message: 'Prix remis par défaut (simulé)' }),

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

  /** Cartes Call of Duty de l'onglet « Positions » : création sans `id`, modification avec */
  codMapSave: (map: Omit<CodMapData, 'id' | 'custom'> & { id?: string }) =>
    fetchNui<AdminActionResult & { id?: string }>('adminCodMapSave', map, { ok: true, id: map.id ?? 'map1', message: 'Carte enregistrée (simulé)' }),

  codMapDelete: (id: string) =>
    fetchNui<AdminActionResult>('adminCodMapDelete', { id }, { ok: true, message: 'Carte supprimée (simulé)' }),

  codMapRestore: (id: string) =>
    fetchNui<AdminActionResult & { id?: string }>('adminCodMapRestore', { id }, { ok: true, id, message: 'Carte remise (simulé)' }),

  /** Position actuelle de l'admin (bouton « Ma position ») */
  position: () =>
    fetchNui<{ ok: boolean; point?: MapPoint }>('adminPosition', {}, { ok: true, point: { x: 215.3, y: -930.1, z: 30.7, w: 145 } }),

  close: () => fetchNui<void>('adminClose'),
};
