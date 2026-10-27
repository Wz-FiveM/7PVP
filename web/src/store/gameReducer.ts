import type {
  GameConfig,
  KillfeedItem,
  LeaderboardRow,
  PlayerState,
  Toast,
  Vitals,
  ZoneInfo,
} from '../types/game';
import type { InitPayload } from '../types/nui';

export interface GameState {
  ready: boolean;
  config: GameConfig;
  player: PlayerState | null;
  zone: ZoneInfo;
  vitals: Vitals;
  menu: { open: boolean; inSafe: boolean };
  death: { active: boolean; seconds: number; key: number };
  toasts: Toast[];
  killfeed: KillfeedItem[];
  leaderboard: LeaderboardRow[];
}

export type GameAction =
  | { type: 'init'; payload: InitPayload }
  | { type: 'sync'; player: PlayerState }
  | { type: 'zone'; zone: ZoneInfo }
  | { type: 'vitals'; vitals: Vitals }
  | { type: 'menu'; open: boolean; inSafe: boolean }
  | { type: 'death'; seconds: number }
  | { type: 'alive' }
  | { type: 'toast/add'; toast: Toast }
  | { type: 'toast/remove'; id: number }
  | { type: 'killfeed/add'; item: KillfeedItem }
  | { type: 'killfeed/remove'; id: number }
  | { type: 'leaderboard'; rows: LeaderboardRow[] };

export const initialState: GameState = {
  ready: false,
  config: {
    shop: [],
    items: {},
    containers: { bag: { label: 'Sac', capacity: 0 }, protected: { label: 'Conteneur protégé', capacity: 0 } },
    shortcutSlots: 7,
    xpPerLevel: 1000,
  },
  player: null,
  zone: { label: 'Zone PvP', type: 'pvp' },
  vitals: { health: 100, maxHealth: 100, armor: 0, weapon: false, clip: 0, reserve: 0 },
  menu: { open: false, inSafe: false },
  death: { active: false, seconds: 0, key: 0 },
  toasts: [],
  killfeed: [],
  leaderboard: [],
};

export function gameReducer(state: GameState, action: GameAction): GameState {
  switch (action.type) {
    case 'init':
      return {
        ...state,
        ready: true,
        config: action.payload.config,
        player: action.payload.player ?? state.player,
        zone: action.payload.zone,
      };
    case 'sync':
      return { ...state, player: action.player };
    case 'zone':
      return { ...state, zone: action.zone };
    case 'vitals':
      return { ...state, vitals: action.vitals };
    case 'menu':
      return { ...state, menu: { open: action.open, inSafe: action.inSafe } };
    case 'death':
      return {
        ...state,
        menu: { ...state.menu, open: false },
        death: { active: true, seconds: action.seconds, key: state.death.key + 1 },
      };
    case 'alive':
      return { ...state, death: { ...state.death, active: false } };
    case 'toast/add':
      return { ...state, toasts: [...state.toasts, action.toast] };
    case 'toast/remove':
      return { ...state, toasts: state.toasts.filter((toast) => toast.id !== action.id) };
    case 'killfeed/add':
      return { ...state, killfeed: [action.item, ...state.killfeed].slice(0, 6) };
    case 'killfeed/remove':
      return { ...state, killfeed: state.killfeed.filter((item) => item.id !== action.id) };
    case 'leaderboard':
      return { ...state, leaderboard: action.rows };
  }
}
