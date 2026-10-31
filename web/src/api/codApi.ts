import { fetchNui } from './nui';
import type { CodActionResult, CodClass, CodLeaderboardRow, CodPartyLobby, CodPlayerCardChoice, CodProfile, CodWeaponMods } from '../types/cod';

/** Mode Call of Duty (voir client/modules/cod/cod.lua). Le serveur valide chaque choix. */
export const codApi = {
  /** lance ou annule la recherche de partie */
  queue: (playlist: string) => fetchNui<CodActionResult>('codQueue', { playlist }, { ok: true }),

  vote: (map: string) => fetchNui<CodActionResult>('codVote', { map }, { ok: true }),

  saveClass: (index: number, classData: CodClass) =>
    fetchNui<CodActionResult>('codSaveClass', { index, class: classData }, { ok: true, message: 'Classe enregistrée.' }),

  saveStreaks: (streaks: string[]) =>
    fetchNui<CodActionResult>('codSaveStreaks', { streaks }, { ok: true, message: 'Séries enregistrées.' }),

  savePlayerCard: (card: CodPlayerCardChoice) =>
    fetchNui<CodActionResult>('codSavePlayerCard', { card }, { ok: true, message: 'Carte de joueur enregistrée.' }),

  selectClass: (index: number) => fetchNui<CodActionResult>('codSelectClass', { index }, { ok: true }),

  /** montre une arme sur le personnage du menu, sans argument : celle de la classe équipée */
  previewWeapon: (weapon?: string, mods?: CodWeaponMods) => fetchNui<void>('codWeaponPreview', { weapon, mods }),

  /** repart du rang 1 au niveau de Prestige suivant ; `current` ne sert qu'au navigateur */
  enterPrestige: (current: CodProfile) =>
    fetchNui<CodActionResult>('codPrestige', {}, {
      ok: true,
      profile: { ...current, rank: 1, prestige: current.prestige + 1, tokens: current.tokens + 1, canPrestige: false, xpInto: 0, xpNeeded: 800 },
    }),

  /** dépense un jeton de Prestige ; `current` ne sert qu'au navigateur */
  unlockPermanent: (id: string, current: CodProfile) =>
    fetchNui<CodActionResult>('codPrestigeUnlock', { id }, {
      ok: true,
      message: 'Déblocage permanent',
      profile: { ...current, tokens: current.tokens - 1, permanent: [...current.permanent, id] },
    }),

  /** montre un personnage dans le menu ; 'own' : celui du joueur, null : le choix enregistré */
  previewOperator: (id: string | null) => fetchNui<void>('codOperatorPreview', { id }),

  /** porte un personnage, null pour reprendre le sien ; `current` ne sert qu'au navigateur */
  selectOperator: (id: string | null, current: CodProfile) =>
    fetchNui<CodActionResult>('codOperatorSelect', { id }, { ok: true, profile: { ...current, operator: id ?? false } }),

  /** achète un personnage pour toujours ; `current` ne sert qu'au navigateur */
  buyOperator: (id: string, current: CodProfile) =>
    fetchNui<CodActionResult>('codOperatorBuy', { id }, {
      ok: true,
      message: 'Personnage acheté',
      profile: { ...current, operator: id, ownedOperators: [...current.ownedOperators, id] },
    }),

  leaderboard: () =>
    fetchNui<{ rows: CodLeaderboardRow[] }>('codLeaderboard', {}, {
      rows: [
        { name: 'Kaze', rank: 42, prestige: 3, kills: 3120, deaths: 1890, wins: 212 },
        { name: 'Wezor', rank: 31, prestige: 0, kills: 1984, deaths: 1402, wins: 141 },
        { name: 'Nyx', rank: 18, prestige: 0, kills: 870, deaths: 910, wins: 63 },
      ],
    }),

  partyInvite: (id: number) => fetchNui<CodActionResult>('codPartyInvite', { id }, { ok: true, message: 'Invitation envoyée.' }),

  partyRespond: (accept: boolean) => fetchNui<CodActionResult>('codPartyRespond', { accept }, { ok: true }),

  partyLeave: () => fetchNui<CodActionResult>('codPartyLeave', {}, { ok: true }),

  partyKick: (id: number) => fetchNui<CodActionResult>('codPartyKick', { id }, { ok: true }),

  /** joueurs à inviter et cartes des parties privées */
  partyLobby: () =>
    fetchNui<CodPartyLobby>('codPartyLobby', {}, {
      players: [{ id: 4, name: 'Rook', busy: false }, { id: 7, name: 'Nyx', busy: true }],
      maps: [{ id: 'port', label: 'Terminal', place: 'Port de Los Santos' }, { id: 'nuketown', label: 'Nuketown', place: 'Île au nord-est de Paleto Bay' }],
    }),

  startPrivate: (playlist: string, map: string) => fetchNui<CodActionResult>('codPrivate', { playlist, map }, { ok: true }),

  wzBuy: (id: string) => fetchNui<CodActionResult>('codWzBuy', { id }, { ok: true, message: 'Acheté' }),

  wzShopClose: () => fetchNui<void>('codWzShopClose'),

  closePicker: () => fetchNui<void>('codPickerClose'),

  /** quitte l'écran de choix de classe et rejoint la partie */
  deploy: () => fetchNui<void>('codDeploy'),
};
