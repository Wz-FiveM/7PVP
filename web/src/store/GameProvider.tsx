import { useCallback, useEffect, useMemo, useReducer, useRef, type ReactNode } from 'react';
import { gameApi } from '../api/gameApi';
import { isEnvBrowser } from '../api/nui';
import { mockVitals } from '../dev/mocks';
import { useNuiMessage } from '../hooks/useNuiMessage';
import type { KillfeedEntry, ToastKind } from '../types/game';
import type { ActionResult, NuiMessage } from '../types/nui';
import { GameContext, type GameActions } from './GameContext';
import { gameReducer, initialState } from './gameReducer';

const TOAST_DURATION = 4000;
const KILLFEED_DURATION = 6000;

export function GameProvider({ children }: { children: ReactNode }) {
  const [state, dispatch] = useReducer(gameReducer, initialState);
  const nextId = useRef(0);

  const notify = useCallback((text: string, kind: ToastKind = 'info') => {
    const id = ++nextId.current;
    dispatch({ type: 'toast/add', toast: { id, text, kind } });
    window.setTimeout(() => dispatch({ type: 'toast/remove', id }), TOAST_DURATION);
  }, []);

  const pushKill = useCallback((entry: KillfeedEntry) => {
    const id = ++nextId.current;
    dispatch({ type: 'killfeed/add', item: { ...entry, id } });
    window.setTimeout(() => dispatch({ type: 'killfeed/remove', id }), KILLFEED_DURATION);
  }, []);

  const handleMessage = useCallback(
    (message: NuiMessage) => {
      switch (message.action) {
        case 'sync':
          return dispatch({ type: 'sync', player: message.data });
        case 'zone':
          return dispatch({ type: 'zone', zone: message.data });
        case 'vitals':
          return dispatch({ type: 'vitals', vitals: message.data });
        case 'menu':
          return dispatch({ type: 'menu', ...message.data });
        case 'notify':
          return notify(message.data.text, message.data.kind);
        case 'killfeed':
          return pushKill(message.data);
        case 'death':
          return dispatch({ type: 'death', seconds: message.data.seconds });
        case 'alive':
          return dispatch({ type: 'alive' });
      }
    },
    [notify, pushKill],
  );

  useNuiMessage(handleMessage);

  useEffect(() => {
    gameApi.ready().then((payload) => {
      dispatch({ type: 'init', payload });
      // Dans le navigateur : données factices et menu ouvert pour développer
      if (isEnvBrowser()) {
        dispatch({ type: 'vitals', vitals: mockVitals });
        dispatch({ type: 'menu', open: true, inSafe: true });
        pushKill({ killer: 'Alpha', victim: 'Bravo' });
      }
    });
  }, [pushKill]);

  /** Exécute une action serveur et affiche son message éventuel. */
  const run = useCallback(
    async (request: Promise<ActionResult>) => {
      const result = await request;
      if (result?.message) notify(result.message, result.ok ? 'success' : 'error');
    },
    [notify],
  );

  const actions = useMemo<GameActions>(
    () => ({
      notify,
      closeMenu: () => {
        if (isEnvBrowser()) dispatch({ type: 'menu', open: false, inSafe: false });
        gameApi.close();
      },
      buy: (index) => run(gameApi.buy(index)),
      consumeItem: (name) => run(gameApi.useItem(name)),
      equip: (name) => run(gameApi.equip(name)),
      moveItem: (item, from, to, count) => run(gameApi.moveItem(item, from, to, count)),
      dropItem: (item, container, count) => run(gameApi.dropItem(item, container, count)),
      setShortcut: (slot, item) => run(gameApi.setShortcut(slot, item)),
      refreshLeaderboard: async () => {
        const rows = await gameApi.leaderboard();
        dispatch({ type: 'leaderboard', rows: Array.isArray(rows) ? rows : [] });
      },
    }),
    [notify, run],
  );

  const value = useMemo(() => ({ state, actions }), [state, actions]);

  return <GameContext.Provider value={value}>{children}</GameContext.Provider>;
}
