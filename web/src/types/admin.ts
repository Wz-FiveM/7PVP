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

/** Options personnelles de l'admin */
export interface AdminSelf {
  noclip: boolean;
  god: boolean;
  invisible: boolean;
}

export type AdminAction =
  | 'giveItem' | 'giveMoney' | 'heal' | 'revive' | 'kill' | 'freeze'
  | 'gotoPlayer' | 'bringPlayer' | 'sendToLobby' | 'kick'
  | 'announce' | 'clearLoot' | 'airdrop' | 'horde'
  | 'noclip' | 'god' | 'invisible' | 'tpWaypoint' | 'spawnVehicle' | 'deleteVehicle';

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
