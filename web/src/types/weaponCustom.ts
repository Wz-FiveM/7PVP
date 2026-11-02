/** Custom d'une arme (client/modules/inventory/weapon_custom.lua) */
export interface WeaponCustomChoice {
  /** teinte GTA */
  tint: number;
  /** composant GTA de la finition, `false` : aucune */
  finish: string | false;
}

export interface WeaponCustomWeapon extends WeaponCustomChoice {
  /** objet de l'arme */
  name: string;
  label: string;
  tints: { id: number; label: string; hex: string }[];
  finishes: { component: string; label: string }[];
  /** accessoires (objets) que cette arme accepte */
  attachments: string[];
}

export type WeaponCustomPayload = { open: false } | { open: true; weapons: WeaponCustomWeapon[] };
