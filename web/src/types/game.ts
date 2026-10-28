export type ZoneType = 'safe' | 'pve' | 'pvp';
export type ToastKind = 'info' | 'success' | 'error';
export type ItemType = 'weapon' | 'ammo' | 'consumable' | 'money' | 'attachment' | 'material' | 'vehicle';
export type ContainerId = 'bag' | 'protected' | 'stash';

export interface ZoneInfo {
  id?: string;
  label: string;
  type: ZoneType;
}

/** nom de l'objet -> quantité. Lua envoie `[]` pour un conteneur vide. */
export type ItemStacks = Record<string, number> | [];

/** Butin ouvert comme un inventaire (largage) : on y prend les objets à la main */
export interface LootContainer {
  id: number;
  label: string;
  items: ItemStacks;
}

export interface Inventory {
  bag: ItemStacks;
  protected: ItemStacks;
  /** coffre : seulement en zone safe */
  stash: ItemStacks;
  /** objet assigné à chaque touche, `false` si vide */
  shortcuts: (string | false)[];
  /** arme -> accessoires fixés (Lua envoie `[]` s'il n'y en a aucun) */
  attachments?: Record<string, Record<string, boolean>> | [];
}

export interface PlayerState {
  /** server id du joueur */
  source: number;
  name: string;
  money: number;
  xp: number;
  level: number;
  kills: number;
  deaths: number;
  npcKills: number;
  inventory: Inventory;
  /** kills de joueurs depuis la dernière mort */
  streak: number;
  /** prime sur sa tête ($), 0 = aucune */
  bounty: number;
  contracts?: ContractsState;
  season?: SeasonStats;
}

export interface ItemDefinition {
  label: string;
  type: ItemType;
  weight: number;
  weapon?: string;
  ammo?: string;
  heal?: number;
  armor?: number;
  /** (véhicules) modèle GTA */
  model?: string;
  /** image web/public/items/<image>.png, si elle ne porte pas le nom de l'objet */
  image?: string;
}

export interface ContainerDefinition {
  label: string;
  capacity: number;
  /** utilisable seulement en zone safe (coffre) */
  safeOnly?: boolean;
}

export interface ShopEntry {
  item: string;
  count: number;
  price: number;
  /** niveau minimum (défaut 1) */
  level?: number;
}

/** Recette de fabrication (config/crafting.lua) */
export interface Recipe {
  id: string;
  result: { item: string; count: number };
  ingredients: Record<string, number>;
  level?: number;
}

export interface Contract {
  id: string;
  label: string;
  goal: number;
  progress: number;
  done: boolean;
  reward: { money: number; xp: number };
}

/** Contrats du jour ; `resetIn` en secondes au moment de la synchro */
export interface ContractsState {
  list: Contract[];
  resetIn: number;
}

