import type { NuiMessage } from '../types/nui';
import { mockCreator, mockInit, mockLobbyModes, mockVitals } from './mocks';

/**
 * Panneau de dev (npm run dev uniquement) : chaque bouton envoie de vrais messages NUI,
 * exactement comme le ferait le Lua avec SendNUIMessage. On teste donc le même chemin qu'en jeu.
 */
export function sendNui(message: NuiMessage | { action: 'creator'; data: unknown }): void {
  window.postMessage(message, '*');
}

/** Ferme tout ce qui recouvre l'écran (créateur, lobby, menu, mort, chat). */
function resetScreens(): void {
  sendNui({ action: 'creator', data: { open: false } });
  sendNui({ action: 'lobby', data: { open: false } });
  sendNui({ action: 'menu', data: { open: false, inSafe: true } });
  sendNui({ action: 'chat', data: { open: false } });
  sendNui({ action: 'admin', data: { open: false } });
  sendNui({ action: 'alive' });
}

function enterPvp(): void {
  resetScreens();
  sendNui({ action: 'mode', data: { mode: 'pvp' } });
  sendNui({ action: 'vitals', data: mockVitals });
}

export interface DevScreen {
  id: string;
  label: string;
  open: () => void;
}

/** Écrans complets : un seul affiché à la fois. */
export const DEV_SCREENS: DevScreen[] = [
  {
    id: 'lobby',
    label: 'Lobby',
    open: () => {
      resetScreens();
      sendNui({ action: 'mode', data: { mode: false } });
      sendNui({ action: 'lobby', data: { open: true, modes: mockLobbyModes } });
    },
  },
  {
    id: 'creator',
    label: 'Créateur',
    open: () => {
      resetScreens();
      sendNui({ action: 'mode', data: { mode: false } });
      sendNui({ action: 'creator', data: mockCreator });
    },
  },
  {
    id: 'creator-edit',
    label: 'Créateur (édition)',
    open: () => {
      enterPvp();
      sendNui({ action: 'creator', data: { ...mockCreator, mode: 'edit' } });
    },
  },
  { id: 'hud', label: 'HUD PvP', open: enterPvp },
  {
    id: 'menu',
    label: 'Menu (zone safe)',
    open: () => {
      enterPvp();
      sendNui({ action: 'menu', data: { open: true, inSafe: true } });
    },
  },
  {
    id: 'menu-outside',
    label: 'Menu (hors safe)',
    open: () => {
      enterPvp();
      sendNui({ action: 'menu', data: { open: true, inSafe: false } });
    },
  },
  {
    id: 'death',
    label: 'Écran de mort',
    open: () => {
      enterPvp();
      sendNui({ action: 'death', data: { seconds: 8 } });
    },
  },
  {
    id: 'admin',
    label: 'Panneau admin',
    open: () => {
      enterPvp();
      sendNui({ action: 'admin', data: { open: true, self: { noclip: false, god: false, invisible: false } } });
    },
  },
  {
    id: 'chat',
    label: 'Chat ouvert',
    open: () => {
      enterPvp();
      sendNui({ action: 'chat', data: { open: true } });
    },
  },
];

const PLAYERS = ['Alpha', 'Bravo', 'Wezor', 'Kilo', 'Nova'];
const LINES = ['quelqu\'un au port ?', 'gg', 'je suis en safe', 'attention sniper sur le toit', 'qui vend du 5.56 ?'];
const pick = <T,>(list: T[]): T => list[Math.floor(Math.random() * list.length)];

export interface DevAction {
  label: string;
  run: () => void;
}

/** Événements ponctuels, à déclencher par-dessus l'écran affiché. */
export const DEV_ACTIONS: DevAction[] = [
  {
    label: 'Message chat',
    run: () =>
      sendNui({ action: 'chatMessage', data: { kind: 'player', author: pick(PLAYERS), text: pick(LINES), time: Date.now() / 1000 } }),
  },
  {
    label: 'Message système',
    run: () =>
      sendNui({ action: 'chatMessage', data: { kind: 'system', text: `${pick(PLAYERS)} a rejoint le PvP.`, time: Date.now() / 1000 } }),
  },
  { label: 'Notif succès', run: () => sendNui({ action: 'notify', data: { text: 'Butin : 9mm x24, $60', kind: 'success' } }) },
  { label: 'Notif erreur', run: () => sendNui({ action: 'notify', data: { text: 'Ton sac est plein.', kind: 'error' } }) },
  { label: 'Killfeed', run: () => sendNui({ action: 'killfeed', data: { killer: pick(PLAYERS), victim: pick(PLAYERS) } }) },
  { label: 'Raccourcis (TAB)', run: () => sendNui({ action: 'hotbar', data: { visible: true } }) },
  { label: 'Cacher raccourcis', run: () => sendNui({ action: 'hotbar', data: { visible: false } }) },
  { label: 'Zone safe', run: () => sendNui({ action: 'zone', data: mockInit.zone }) },
  { label: 'Zone PvE', run: () => sendNui({ action: 'zone', data: { id: 'port', label: 'Port de Los Santos', type: 'pve' } }) },
  { label: 'Zone PvP', run: () => sendNui({ action: 'zone', data: { label: 'Zone PvP', type: 'pvp' } }) },
  { label: 'Blessé', run: () => sendNui({ action: 'vitals', data: { ...mockVitals, health: 28, armor: 0 } }) },
  { label: 'Pleine forme', run: () => sendNui({ action: 'vitals', data: { ...mockVitals, health: 100, armor: 100 } }) },
];
