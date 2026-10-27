import { createContext, useContext } from 'react';
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
