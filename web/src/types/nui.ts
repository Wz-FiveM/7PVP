import type { AdminSelf, NoclipInfo, NoclipKeyId } from './admin';
import type { CreatorPayload } from './appearance';
import type {
  ChatMessageData, EffectHud, GameConfig, GroupData, GroupInvite, GroupVital, HitEvent, KillfeedEntry, PauseInfo, DeathRecap, BountyEntry, GameClock, HordeState, ControlZoneHud, FreeroamWeapon, FreeroamVehicle, TeleportMenuData, NearServices, HelpNotification, InteractionItem, LobbyMode, MinimapAnchor, PlayerState, ToastKind, Vitals, ZoneInfo,
} from './game';

/** Messages envoyés par Lua via `Nui.send(action, data)` */
export type NuiMessage =
  | { action: 'sync'; data: PlayerState }
  | { action: 'zone'; data: ZoneInfo }
  | { action: 'vitals'; data: Vitals }
  | { action: 'hotbar'; data: { visible: boolean } }
  | { action: 'minimap'; data: MinimapAnchor }
  | { action: 'lobby'; data: { open: boolean; modes?: LobbyMode[] } }
  /** mode de jeu en cours, `false` au lobby */
  | { action: 'mode'; data: { mode: string | false } }
  | { action: 'chat'; data: { open: boolean } }
  | { action: 'admin'; data: { open: boolean; self?: AdminSelf } }
  | { action: 'noclip'; data: NoclipInfo }
  /** touches du noclip maintenues (envoyé seulement quand elles changent) */
  | { action: 'noclipHeld'; data: { held: NoclipKeyId[] } }
  | { action: 'chatMessage'; data: ChatMessageData }
  | { action: 'creator'; data: CreatorPayload }
  | { action: 'menu'; data: { open: boolean; inSafe: boolean; near?: NearServices; page?: string } }
  | { action: 'notify'; data: { text: string; kind: ToastKind } }
  | { action: 'killfeed'; data: KillfeedEntry }
  | { action: 'hit'; data: HitEvent }
  /** statut « en combat » : secondes restantes, 0 = terminé */
  | { action: 'combat'; data: { seconds: number } }
  /** groupe actuel, `false` sans groupe */
  | { action: 'group'; data: { group: GroupData | false } }
  | { action: 'groupInvite'; data: GroupInvite }
  | { action: 'groupVitals'; data: GroupVital[] }
  | { action: 'pause'; data: { open: boolean; info?: PauseInfo } }
  | { action: 'death'; data: { seconds: number; recap?: DeathRecap } }
  | { action: 'bounties'; data: BountyEntry[] }
  | { action: 'clock'; data: GameClock }
  | { action: 'controlZone'; data: { zone: ControlZoneHud | false } }
  | { action: 'freeroamMenu'; data: { open: boolean; pvp: boolean; weapons: FreeroamWeapon[]; vehicles: FreeroamVehicle[] } }
  | { action: 'freeroamPvp'; data: { pvp: boolean } }
  | { action: 'helpNotify'; data: { help: HelpNotification | false } }
  /** `items: false` : ciblage en cours (curseur affiché, pas encore de menu) */
  | { action: 'interaction'; data: { open: boolean; items?: InteractionItem[] | false } }
  | { action: 'horde'; data: { horde: HordeState | false } }
  /** effets à durée actifs (vide quand il n'y en a plus) */
  | { action: 'effects'; data: EffectHud[] }
  /** menu de téléportation entre zones safe (F1) */
  | { action: 'teleport'; data: { open: boolean } & Partial<TeleportMenuData> }
  /** attente avant la téléportation (hors zone safe), `false` = terminée ou annulée */
  | { action: 'teleportChannel'; data: { seconds: number | false } }
  | { action: 'alive'; data?: undefined };

/** Réponse du callback NUI `ready` */
export interface InitPayload {
  config: GameConfig;
  player?: PlayerState;
  zone: ZoneInfo;
}

/** Réponse des actions (achat, utilisation d'objet) */
export interface ActionResult {
  ok: boolean;
  message?: string;
}
