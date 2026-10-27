import { createContext, useContext } from 'react';
import type { AdminActionPayload } from '../types/admin';
import type { ContainerId, ToastKind } from '../types/game';
import type { GameState } from './gameReducer';

export interface GameActions {
  notify: (text: string, kind?: ToastKind) => void;
  closeMenu: () => void;
  buy: (index: number) => Promise<void>;
  consumeItem: (name: string) => Promise<void>;
  equip: (name: string) => Promise<void>;
  moveItem: (item: string, from: ContainerId, to: ContainerId, count: number) => Promise<void>;
  dropItem: (item: string, container: ContainerId, count: number) => Promise<void>;
  setShortcut: (slot: number, item: string | null) => Promise<void>;
  refreshLeaderboard: () => Promise<void>;
  /** Admin : exécute une action (vérifiée côté serveur) ; renvoie true si réussie */
  adminAction: (payload: AdminActionPayload) => Promise<boolean>;
  closeAdmin: () => void;
  /** Chat : envoie le message (ou la commande « / ») et ferme la saisie */
  sendChat: (text: string) => void;
  closeChat: () => void;
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
