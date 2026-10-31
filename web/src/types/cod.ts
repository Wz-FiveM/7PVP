/** Mode Call of Duty (server/modules/cod/, config/cod.lua) */

export interface CodCatalogEntry {
  id: string;
  label: string;
  category: string;
  rank: number;
  ammo: number;
}
export interface CodPerk {
  id: string;
  tier: number;
  rank: number;
  label: string;
  description: string;
}
export interface CodStreakInfo {
  id: string;
  kills: number;
  rank: number;
  label: string;
  description: string;
}
export interface CodPlaylist {
  id: string;
  label: string;
  short: string;
  description: string;
  teams: boolean;
  minPlayers: number;
  maxPlayers: number;
  time: number;
  scoreLimit: number;
}
/** Bannière ou emblème de la carte de joueur (config/cod_player_cards.lua) */
export interface CodCardAsset {
  id: string;
  label: string;
  rank: number;
  /** niveau de Prestige requis */
  prestige?: number;
}
/** Personnage à porter (config/cod_operators.lua) */
export interface CodOperatorEntry {
  id: string;
  label: string;
  universe: string;
  /** prix en points boutique */
  price: number;
  /** auteur du modèle */
  credit: string;
  /** le modèle est dans le jeu (renseigné par le client) */
  available?: boolean;
}
/** Accessoire d'arme (config/cod_gunsmith.lua) */
export interface CodAttachment {
  id: string;
  slot: string;
  /** niveau de l'arme qui le débloque */
  level: number;
  label: string;
  description: string;
}
/** Camouflage d'arme : ce qu'il faut avoir fait avec elle pour le débloquer */
export interface CodCamo {
  id: string;
  tint: number;
  /** pastille du menu */
  color: string;
  label: string;
  kills?: number;
  headshots?: number;
}
export interface CodGunsmithCatalog {
  levels: { max: number; base: number; growth: number };
  slots: { id: string; label: string }[];
  attachments: CodAttachment[];
  camos: CodCamo[];
  /** arme -> accessoire -> composant de GTA */
  weapons: Record<string, Record<string, string>>;
}
export interface CodCatalog {
  playlists: CodPlaylist[];
  primary: CodCatalogEntry[];
  secondary: CodCatalogEntry[];
  equipment: CodCatalogEntry[];
  perks: CodPerk[];
  streaks: CodStreakInfo[];
  maxStreaks: number;
  classNameLength: number;
  gunsmith: CodGunsmithCatalog;
  banners: CodCardAsset[];
  emblems: CodCardAsset[];
  tagLength: number;
  operators: CodOperatorEntry[];
  maxPrestige: number;
  /** jetons gagnés à chaque Prestige */
  prestigeTokens: number;
  keys: { streak: string; class: string; scoreboard: string };
}

export interface CodWeaponMods {
  attachments: string[];
  /** false : pas de camouflage */
  camo: string | false;
}
/** Progression d'une arme, absente tant qu'elle n'a fait aucun kill */
export interface CodWeaponProgress {
  kills: number;
  headshots: number;
  level: number;
  into: number;
  /** 0 au niveau maximum */
  needed: number;
}
export interface CodClass {
  name: string;
  primary: string;
  secondary: string;
  primaryMods: CodWeaponMods;
  secondaryMods: CodWeaponMods;
  /** false : pas d'équipement */
  equipment: string | false;
  /** un atout par niveau (1, 2, 3) */
  perks: string[];
}
/** Choix du joueur */
export interface CodPlayerCardChoice {
  banner: string;
  emblem: string;
  /** tag de clan, peut être vide */
  tag: string;
}
/** Carte telle que la voient les autres joueurs */
export interface CodPlayerCardData extends CodPlayerCardChoice {
  name: string;
  rank: number;
  prestige: number;
}
export interface CodProfile {
  name: string;
  rank: number;
  maxRank: number;
  /** 0 : pas encore passé en Prestige */
  prestige: number;
  /** jetons de Prestige à dépenser */
  tokens: number;
  /** armes, atouts et séries gardés pour toujours avec un jeton */
  permanent: string[];
  canPrestige: boolean;
  /** XP de tous les Prestiges */
  xp: number;
  xpInto: number;
  /** 0 au rang maximum */
  xpNeeded: number;
  kills: number;
  deaths: number;
  assists: number;
  wins: number;
  losses: number;
  bestStreak: number;
  selected: number;
  classes: CodClass[];
  streaks: string[];
  weapons: Record<string, CodWeaponProgress>;
  card: CodPlayerCardChoice;
  /** personnage porté ; false : celui du joueur */
  operator: string | false;
  /** personnages achetés */
  ownedOperators: string[];
  /** jours de VIP restants, 0 sans VIP */
  vipDays: number;
}

export interface CodMapVote {
  id: string;
  label: string;
  place: string;
  votes: number;
}
/** count = 0 : pas dans la file */
export interface CodQueueData {
  count: number;
  playlist?: string;
  names?: string[];
  cards?: CodPlayerCardData[];
  needed?: number;
  max?: number;
  startIn?: number | false;
  maps?: CodMapVote[] | false;
  vote?: string | false;
}

