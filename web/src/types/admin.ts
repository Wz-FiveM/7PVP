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
  | 'announce' | 'clearLoot'
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