export interface GameConfig {
  shop: ShopEntry[];
  items: Record<string, ItemDefinition>;
  containers: Record<ContainerId, ContainerDefinition>;
  shortcutSlots: number;
  xpPerLevel: number;
  groupMaxSize?: number;
  /** nom de la touche du menu (ex : VERR. MAJ) */
  menuKey?: string;
  /** accessoire -> { arme -> composant GTA } */
  attachments?: Record<string, Record<string, string>>;
  recipes?: Recipe[];
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

/** Effet à durée d'un stimulant (client/modules/effects/effects.lua) */
export interface EffectHud {
  id: string;
  label: string;
  /** nom court affiché sous l'icône */
  short: string;
  /** image web/public/items/<icon>.png */
  icon: string;
  /** secondes restantes à l'envoi */
  remaining: number;
  /** durée totale, en secondes */
  duration: number;
}

/** Dégâts infligés à un joueur, confirmés par le serveur (client/modules/combat/hits.lua) */
export interface HitEvent {
  /** total vie + armure */
  damage: number;
  /** part encaissée par l'armure */
  armor: number;
  headshot: boolean;
  fatal: boolean;
}

export interface KillfeedEntry {
  killer?: string;
  victim: string;
  /** `disconnect` : la victime s'est déconnectée en plein combat */
  reason?: 'disconnect';
  /** objet de l'arme du coup mortel (image en silhouette) */
  weapon?: string;
  headshot?: boolean;
  /** server ids : la ligne est mise en avant si le joueur local est concerné */
  killerId?: number;
  victimId?: number;
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

/** Message du chat (envoyé par server/modules/chat/chat_service.lua) */
export interface ChatMessageData {
  kind: 'player' | 'system';
  author?: string;
  text: string;
  /** horodatage serveur, en secondes */
  time: number;
}

export interface ChatMessage extends ChatMessageData {
  id: number;
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

/** Groupe (escouade) du joueur, envoyé par server/modules/group/group_service.lua */
export interface GroupData {
  id: number;
  /** server id du chef */
  leader: number;
  members: { id: number; name: string }[];
}

/** Vie d'un coéquipier, lue par le serveur (connue à toute distance) */
export interface GroupVital {
  id: number;
  health: number | false;
  armor: number;
  dead?: boolean;
}

export interface GroupInvite {
  from: number;
  fromName: string;
}

/** Informations du menu pause (client/modules/pause/pause.lua) */
export interface PauseInfo {
  name: string;
  serverId: number;
  /** mode en cours ('pvp', 'freeroam') */
  mode: string | null;
  level: number;
  kills: number;
  deaths: number;
  npcKills: number;
  isAdmin: boolean;
  keys: { menu: string; hotbar: string; chat: string; admin: string; noclip: string; teleport: string };
}

/** Course poursuite (server/modules/activities/chase_service.lua) */
export type ChaseRole = 'thief' | 'cop';
export interface ChaseScores {
  me: number;
  opponent: number;
}
export interface ChaseHudData {
  round: number;
  role: ChaseRole;
  scores: ChaseScores;
  opponent: string;
  countdown: number;
  roundTime: number;
  escapeDistance: number;
  arrestTime: number;
}
export interface ChaseStateData {
  remaining: number;
  /** santé de son véhicule en % (au-dessous de 0 : manche perdue), absente à pied */
  health?: number;
  /** avertissements anti-PIT sur la partie */
  warns?: number;
  maxWarns?: number;
  /** immobilisation du voleur, de 0 à 1 */
  arrest: number;
}

/** CVC (server/modules/activities/cvc_service.lua) : scores et survivants vus par son équipe */
export interface CvcScores {
  us: number;
  them: number;
}
export interface CvcHudData {
  round: number;
  team: string;
  teamId: 'alpha' | 'bravo';
  arena: string;
  countdown: number;
  roundTime: number;
  roundsToWin: number;
  scores: CvcScores;
}
export interface CvcStateData {
  remaining: number;
  alive: CvcScores;
}

/** Mode de jeu du Freeroam, lancé depuis son PNJ (Config.FreeroamActivities) */
export interface ActivityInfo {
  id: string;
  label: string;
  tagline?: string;
  description?: string;
  icon?: string;
  /** false : « Bientôt disponible » */
  enabled: boolean;
}

/** Zone safe proposée dans le menu de téléportation (F1) */
export interface TeleportZone {
  id: string;
  label: string;
  description?: string;
  /** distance au joueur, en mètres */
  distance: number;
  /** le joueur est dans cette zone */
  current: boolean;
}

export interface TeleportMenuData {
  zones: TeleportZone[];
  /** secondes avant la prochaine téléportation */
  cooldown: number;
  /** secondes d'attente avant le départ (0 depuis une zone safe) */
  channel: number;
  /** une téléportation est déjà en attente */
  pending: boolean;
  key: string;
}

export type PauseAction = 'map' | 'settings' | 'menu' | 'lobby' | 'quit';

/** Dégâts échangés avec un joueur pendant une vie */
export interface DamageSummary {
  damage: number;
  hits: number;
  headshots: number;
}

/** Récapitulatif de mort (server/modules/combat/combat_service.lua) */
export interface DeathRecap {
  killer?: string;
  killerId?: number;
  /** arme ou cause (« Chute », « Véhicule »...) */
  weapon?: string;
  zombie?: boolean;
  /** mètres */
  distance?: number;
  killerHealth?: number;
  killerArmor?: number;
  /** dégâts qu'il t'a infligés / que tu lui as infligés */
  taken?: DamageSummary;
  dealt?: DamageSummary;
}

/** Joueur dont la tête est mise à prix */
export interface BountyEntry {
  id: number;
  name: string;
  amount: number;
  streak: number;
}

/** Heure du jeu (shared/modules/clock.lua) */
export interface GameClock {
  hour: number;
  minute: number;
  night: boolean;
}

/** Horde en cours (server/modules/pve/horde_service.lua) */
export interface HordeState {
  zoneId: string;
  label: string;
  /** secondes restantes */
  endsIn: number;
  kills: number;
}

export type LeaderboardScope = 'season' | 'previous' | 'all';

/** Stats de la saison en cours du joueur */
export interface SeasonStats {
  label: string;
  kills: number;
  deaths: number;
  npcKills: number;
}

/** Zone de contrôle où se trouve le joueur (client/modules/control/control.lua) */
export interface ControlZoneHud {
  label: string;
  ownerLabel: string | false;
  mine: boolean;
  capturing: boolean;
  enemyCapturing: boolean;
  /** 0 à 100 */
  progress: number;
  contested: boolean;
}

/** Menu du Freeroam (config/freeroam.lua) */
export interface FreeroamWeapon {
  weapon: string;
  label: string;
}

export interface FreeroamVehicle {
  model: string;
  label: string;
  category: string;
}

export interface FreeroamState {
  menuOpen: boolean;
  pvp: boolean;
  weapons: FreeroamWeapon[];
  vehicles: FreeroamVehicle[];
}

/** Services des PNJ de la zone safe à portée (config/npcs.lua) */
export interface NearServices {
  stash?: boolean;
  shop?: boolean;
  clothing?: boolean;
  crafting?: boolean;
  contracts?: boolean;
  market?: boolean;
}

/** Notification d'aide (client/modules/nui/help_notify.lua) */
export interface HelpNotification {
  key: string;
  text: string;
}

/** Annonce de la place de marché */
export interface MarketListing {
  id: number;
  item: string;
  count: number;
  /** prix du lot */
  price: number;
  sellerName: string;
  /** annonce du joueur local */
  mine: boolean;
}

export interface MarketState {
  listings: MarketListing[];
  /** argent des ventes à récupérer */
  balance: number;
  /** taxe sur les ventes (0.05 = 5 %) */
  fee: number;
  maxListings: number;
}

/** Élément du menu d'interaction (client/modules/interaction/interaction_menu.lua) */
export interface InteractionItem {
  id: string;
  kind: 'info' | 'action' | 'toggle' | 'submenu' | 'separator';
  label?: string;
  icon?: import('../components/icons/Icon').IconName;
  /** texte à droite (info) */
  value?: string;
  /** case cochée (toggle) */
  checked?: boolean;
  disabled?: boolean;
  children?: InteractionItem[];
}
