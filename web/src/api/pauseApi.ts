import { fetchNui } from './nui';
import type { PauseAction } from '../types/game';

/** Menu pause (voir client/modules/pause/pause.lua). */
export const pauseApi = {
  close: () => fetchNui<void>('pauseClose'),

  /** carte, paramètres GTA, menu F2, lobby, déconnexion : le menu se ferme */
  action: (action: PauseAction) => fetchNui<void>('pauseAction', { action }),
};
