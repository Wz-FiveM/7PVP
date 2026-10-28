/** Joueur listé dans le panneau admin (server/modules/admin/admin_service.lua) */
export interface AdminPlayer {
  id: number;
  name: string;
  /** mode en cours, `false` au lobby */
  mode: string | false;
  dead: boolean;
  money: number;
  level: number;
}

/** Options personnelles de l'admin qui s'activent / se coupent */
export type AdminToggle = 'noclip' | 'god' | 'invisible';

/** Options personnelles de l'admin */
export interface AdminSelf extends Record<AdminToggle, boolean> {
  /** nom du joueur regardé en mode spectateur, `false` sinon */
  spectating: string | false;
}

export type AdminAction =
  | 'giveItem' | 'giveMoney' | 'heal' | 'revive' | 'kill' | 'freeze'
  | 'gotoPlayer' | 'bringPlayer' | 'sendToLobby' | 'kick' | 'spectate' | 'spectateStop'
  | 'announce' | 'clearLoot' | 'airdrop' | 'horde'
  | 'noclip' | 'god' | 'invisible' | 'tpWaypoint' | 'spawnVehicle' | 'deleteVehicle' | 'gotoPoint';

export interface AdminActionPayload {
  action: AdminAction;
  target?: number;
  [key: string]: unknown;
}

export interface AdminActionResult {
  ok: boolean;
  message?: string;
  self?: AdminSelf;
}

/** Touches de l'aide du noclip (client/modules/admin/noclip.lua, Noclip.HELP_KEYS) */
export type NoclipKeyId = 'forward' | 'left' | 'back' | 'right' | 'up' | 'down' | 'fast' | 'slow';

/** Noclip actif : touches affichées et vitesses */
export interface NoclipInfo {
  active: boolean;
  /** libellé de chaque touche, selon la disposition du clavier du joueur */
  keys?: Record<NoclipKeyId, string>;
  toggleKey: string;
  /** vitesse de base en m/s */
  speed: number;
  fastMultiplier: number;
  slowMultiplier: number;
}

/** Ligne d'une table de butin : quantité tirée entre min et max, chance en % */
export interface LootDrop {
  item: string;
  count: [number, number];
  chance: number;
}

/** Table de butin modifiable (server/modules/loot/loot_config_service.lua) */
export interface LootTableData {
  name: string;
  label: string;
  /** argent tiré entre min et max, `false` sans argent */
  money: [number, number] | false;
  drops: LootDrop[];
  /** zones (et largages) qui utilisent cette table */
  usedBy: string[];
  /** modifiée depuis le panneau (différente de config/loot.lua) */
  modified: boolean;
}

export interface LootZoneData {
  id: string;
  label: string;
  loot: string;
}

export interface LootAdminData {
  ok: boolean;
  message?: string;
  tables: LootTableData[];
  zones: LootZoneData[];
  items: { name: string; label: string; type: string }[];
}

/** Véhicule d'une liste du Freeroam (server/modules/freeroam/freeroam_config_service.lua) */
export interface FreeroamVehicle {
  model: string;
  label: string;
  /** onglet du menu Freeroam (liste avec catégories uniquement) */
  category?: string;
}

/** Position sur la carte ; `w` = cap en degrés */
export interface MapPoint {
  x: number;
  y: number;
  z: number;
  w: number;
}

/** Départs des deux équipes dans une arène du CVC */
export interface CvcArenaSpawns {
  label: string;
  spawns: [MapPoint, MapPoint];
}

/** PNJ d'un mode de jeu, ou tableau du classement (shared/modules/freeroam_positions.lua) */
export interface FreeroamPlace {
  key: string;
  label: string;
  coords: MapPoint;
}

/** Réglage de l'onglet « Freeroam » (server/modules/freeroam/freeroam_config_service.lua) */
export type FreeroamSetting = {
  name: string;
  group: 'vehicles' | 'positions';
  label: string;
  hint: string;
  /** différent du fichier de config */
  modified: boolean;
} & (
  | { kind: 'vehicles'; category: boolean; value: FreeroamVehicle[] }
  | { kind: 'model'; category: false; value: string }
  | { kind: 'points'; category: false; value: MapPoint[] }
  | { kind: 'arenas'; category: false; value: CvcArenaSpawns[] }
  | { kind: 'places'; category: false; value: FreeroamPlace[] }
);

export type ChasePhase = 'vote' | 'countdown' | 'running' | 'pause' | 'ended';

/** Course poursuite en cours (ChaseService.describeMatches) */
export interface ChaseMatchInfo {
  id: number;
  round: number;
  phase: ChasePhase;
  players: {
    id: number;
    name: string;
    /** `false` pendant le vote */
    role: 'thief' | 'cop' | false;
    score: number;
    warns: number;
  }[];
}

export interface FreeroamAdminData {
  ok: boolean;
  message?: string;
  settings: FreeroamSetting[];
  chases: ChaseMatchInfo[];
  /** joueurs dans la file de la course poursuite */
  chaseQueue: number;
}
