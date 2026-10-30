import { fetchNui } from './nui';
import type { CodActionResult, CodClass, CodLeaderboardRow, CodPlayerCardChoice, CodProfile } from '../types/cod';

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

  leaderboard: () =>
    fetchNui<{ rows: CodLeaderboardRow[] }>('codLeaderboard', {}, {
      rows: [
        { name: 'Kaze', rank: 42, prestige: 3, kills: 3120, deaths: 1890, wins: 212 },
        { name: 'Wezor', rank: 31, prestige: 0, kills: 1984, deaths: 1402, wins: 141 },
        { name: 'Nyx', rank: 18, prestige: 0, kills: 870, deaths: 910, wins: 63 },
      ],
    }),

  closePicker: () => fetchNui<void>('codPickerClose'),

  /** quitte l'écran de choix de classe et rejoint la partie */
  deploy: () => fetchNui<void>('codDeploy'),
};