export type CodTeamId = 'alpha' | 'bravo';

export interface CodBoardEntry {
  id: number;
  name: string;
  rank: number;
  prestige: number;
  /** false en chacun pour soi */
  team: CodTeamId | false;
  kills: number;
  deaths: number;
  assists: number;
  score: number;
  /** score en chacun pour soi : les kills, ou les armes passées en Course aux armes */
  points?: number;
  alive: boolean;
}
export interface CodHudData {
  self: number;
  playlist: { id: string; label: string; short: string; scoreLimit: number };
  map: { label: string; place: string };
  team: CodTeamId | false;
  teams: { id: CodTeamId; label: string }[];
  countdown: number;
  remaining: number;
}
/** at : Date.now() à la réception, pour décompter `remaining` */
export type CodHudState = CodHudData & { at: number };
export interface CodFlag {
  id: string;
  owner: CodTeamId | false;
  capturing: CodTeamId | false;
  progress: number;
}
export type CodObjective =
  | { kind: 'flags'; flags: CodFlag[] }
  | { kind: 'sites'; round: number; attackers: CodTeamId; bomb: { site: string; remaining: number } | false }
  /** Élimination confirmée : les plaques ne se voient que dans le monde */
  | { kind: 'tags' }
  /** Course aux armes : nombre d'armes à passer */
  | { kind: 'gun'; levels: number };

export interface CodStateData {
  phase: string;
  remaining: number;
  scores: Record<CodTeamId, number>;
  board: CodBoardEntry[];
  objective?: CodObjective;
}
export interface CodKillData {
  /** Absent : mort sans tueur (chute, hors zone) */
  killer?: string;
  killerTeam?: CodTeamId | false;
  killerId?: number;
  /** Carte de la victime, à montrer au tueur */
  victimCard?: CodPlayerCardData;
  victim: string;
  victimTeam: CodTeamId | false;
  /** Arme du coup mortel (image de web/public/items) */
  weapon?: string;
  /** Série à l'origine du kill : son pictogramme remplace l'arme */
  streak?: string;
  headshot: boolean;
}
/** Télémétrie d'une série pilotée */
export interface CodTabletStatus {
  altitude?: number;
  boost?: boolean;
  /** m/s */
  speed?: number;
  /** secondes avant l'impact */
  impact?: number;
  /** cap de la caméra, en degrés du jeu */
  heading?: number;
  /** m jusqu'au point visé */
  range?: number;
  /** position du point visé */
  x?: number;
  y?: number;
  /** inclinaison de la caméra, en degrés */
  pitch?: number;
  /** m : zone touchée par l'arme */
  radius?: number;
  weapon?: string;
  ready?: number;
  remaining?: number;
  firing?: boolean;
}
export interface CodMedalData {
  id: string;
  label: string;
}
/** Carte à droite de l'écran : exploit ou série déployée par un joueur */
export interface CodCardData extends CodMedalData {
  kind: 'medal' | 'streak';
  name: string;
  /** Bannière de la carte de joueur */
  banner: string;
  friendly: boolean;
}
export interface CodStreakState {
  streak: number;
  items: { id: string; label: string }[];
  /** séries choisies, de la moins chère à la plus chère ; kills : ce que demande le joueur (avec Détermination) */
  slots: { id: string; label: string; kills: number }[];
}
export interface CodDeadData {
  killer?: string;
  weapon?: string;
  /** secondes, false : pas de réapparition avant la prochaine manche */
  respawn: number | false;
  /** Carte du tueur */
  card?: CodPlayerCardData;
  /** une kill cam va commencer : la réapparition attendra sa fin */
  killcam?: boolean;
}
export interface CodKillcamData {
  open: boolean;
  killer?: string;
  weapon?: string;
  /** Carte du tueur */
  card?: CodPlayerCardData;
  /** touche pour passer */
  key?: string;
  /** kill cam finale, vue par tous les joueurs */
  final?: boolean;
}
export interface CodRoundEndData {
  result: 'won' | 'lost';
  reason: string;
  scores: Record<CodTeamId, number>;
}
/** Écran de choix de classe à l'arrivée dans une partie */
export interface CodLoadoutData {
  seconds: number;
  at: number;
  /** texture du portrait du personnage, absent s'il n'a pas pu être pris */
  portrait?: string;
}
export interface CodLoadingData {
  map: { label: string; place: string };
  playlist: string;
  tip: string;
}

export interface CodEndData {
  result: 'won' | 'lost' | 'draw';
  reason: string;
  team: CodTeamId | false;
  scores: Record<CodTeamId, number> | false;
  board: CodBoardEntry[];
  summary?: {
    earned: number;
    bonus: number;
    rankBefore: number;
    rankAfter: number;
    prestige: number;
    canPrestige: boolean;
    unlocks: string[];
    /** accessoires et camouflages débloqués pendant la partie */
    weaponUnlocks: { weapon: string; label: string }[];
  };
  seconds: number;
}
export interface CodLeaderboardRow {
  name: string;
  rank: number;
  prestige: number;
  kills: number;
  deaths: number;
  wins: number;
}
export interface CodActionResult {
  ok: boolean;
  message?: string;
  profile?: CodProfile;
}
