import { fetchNui } from './nui';
import type { ActionResult } from '../types/nui';

/** Modes de jeu du Freeroam (voir client/modules/activities/activities.lua). */
export const activityApi = {
  close: () => fetchNui<void>('activityClose'),

  /** le serveur vérifie et lance le mode ; la fenêtre se ferme si c'est accepté */
  start: (id: string) => fetchNui<ActionResult>('activityStart', { id }, { ok: false, message: 'Ce mode arrive bientôt.' }),
};
