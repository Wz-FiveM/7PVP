import type { WeaponCustomChoice } from '../types/weaponCustom';
import { fetchNui } from './nui';

/** Custom des armes chez le customiseur (voir client/modules/inventory/weapon_custom.lua). */
export const weaponCustomApi = {
  /** Essai sur le modèle posé devant le joueur */
  preview: (name: string, choice: WeaponCustomChoice, attachments: string[]) =>
    fetchNui<unknown>('weaponCustomPreview', { name, ...choice, attachments }, {}),
  rotate: (delta: number) => fetchNui<unknown>('weaponCustomRotate', { delta }, {}),
  /** Armes modifiées : objet de l'arme -> custom */
  save: (customs: Record<string, WeaponCustomChoice>) =>
    fetchNui<{ ok: boolean; message?: string }>('weaponCustomSave', customs, { ok: true }),
  cancel: () => fetchNui<unknown>('weaponCustomCancel', {}, {}),
};
