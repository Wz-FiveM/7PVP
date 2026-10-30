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
  banners: CodCardAsset[];
  emblems: CodCardAsset[];
  tagLength: number;
  keys: { streak: string; class: string; scoreboard: string };
}

export interface CodClass {
  name: string;
  primary: string;
  secondary: string;
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
}
export interface CodProfile {
  name: string;
  rank: number;
  maxRank: number;
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
  card: CodPlayerCardChoice;
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
  /** false en chacun pour soi */
  team: CodTeamId | false;
  kills: number;
  deaths: number;
  assists: number;
  score: number;
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
  | { kind: 'sites'; round: number; attackers: CodTeamId; bomb: { site: string; remaining: number } | false };

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
  summary?: { earned: number; bonus: number; rankBefore: number; rankAfter: number; unlocks: string[] };
  seconds: number;
}
export interface CodLeaderboardRow {
  name: string;
  rank: number;
  kills: number;
  deaths: number;
  wins: number;
}
export interface CodActionResult {
  ok: boolean;
  message?: string;
  profile?: CodProfile;
}
