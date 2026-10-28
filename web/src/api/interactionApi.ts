import { fetchNui } from './nui';

/** Menu d'interaction (voir client/modules/interaction/interaction_menu.lua). */
export const interactionApi = {
  close: () => fetchNui<void>('interactionClose'),

  /** Clic dans le monde (position de 0 à 1) : le jeu vise la cible et renvoie son menu */
  pick: (x: number, y: number) => fetchNui<void>('interactionPick', { x, y }),

  /** Le menu est renvoyé à jour par Lua après l'action */
  action: (id: string) => fetchNui<void>('interactionAction', { id }),
};
