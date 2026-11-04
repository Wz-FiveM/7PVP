import { fetchNui } from './nui';
import type { TacActionResult, TacLeaderboardRow } from '../types/tactical';

/** Mode Sabotage (voir client/modules/tactical/tactical.lua). Le serveur valide chaque choix. */
export const tacticalApi = {
  /** lance ou annule la recherche de partie */
  queue: () => fetchNui<TacActionResult>('tacQueue', {}, { ok: true }),

  selectRole: (role: string) => fetchNui<TacActionResult>('tacSelectRole', { role }, { ok: true }),

  /** arme (id), 'armor:<id>' ou 'ability:c|q' */
  buy: (item: string) => fetchNui<TacActionResult>('tacBuy', { item }, { ok: true }),

  /** 'primary', 'secondary', 'armor', 'ability:c' ou 'ability:q' */
  sell: (key: string) => fetchNui<TacActionResult>('tacSell', { key }, { ok: true }),

  closeBuy: () => fetchNui<void>('tacBuyClose'),

  /** résultats : retour au menu sans attendre */
  continueToMenu: () => fetchNui<TacActionResult>('tacContinue', {}, { ok: true }),

  leaderboard: () =>
    fetchNui<{ rows: TacLeaderboardRow[] }>('tacLeaderboard', {}, {
      rows: [
        { name: 'Kaze', rating: 1612, division: 'Diamant', matches: 84, wins: 52, kills: 1203, deaths: 870 },
        { name: 'Wezor', rating: 1388, division: 'Or', matches: 41, wins: 24, kills: 512, deaths: 430 },
        { name: 'Nyx', rating: 1104, division: 'Argent', matches: 12, wins: 6, kills: 98, deaths: 121 },
      ],
    }),
};
