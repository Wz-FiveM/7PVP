import { createContext, useContext } from 'react';
import type { AdminActionPayload } from '../types/admin';
import type { ContainerId, LeaderboardScope, PauseAction, ToastKind } from '../types/game';
import type { GameState } from './gameReducer';

export interface GameActions {
  notify: (text: string, kind?: ToastKind) => void;
  closeMenu: () => void;
  buy: (index: number) => Promise<void>;
  consumeItem: (name: string) => Promise<void>;
  equip: (name: string) => Promise<void>;
  moveItem: (item: string, from: ContainerId, to: ContainerId, count: number) => Promise<void>;
  dropItem: (item: string, container: ContainerId, count: number) => Promise<void>;
  /** Prend des objets du butin ouvert (largage) et les range dans le sac ou le conteneur protégé */
  lootTake: (item: string, count: number, to: 'bag' | 'protected') => Promise<void>;
  setShortcut: (slot: number, item: string | null) => Promise<void>;
  craft: (id: string) => Promise<void>;
  /** Fixe ou retire un accessoire d'une arme */
  attachment: (weapon: string, attachment: string, attach: boolean) => Promise<void>;
  refreshLeaderboard: (scope: LeaderboardScope) => Promise<void>;
  /** Admin : exécute une action (vérifiée côté serveur) ; renvoie true si réussie */
  adminAction: (payload: AdminActionPayload) => Promise<boolean>;
  closeAdmin: () => void;
  /** Chat : envoie le message (ou la commande « / ») et ferme la saisie */
  sendChat: (text: string) => void;
  closeChat: () => void;
  /** Freeroam : fermer le menu, ou lancer une action (arme, véhicule, soin, PvP...) */
  closeFreeroam: () => void;
  freeroamAction: (action: string, data?: Record<string, unknown>) => Promise<void>;
  /** Menu d'interaction : fermer, ou cliquer sur un élément */
  closeInteraction: () => void;
  interactionAction: (id: string) => void;
  /** Menu pause : fermer, ou lancer une action (le menu se ferme) */
  closePause: () => void;
  pauseAction: (action: PauseAction) => void;
  /** Lobby : rejoindre un mode */
  joinMode: (mode: string) => Promise<void>;
  /** Retour au lobby (refusé hors zone safe en PvP) */
  leaveToLobby: () => Promise<void>;
}

export interface GameContextValue {
  state: GameState;
  actions: GameActions;
}

export const GameContext = createContext<GameContextValue | null>(null);

export function useGame(): GameContextValue {
  const context = useContext(GameContext);
  if (!context) {
    throw new Error('useGame doit être utilisé dans <GameProvider>');
  }
  return context;
}
