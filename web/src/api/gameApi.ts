import { fetchNui } from './nui';
import { mockInit, mockLeaderboard } from '../dev/mocks';
import type { ContainerId, LeaderboardRow, LeaderboardScope, StashId } from '../types/game';
import type { ActionResult, CaseOpenResult, InitPayload } from '../types/nui';

const MOCK_OK: ActionResult = { ok: true, message: 'Action simulée (navigateur)' };

/** Toutes les requêtes React -> Lua passent par ici (voir client/modules/nui/nui.lua). */
export const gameApi = {
  ready: () => fetchNui<InitPayload>('ready', {}, mockInit),

  close: () => fetchNui<void>('close'),

  /** Langue de l'interface et des messages (gardée côté Lua, qui renvoie « locale ») */
  setLanguage: (lang: string) => fetchNui<ActionResult>('setLanguage', { lang }, { ok: true }),

  /** `index` est 1-based, comme Config.Shop côté Lua */
  buy: (index: number) => fetchNui<ActionResult>('buy', { index }, MOCK_OK),

  caseBuy: (id: string) => fetchNui<ActionResult>('caseBuy', { id }, MOCK_OK),

  /** `mock` : roulette simulée hors jeu (le tirage est fait par le serveur en jeu) */
  caseOpen: (id: string, mock: CaseOpenResult) => fetchNui<CaseOpenResult>('caseOpen', { id }, mock),

  /** Achat et ouverture immédiate avec des points boutique */
  caseOpenPoints: (id: string, mock: CaseOpenResult) => fetchNui<CaseOpenResult>('caseOpenPoints', { id }, mock),

  /** Roulette passée ou fermée : le serveur dévoile le résultat et libère le verrou */
  caseSkip: () => fetchNui<ActionResult>('caseSkip', {}, MOCK_OK),

  useItem: (name: string) => fetchNui<ActionResult>('useItem', { name }, MOCK_OK),

  equip: (name: string) => fetchNui<ActionResult>('equip', { name }, { ok: true }),

  moveItem: (item: string, from: ContainerId, to: ContainerId, count: number) =>
    fetchNui<ActionResult>('moveItem', { item, from, to, count }, MOCK_OK),

  lootTake: (item: string, count: number, to: 'bag' | 'protected') =>
    fetchNui<ActionResult>('lootTake', { item, count, to }, MOCK_OK),

  /** Achat d'un coffre payant auprès du banquier */
  unlockStash: (id: StashId) => fetchNui<ActionResult>('unlockStash', { id }, MOCK_OK),

  /** Sets d'équipement : `slot` est 1-based */
  loadoutSetSave: (slot: number) => fetchNui<ActionResult>('loadoutSetSave', { slot }, MOCK_OK),

  loadoutSetApply: (slot: number) => fetchNui<ActionResult>('loadoutSetApply', { slot }, MOCK_OK),

  loadoutSetClear: (slot: number) => fetchNui<ActionResult>('loadoutSetClear', { slot }, MOCK_OK),

  dropItem: (item: string, container: ContainerId, count: number) =>
    fetchNui<ActionResult>('dropItem', { item, container, count }, MOCK_OK),

  /** `slot` est 1-based ; `item: null` vide l'emplacement */
  setShortcut: (slot: number, item: string | null) =>
    fetchNui<ActionResult>('setShortcut', { slot, item }, { ok: true }),

  craft: (id: string) => fetchNui<ActionResult>('craft', { id }, MOCK_OK),

  selectClass: (id: string) => fetchNui<ActionResult>('classSelect', { id }, MOCK_OK),

  /** Un code par lettre (« qg-r »), chaîne vide pour retirer les couleurs */
  selectNameColors: (colors: string) => fetchNui<ActionResult>('nameColorSelect', { colors }, MOCK_OK),

  /** Achat d'un fond du killfeed en points boutique, équipé aussitôt */
  buyKillfeedBackground: (id: string) => fetchNui<ActionResult>('killfeedBackgroundBuy', { id }, MOCK_OK),

  seasonPassClaim: (tier: number, premium: boolean) => fetchNui<ActionResult>('seasonPassClaim', { tier, premium }, MOCK_OK),

  seasonPassBuy: () => fetchNui<ActionResult>('seasonPassBuy', {}, MOCK_OK),

  /** Titre affiché : chaîne vide pour n'en afficher aucun */
  selectTitle: (id: string) => fetchNui<ActionResult>('titleSelect', { id }, MOCK_OK),

  /** Chaîne vide pour reprendre le fond par défaut */
  selectKillfeedBackground: (id: string) => fetchNui<ActionResult>('killfeedBackgroundSelect', { id }, MOCK_OK),

  /** Fixe (`attach: true`) ou retire un accessoire d'une arme */
  attachment: (weapon: string, attachment: string, attach: boolean) =>
    fetchNui<ActionResult>('attachment', { weapon, attachment, attach }, MOCK_OK),

  leaderboard: (scope: LeaderboardScope) =>
    fetchNui<{ rows: LeaderboardRow[]; title: string }>('leaderboard', { scope }, { rows: mockLeaderboard, title: 'Saison octobre 2026' }),

  chatSend: (text: string) => fetchNui<void>('chatSend', { text }),

  chatClose: () => fetchNui<void>('chatClose'),

  joinMode: (mode: string) => fetchNui<ActionResult>('lobbyJoin', { mode }, { ok: true }),

  leaveToLobby: () => fetchNui<ActionResult>('lobbyLeave', {}, { ok: true }),
};
