import { fetchNui } from './nui';
import type { ActionResult } from '../types/nui';

/** Menu de téléportation entre zones safe (voir client/modules/teleport/teleport.lua). */
export const teleportApi = {
  close: () => fetchNui<void>('teleportClose'),

  /** le serveur vérifie combat, délai et attente ; le menu se ferme si c'est accepté */
  go: (zone: string) => fetchNui<ActionResult>('teleportGo', { zone }, { ok: true }),
};
