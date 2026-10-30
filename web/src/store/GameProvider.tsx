import { useCallback, useEffect, useMemo, useReducer, useRef, type ReactNode } from 'react';
import { adminApi } from '../api/adminApi';
import { gameApi } from '../api/gameApi';
import { freeroamApi } from '../api/freeroamApi';
import { interactionApi } from '../api/interactionApi';
import { pauseApi } from '../api/pauseApi';
import { tradeApi } from '../api/tradeApi';
import { isEnvBrowser } from '../api/nui';
import { mockCaseReel, mockLobbyModes, mockVitals } from '../dev/mocks';
import { useNuiMessage } from '../hooks/useNuiMessage';
import { setLanguage, t } from '../i18n';
import type { KillfeedEntry, ToastKind } from '../types/game';
import type { ActionResult, CaseOpenResult, NuiMessage } from '../types/nui';
import { GameContext, type GameActions } from './GameContext';
import { gameReducer, initialState } from './gameReducer';

const TOAST_DURATION = 4000;
const KILLFEED_DURATION = 6000;

/** Nouvel essai de la poignée de main « ready » : 0,5 s, puis de plus en plus espacé (5 s max) */
const READY_FIRST_DELAY = 500;
const READY_MAX_DELAY = 5000;

export function GameProvider({ children }: { children: ReactNode }) {
  const [state, dispatch] = useReducer(gameReducer, initialState);
  const nextId = useRef(0);
  // Les actions sont stables (useMemo sans l'état) : la config est lue ici quand il le faut
  const configRef = useRef(state.config);
  configRef.current = state.config;

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
        case 'hotbar':
          return dispatch({ type: 'hotbar', visible: message.data.visible });
        case 'minimap':
          return dispatch({ type: 'minimap', minimap: message.data });
        case 'mode':
          return dispatch({ type: 'mode', mode: message.data.mode || null });
        case 'lobby':
          return dispatch({ type: 'lobby', open: message.data.open, modes: message.data.modes });
        case 'chat':
          return dispatch({ type: 'chat/open', open: message.data.open });
        case 'admin':
          return dispatch({ type: 'admin', open: message.data.open, self: message.data.self });
        case 'noclip':
          return dispatch({ type: 'noclip', info: message.data });
        case 'noclipHeld':
          return dispatch({ type: 'noclip/held', held: message.data.held });
        case 'chatMessage':
          return dispatch({ type: 'chat/message', message: { ...message.data, id: ++nextId.current } });
        case 'menu':
          return dispatch({ type: 'menu', ...message.data });
        case 'notify':
          return notify(message.data.text, message.data.kind);
        case 'locale':
          return void setLanguage(message.data.lang, message.data.languages);
        case 'killfeed':
          return pushKill(message.data);
        case 'death':
          return dispatch({ type: 'death', seconds: message.data.seconds, recap: message.data.recap });
        case 'freeroamMenu':
          return dispatch({
            type: 'freeroam',
            patch: {
              menuOpen: message.data.open,
              pvp: message.data.pvp,
              weapons: message.data.weapons ?? [],
              vehicles: message.data.vehicles ?? [],
            },
          });
        case 'interaction':
          return dispatch({ type: 'interaction', open: message.data.open, items: message.data.items || null });
        case 'helpNotify':
          return dispatch({ type: 'helpNotify', help: message.data.help || null });
        case 'lootContainer': {
          const { open, id, label, items } = message.data;
          if (!open) return dispatch({ type: 'loot', loot: null });
          if (label !== undefined && id !== undefined) return dispatch({ type: 'loot', loot: { id, label, items: items ?? [] } });
          return dispatch({ type: 'loot', loot: null, items: items ?? [] });
        }
        case 'trade':
          return dispatch({ type: 'trade', trade: message.data.trade || null });
        case 'freeroamPvp':
          return dispatch({ type: 'freeroam', patch: { pvp: message.data.pvp } });
        case 'controlZone':
          return dispatch({ type: 'controlZone', zone: message.data.zone || null });
        case 'clock':
          return dispatch({ type: 'clock', clock: message.data });
        case 'horde':
          return dispatch({ type: 'horde', horde: message.data.horde || null });
        case 'bounties':
          return dispatch({ type: 'bounties', list: Array.isArray(message.data) ? message.data : [] });
        case 'alive':
          return dispatch({ type: 'alive' });
        case 'group':
          return dispatch({ type: 'group', group: message.data.group || null });
        case 'groupInvite':
          return dispatch({ type: 'group/invite', invite: message.data });
        case 'pause':
          return dispatch({ type: 'pause', open: message.data.open, info: message.data.info });
        case 'groupVitals':
          return dispatch({ type: 'group/vitals', vitals: message.data });
        case 'combat':
          return dispatch({ type: 'combat', seconds: message.data.seconds });
      }
    },
    [notify, pushKill],
  );

  useNuiMessage(handleMessage);

  // Poignée de main avec Lua : réessayée tant qu'il n'a pas répondu (scripts pas encore
  // chargés, callback en erreur...), sinon le HUD ne se chargerait jamais
  useEffect(() => {
    let cancelled = false;
    let timer: number | undefined;
    const attempt = async (delay: number) => {
      const payload = await gameApi.ready();
      if (cancelled) return;
      if (!payload?.config) {
        timer = window.setTimeout(() => attempt(Math.min(delay * 2, READY_MAX_DELAY)), delay);
        return;
      }
      // Dictionnaire chargé avant le premier rendu : pas de texte français affiché un instant
      if (payload.locale) await setLanguage(payload.locale.lang, payload.locale.languages);
      if (cancelled) return;
      dispatch({ type: 'init', payload });
      // Dans le navigateur : données factices ; l'écran affiché se choisit dans le panneau de dev
      if (isEnvBrowser()) dispatch({ type: 'vitals', vitals: mockVitals });
    };
    void attempt(READY_FIRST_DELAY);
    return () => {
      cancelled = true;
      window.clearTimeout(timer);
    };
  }, []);

  // Dans le navigateur, TAB et T simulent les touches du jeu (raccourcis, chat)
  useEffect(() => {
    if (!isEnvBrowser()) return;
    const onKey = (event: KeyboardEvent) => {
      if (event.repeat) return;
      // T ouvre le chat (sauf si on tape déjà dans un champ)
      const typing = document.activeElement instanceof HTMLInputElement;
      if (event.key.toLowerCase() === 't' && event.type === 'keydown' && !typing) {
        event.preventDefault();
        dispatch({ type: 'chat/open', open: true });
        return;
      }
      if (event.key !== 'Tab') return;
      event.preventDefault();
      dispatch({ type: 'hotbar', visible: event.type === 'keydown' });
    };
    window.addEventListener('keydown', onKey);
    window.addEventListener('keyup', onKey);
    return () => {
      window.removeEventListener('keydown', onKey);
      window.removeEventListener('keyup', onKey);
    };
  }, []);

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
        if (isEnvBrowser()) {
          dispatch({ type: 'menu', open: false, inSafe: false, near: {} });
          dispatch({ type: 'loot', loot: null });
          dispatch({ type: 'trade', trade: null });
        }
        gameApi.close();
      },
      buy: (index) => run(gameApi.buy(index)),
      buyCase: (id) => run(gameApi.caseBuy(id)),
      openCase: async (id, withPoints = false) => {
        const definition = configRef.current.cases?.find((c) => c.id === id);
        const mock: CaseOpenResult = isEnvBrowser() && definition
          ? { ok: true, reel: mockCaseReel(definition), winner: 48, duration: 6.5 }
          : { ok: false };
        const result = await (withPoints ? gameApi.caseOpenPoints(id, mock) : gameApi.caseOpen(id, mock));
        if (!result?.ok || !result.reel || !result.winner) {
          notify(result?.message ?? t('Ouverture impossible.'), 'error');
          return;
        }
        dispatch({ type: 'case/spin', spin: { caseId: id, reel: result.reel, winner: result.winner, duration: result.duration ?? 6.5 } });
      },
      closeCase: () => dispatch({ type: 'case/close' }),
      openStore: () => {
        const url = configRef.current.shopPoints?.storeUrl;
        if (!url) return;
        // En jeu : navigateur du système (le lien ne s'ouvre pas dans le NUI)
        if (isEnvBrowser()) window.open(url, '_blank');
        else (window.invokeNative as (native: string, arg: string) => void)('openUrl', url);
      },
      consumeItem: (name) => run(gameApi.useItem(name)),
      equip: (name) => run(gameApi.equip(name)),
      moveItem: (item, from, to, count) => run(gameApi.moveItem(item, from, to, count)),
      lootTake: (item, count, to) => run(gameApi.lootTake(item, count, to)),
      craft: (id) => run(gameApi.craft(id)),
      attachment: (weapon, attachment, attach) => run(gameApi.attachment(weapon, attachment, attach)),
      dropItem: (item, container, count) => run(gameApi.dropItem(item, container, count)),
      unlockStash: (id) => run(gameApi.unlockStash(id)),
      setShortcut: (slot, item) => run(gameApi.setShortcut(slot, item)),
      tradeOffer: (item, count) => run(tradeApi.offer(item, count)),
      tradeReady: (ready) => run(tradeApi.ready(ready)),
      tradeConfirm: () => run(tradeApi.confirm()),
      tradeCancel: async () => {
        if (isEnvBrowser()) dispatch({ type: 'trade', trade: null });
        await run(tradeApi.cancel());
      },
      refreshLeaderboard: async (scope) => {
        const result = await gameApi.leaderboard(scope);
        dispatch({ type: 'leaderboard', rows: Array.isArray(result?.rows) ? result.rows : [], title: result?.title ?? '' });
      },
      sendChat: (text) => {
        if (isEnvBrowser()) {
          // Dans le navigateur : écho local (commandes affichées comme message système)
          dispatch({ type: 'chat/open', open: false });
          const command = text.startsWith('/');
          dispatch({
            type: 'chat/message',
            message: {
              id: ++nextId.current,
              kind: command ? 'system' : 'player',
              author: command ? undefined : 'Dev',
              text: command ? `Commande exécutée : ${text}` : text,
              time: Date.now() / 1000,
            },
          });
        }
        gameApi.chatSend(text);
      },
      adminAction: async (payload) => {
        const result = await adminApi.action(payload);
        if (result?.message) notify(result.message, result.ok ? 'success' : 'error');
        if (result?.self) dispatch({ type: 'admin', open: true, self: result.self });
        if (isEnvBrowser() && (payload.action === 'noclip' || payload.action === 'god' || payload.action === 'invisible')) {
          dispatch({ type: 'admin/toggle', key: payload.action });
        }
        return result?.ok ?? false;
      },
      closeAdmin: () => {
        if (isEnvBrowser()) dispatch({ type: 'admin', open: false });
        adminApi.close();
      },
      closeFreeroam: () => {
        if (isEnvBrowser()) dispatch({ type: 'freeroam', patch: { menuOpen: false } });
        freeroamApi.close();
      },
      freeroamAction: async (action, data) => {
        const result = await freeroamApi.action(action, data);
        if (result?.message) notify(result.message, result.ok ? 'success' : 'error');
        if (typeof result?.pvp === 'boolean') dispatch({ type: 'freeroam', patch: { pvp: result.pvp } });
      },
      closeInteraction: () => {
        if (isEnvBrowser()) dispatch({ type: 'interaction', open: false, items: null });
        interactionApi.close();
      },
      interactionAction: (id) => {
        if (isEnvBrowser()) notify(`Action simulée : ${id}`);
        interactionApi.action(id);
      },
      closePause: () => {
        if (isEnvBrowser()) dispatch({ type: 'pause', open: false });
        pauseApi.close();
      },
      pauseAction: (action) => {
        if (isEnvBrowser()) {
          dispatch({ type: 'pause', open: false });
          notify(`Action simulée : ${action}`);
        }
        pauseApi.action(action);
      },
      closeChat: () => {
        if (isEnvBrowser()) dispatch({ type: 'chat/open', open: false });
        gameApi.chatClose();
      },
      joinMode: async (mode) => {
        const result = await gameApi.joinMode(mode);
        if (!result?.ok) {
          notify(result?.message ?? t('Impossible de rejoindre ce mode.'), 'error');
          return;
        }
        // En jeu, Lua ferme le lobby ; dans le navigateur on le simule
        if (isEnvBrowser()) {
          dispatch({ type: 'lobby', open: false });
          dispatch({ type: 'mode', mode });
        }
      },
      leaveToLobby: async () => {
        const result = await gameApi.leaveToLobby();
        if (!result?.ok && result?.message) notify(result.message, 'error');
        if (result?.ok && isEnvBrowser()) {
          dispatch({ type: 'mode', mode: null });
          dispatch({ type: 'lobby', open: true, modes: mockLobbyModes });
        }
      },
    }),
    [notify, run],
  );

  const value = useMemo(() => ({ state, actions }), [state, actions]);

  return <GameContext.Provider value={value}>{children}</GameContext.Provider>;
}
