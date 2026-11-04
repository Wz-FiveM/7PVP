/** Mode Sabotage (voir config/tactical.lua et client/modules/tactical/) */

export type TacTeam = 'alpha' | 'bravo';
export type TacSlot = 'c' | 'q' | 'x';

export interface TacAbility {
  id: string;
  label: string;
  description: string;
  /** prix d'une charge (capacités achetables) */
  price?: number;
  /** charges rendues à chaque manche */
  free?: number;
  max?: number;
  /** points d'ultime nécessaires */
  cost?: number;
}

export interface TacRole {
  id: string;
  label: string;
  description: string;
  abilities: Record<TacSlot, TacAbility>;
}

export interface TacWeapon {
  id: string;
  label: string;
  category: string;
  slot: 'primary' | 'secondary';
  price: number;
  ammo: number;
}

export interface TacArmor {
  id: string;
  label: string;
  price: number;
  value: number;
}

export interface TacCatalog {
  roles: TacRole[];
  weapons: TacWeapon[];
  armor: TacArmor[];
  keys: { buy: string; abilityC: string; abilityQ: string; ultimate: string };
  roundsToWin: number;
  divisions: { min: number; label: string }[];
}

export interface TacProfile {
  name: string;
  role: string;
  rating: number;
  division: string;
  matches: number;
  wins: number;
  losses: number;
  kills: number;
  deaths: number;
  assists: number;
  plants: number;
  defuses: number;
  mvps: number;
}

export interface TacQueue {
  count: number;
  needed: number;
  max: number;
  /** secondes avant le lancement, `false` tant qu'il manque des joueurs */
  startIn: number | false;
  names: string[];
  /** joueurs en file avec leur rôle (bannières du menu) */
  players?: { name: string; role: string; rating: number; division: string }[];
}

export interface TacHud {
  self: number;
  team: TacTeam;
  role: string;
  map: { label: string; place: string };
  roundsToWin: number;
  catalog: TacCatalog;
}

export interface TacRound {
  round: number;
  attackers: TacTeam;
  attacking: boolean;
  buyTime: number;
  scores: Record<TacTeam, number>;
  overtime: boolean;
}

export interface TacLoadout {
  primary: string | false;
  secondary: string | false;
  armor: number;
}

/** Coéquipier vu dans le menu d'achat */
export interface TacMate {
  id: number;
  name: string;
  role: string;
  money: number;
  primary: string | false;
  alive: boolean;
}

export interface TacSelf {
  /** coéquipiers (argent, arme principale) */
  mates?: TacMate[];
  alive: boolean;
  money: number;
  loadout: TacLoadout;
  /** achats de la manche, qu'on peut revendre : 'primary', 'secondary', 'armor', 'ability:c'... */
  bought: string[];
  charges: { c: number; q: number };
  ult: number;
  ultCost: number;
  role: string;
}

export interface TacBoardRow {
  id: number;
  name: string;
  team: TacTeam;
  role: string;
  alive: boolean;
  kills: number;
  deaths: number;
  assists: number;
  /** dégâts moyens par manche */
  damage: number;
  firstKills: number;
  plants: number;
  defuses: number;
  score: number;
  ult: number;
  division?: string;
}

/** Présentation des équipes au chargement de la partie */
export interface TacLineupPlayer {
  id: number;
  name: string;
  team: TacTeam;
  role: string;
  rating: number;
  division: string;
}

export interface TacLineup {
  map: { label: string; place: string };
  attackers: TacTeam;
  players: TacLineupPlayer[];
}

/** Rapport de combat face à un ennemi, montré à la mort */
export interface TacReportRow {
  id: number;
  name: string;
  role: string;
  killer: boolean;
  dealt: number;
  dealtHits: number;
  taken: number;
  takenHits: number;
}

export interface TacDead {
  killer?: string;
  killerRole?: string;
  weapon?: string;
  spectate?: number;
  report?: TacReportRow[];
}

export interface TacState {
  phase: 'loading' | 'buy' | 'running' | 'round_end' | 'ended';
  round: number;
  remaining: number;
  attackers: TacTeam;
  scores: Record<TacTeam, number>;
  bomb: { site: string } | false;
  board: TacBoardRow[];
}

export interface TacKill {
  killer?: string;
  killerTeam?: TacTeam;
  victim: string;
  victimTeam: TacTeam;
  weapon?: string;
  headshot: boolean;
}

export interface TacRoundEnd {
  result: 'won' | 'lost';
  reason: string;
  scores: Record<TacTeam, number>;
  round: number;
}

export interface TacSummary {
  before: number;
  after: number;
  change: number;
  division: string;
  promoted: boolean;
  profile: TacProfile;
}

export interface TacEnd {
  result: 'won' | 'lost' | 'draw';
  reason: string;
  team: TacTeam;
  scores: Record<TacTeam, number>;
  board: TacBoardRow[];
  mvp: number | null;
  summary: TacSummary | null;
  seconds: number;
}

export interface TacLeaderboardRow {
  name: string;
  rating: number;
  division: string;
  matches: number;
  wins: number;
  kills: number;
  deaths: number;
}

export interface TacNotice {
  text: string;
  team?: TacTeam;
  /** seulement pour ce joueur (sans couleur d'équipe) */
  private?: boolean;
  danger?: boolean;
  big?: boolean;
}

export interface TacActionResult {
  ok: boolean;
  message?: string;
  profile?: TacProfile;
}
