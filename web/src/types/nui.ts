import type { AdminSelf, NoclipInfo, NoclipKeyId } from './admin';
import type { CreatorPayload } from './appearance';
import type { LanguageInfo } from '../i18n';
import type {
  CaseReelEntry, ChatMessageData, EffectHud, GameConfig, GroupData, GroupInvite, GroupVital, HitEvent, KillfeedEntry, PauseInfo, DeathRecap, BountyEntry, GameClock, HordeState, ControlZoneHud, FreeroamWeapon, FreeroamVehicle, TeleportMenuData, LootContainer, ActivityInfo, ChaseHudData, ChaseStateData, EloChange,
  ChaseScores, CvcHudData, CvcStateData, CvcScores, GunfightHudData, GunfightScores, GungameEndData, GungameHudData, GungameKillData, GungameStateData, SpeedometerData, NearServices, HelpNotification, InteractionItem, LobbyMode, MinimapAnchor, PlayerState, ToastKind, TradeData, Vitals, ZoneInfo,
} from './game';
import type {
  CodCatalog, CodDeadData, CodEndData, CodHudData, CodKillData, CodProfile, CodQueueData, CodRoundEndData, CodStateData, CodStreakState,
} from './cod';

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
  | { action: 'locale'; data: LocalePayload }
  | { action: 'killfeed'; data: KillfeedEntry }
  | { action: 'hit'; data: HitEvent }
  /** statut « en combat » : secondes restantes, 0 = terminé */
  | { action: 'combat'; data: { seconds: number } }
  /** groupe actuel, `false` sans groupe */
  | { action: 'group'; data: { group: GroupData | false } }
  | { action: 'groupInvite'; data: GroupInvite }
  /** échange en cours entre joueurs (à droite de l'inventaire), `false` quand il se termine */
  | { action: 'trade'; data: { trade: TradeData | false } }
  | { action: 'groupVitals'; data: GroupVital[] }
  | { action: 'pause'; data: { open: boolean; info?: PauseInfo } }
  | { action: 'death'; data: { seconds: number; recap?: DeathRecap } }
  | { action: 'bounties'; data: BountyEntry[] }
  | { action: 'clock'; data: GameClock }
  | { action: 'controlZone'; data: { zone: ControlZoneHud | false } }
  | { action: 'freeroamMenu'; data: { open: boolean; pvp: boolean; weapons: FreeroamWeapon[]; vehicles: FreeroamVehicle[] } }
  | { action: 'freeroamPvp'; data: { pvp: boolean } }
  | { action: 'freeroamActivity'; data: { activity: { label: string; tagline: string } | false } }
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
  /** butin ouvert (largage) à droite de l'inventaire, open à false pour le fermer */
  | { action: 'lootContainer'; data: { open: boolean } & Partial<LootContainer> }
  /** fenêtre d'un mode de jeu du Freeroam (PNJ de la zone safe) */
  | { action: 'activity'; data: { open: boolean; activity?: ActivityInfo } }
  /** course poursuite : file d'attente, vote, HUD de manche, résultats */
  | { action: 'chaseQueue'; data: { count: number; needed?: number } }
  | { action: 'chaseVote'; data: { open: boolean; vehicles?: { model: string; label: string }[]; seconds?: number; opponent?: string } }
  | { action: 'chaseHud'; data: { open: boolean } & Partial<ChaseHudData> }
  | { action: 'chaseState'; data: ChaseStateData }
  | { action: 'chaseBanner'; data: { won: boolean; reason: string; round: number; scores: ChaseScores } }
  | { action: 'chaseEnd'; data: { result: 'won' | 'lost' | 'draw'; reason?: string; scores: ChaseScores; elo?: EloChange } }
  /** CVC : file d'attente, HUD de manche, hors zone, résultats */
  | { action: 'cvcQueue'; data: { count: number; needed?: number; max?: number; startIn?: number } }
  | { action: 'cvcHud'; data: { open: boolean } & Partial<CvcHudData> }
  | { action: 'cvcState'; data: CvcStateData }
  | { action: 'cvcOutside'; data: { outside: boolean } }
  | { action: 'cvcBanner'; data: { result: 'won' | 'lost' | 'draw'; reason: string; round: number; scores: CvcScores } }
  | { action: 'cvcEnd'; data: { result: 'won' | 'lost' | 'draw'; reason?: string; scores: CvcScores; elo?: EloChange } }
  /** 1VS1 (GunFight, Bike) : file d'attente, HUD de manche, hors zone, résultats */
  | { action: 'gunfightQueue'; data: { count: number; needed?: number; label?: string } }
  | { action: 'gunfightHud'; data: { open: boolean } & Partial<GunfightHudData> }
  | { action: 'gunfightState'; data: { remaining: number } }
  | { action: 'gunfightOutside'; data: { outside: boolean } }
  | { action: 'gunfightBanner'; data: { result: 'won' | 'lost' | 'draw'; reason: string; round: number; scores: GunfightScores } }
  | { action: 'gunfightEnd'; data: { result: 'won' | 'lost' | 'draw'; reason?: string; scores: GunfightScores; elo?: EloChange } }
  /** Gungame : file d'attente, HUD de partie, changements de niveau, kills, hors zone, résultats */
  | { action: 'gungameQueue'; data: { count: number; needed?: number; max?: number; startIn?: number } }
  | { action: 'gungameHud'; data: { open: boolean } & Partial<GungameHudData> }
  | { action: 'gungameState'; data: GungameStateData }
  | { action: 'gungameLevel'; data: { level: number; reason: 'kill' | 'knifed' | 'suicide' } }
  | { action: 'gungameSpawn'; data: { protection: number } }
  | { action: 'gungameKill'; data: GungameKillData }
  | { action: 'gungameOutside'; data: { outside: boolean } }
  | { action: 'gungameEnd'; data: GungameEndData }
  /** Call of Duty : menu du mode, file et vote, HUD de partie, résultats */
  | { action: 'codMenu'; data: { open: boolean; profile?: CodProfile; catalog?: CodCatalog } }
  | { action: 'codQueue'; data: CodQueueData }
  | { action: 'codPicker'; data: { open: boolean; profile?: CodProfile } }
  | { action: 'codHud'; data: { open: boolean } & Partial<CodHudData> }
  | { action: 'codState'; data: CodStateData }
  | { action: 'codKill'; data: CodKillData }
  | { action: 'codScore'; data: { xp: number; label: string } }
  | { action: 'codStreak'; data: CodStreakState }
  | { action: 'codStreakEarned'; data: { label: string } }
  | { action: 'codNotice'; data: { text: string; friendly?: boolean } }
  | { action: 'codDead'; data: CodDeadData }
  | { action: 'codSpawn'; data: { protection: number } }
  | { action: 'codOutside'; data: { outside: boolean } }
  | { action: 'codScoreboard'; data: { open: boolean } }
  | { action: 'codAction'; data: { kind: string | false; seconds?: number } }
  | { action: 'codRoundEnd'; data: CodRoundEndData }
  | { action: 'codRoundStart'; data: { countdown: number } }
  | { action: 'codNuke'; data: { seconds: number } }
  | { action: 'codJam'; data: { active: boolean } }
  | { action: 'codPredator'; data: { state: 'opening' | 'flying' | 'lost' | false; seconds?: number } }
  | { action: 'codPredatorStatus'; data: { altitude: number; boost: boolean } }
  | { action: 'codEnd'; data: CodEndData }
  | { action: 'speedometer'; data: SpeedometerData }
  | { action: 'alive'; data?: undefined };

/** Réponse du callback NUI `ready` */
export interface InitPayload {
  /** langue du joueur et langues disponibles (Config.Locale) */
  locale?: LocalePayload;
  config: GameConfig;
  player?: PlayerState;
  zone: ZoneInfo;
  /** mode en cours, `false` au lobby */
  mode?: string | false;
  /** lobby déjà ouvert avant que la page soit prête */
  lobby?: { open: boolean; modes: LobbyMode[] };
}

export interface LocalePayload {
  lang: string;
  languages: LanguageInfo[];
}

/** Réponse des actions (achat, utilisation d'objet) */
export interface ActionResult {
  ok: boolean;
  message?: string;
}

/** Réponse de l'ouverture d'une caisse : roulette déjà tirée par le serveur (`winner` 1-based) */
export interface CaseOpenResult extends ActionResult {
  reel?: CaseReelEntry[];
  winner?: number;
  duration?: number;
}
