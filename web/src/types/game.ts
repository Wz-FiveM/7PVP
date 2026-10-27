export type ZoneType = 'safe' | 'pve' | 'pvp';
export type ToastKind = 'info' | 'success' | 'error';
export type ItemType = 'weapon' | 'ammo' | 'consumable' | 'money';
export type ContainerId = 'bag' | 'protected';

export interface ZoneInfo {
  id?: string;
  label: string;
  type: ZoneType;
}

/** nom de l'objet -> quantité. Lua envoie `[]` pour un conteneur vide. */
export type ItemStacks = Record<string, number> | [];

export interface Inventory {
  bag: ItemStacks;
  protected: ItemStacks;
  /** objet assigné à chaque touche, `false` si vide */
  shortcuts: (string | false)[];
}

export interface PlayerState {
  name: string;
  money: number;
  xp: number;
  level: number;
  kills: number;
  deaths: number;
  npcKills: number;
  inventory: Inventory;
}

export interface ItemDefinition {
  label: string;
  type: ItemType;
  weight: number;
  weapon?: string;
  ammo?: string;
  heal?: number;
  armor?: number;
}

export interface ContainerDefinition {
  label: string;
  capacity: number;
}

export interface ShopEntry {
  item: string;
  count: number;
  price: number;
}

export interface GameConfig {
  shop: ShopEntry[];
  items: Record<string, ItemDefinition>;
  containers: Record<ContainerId, ContainerDefinition>;
  shortcutSlots: number;
  xpPerLevel: number;
}

export interface LeaderboardRow {
  name: string;
  level: number;
  xp: number;
  kills: number;
  deaths: number;
  npcKills: number;
  online: boolean;
}

export interface KillfeedEntry {
  killer?: string;
  victim: string;
}

export interface Toast {
  id: number;
  text: string;
  kind: ToastKind;
}

export interface KillfeedItem extends KillfeedEntry {
  id: number;
}

/** État du ped envoyé en continu par client/modules/hud/hud.lua */
export interface Vitals {
  /** 0..maxHealth */
  health: number;
  maxHealth: number;
  /** 0..100 */
  armor: number;
  /** objet arme en main, `false` si aucune */
  weapon: string | false;
  clip: number;
  reserve: number;
}

/** Mode proposé au lobby (voir config/lobby.lua) */
export interface LobbyMode {
  id: string;
  label: string;
  tagline: string;
  description: string;
  /** false : affiché comme « bientôt disponible » */
  enabled: boolean;
  players: number;
}

/** Position de la minimap GTA, en fractions de l'écran (0 à 1) */
export interface MinimapAnchor {
  visible: boolean;
  left: number;
  right: number;
  top: number;
  bottom: number;
}

/** Une pile d'objets prête à afficher */
export interface ItemStack {
  name: string;
  count: number;
  item: ItemDefinition;
}
