import { fetchNui } from './nui';
import type { CodActionResult, CodClass, CodLeaderboardRow } from '../types/cod';

/** Mode Call of Duty (voir client/modules/cod/cod.lua). Le serveur valide chaque choix. */
export const codApi = {
  /** lance ou annule la recherche de partie */
  queue: (playlist: string) => fetchNui<CodActionResult>('codQueue', { playlist }, { ok: true }),

  vote: (map: string) => fetchNui<CodActionResult>('codVote', { map }, { ok: true }),

  saveClass: (index: number, classData: CodClass) =>
    fetchNui<CodActionResult>('codSaveClass', { index, class: classData }, { ok: true, message: 'Classe enregistrée.' }),

  saveStreaks: (streaks: string[]) =>
    fetchNui<CodActionResult>('codSaveStreaks', { streaks }, { ok: true, message: 'Séries enregistrées.' }),

  selectClass: (index: number) => fetchNui<CodActionResult>('codSelectClass', { index }, { ok: true }),

  leaderboard: () =>
    fetchNui<{ rows: CodLeaderboardRow[] }>('codLeaderboard', {}, {
      rows: [
        { name: 'Kaze', rank: 42, kills: 3120, deaths: 1890, wins: 212 },
        { name: 'Wezor', rank: 31, kills: 1984, deaths: 1402, wins: 141 },
        { name: 'Nyx', rank: 18, kills: 870, deaths: 910, wins: 63 },
      ],
    }),

  closePicker: () => fetchNui<void>('codPickerClose'),
};
