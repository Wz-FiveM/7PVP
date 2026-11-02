import { fetchNui } from './nui';
import type { ActionResult } from '../types/nui';

/** Menu de James (voir client/modules/dungeon/dungeon.lua). */
export const dungeonApi = {
  close: () => fetchNui<void>('dungeonMenuClose'),

  /** le serveur vérifie les clés et ouvre la salle d'attente ; le menu se ferme si c'est accepté */
  open: () => fetchNui<ActionResult>('dungeonMenuOpen', {}, { ok: false }),
};
