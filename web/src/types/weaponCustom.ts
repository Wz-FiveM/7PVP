/** Custom d'une arme (client/modules/inventory/weapon_custom.lua) */
export interface WeaponCustomChoice {
  /** teinte GTA */
  tint: number;
  /** composant GTA de la finition, `false` : aucune */
  finish: string | false;
  /** accessoires posés (objets), seulement ceux débloqués */
  attachments: string[];
}

/** Accessoire que l'arme accepte, débloqué à `kills` zombies tués avec elle (config/weapon_custom.lua) */
export interface WeaponCustomAttachment {
  name: string;
  kills: number;
}

export interface WeaponCustomWeapon {
  /** objet de l'arme */
  name: string;
  label: string;
  tint: number;
  finish: string | false;
  /** accessoires posés (Lua envoie `{}` s'il n'y en a aucun) */
  fitted: string[] | Record<string, never>;
  /** zombies tués avec ce modèle */
  kills: number;
  tints: { id: number; label: string; hex: string }[];
  finishes: { component: string; label: string }[];
  /** accessoires que cette arme accepte, dans l'ordre des paliers */
  attachments: WeaponCustomAttachment[];
}

export type WeaponCustomPayload = { open: false } | { open: true; weapons: WeaponCustomWeapon[] };
