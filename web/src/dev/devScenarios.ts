import type { NoclipInfo } from '../types/admin';
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
  sendNui({ action: 'pause', data: { open: false } });
  sendNui({ action: 'freeroamMenu', data: { open: false, pvp: false, weapons: [], vehicles: [] } });
  sendNui({ action: 'noclip', data: { ...NOCLIP, active: false } });
  sendNui({ action: 'alive' });
}

/** Ce que noclip.lua envoie à l'activation (clavier AZERTY) */
const NOCLIP: NoclipInfo = {
  active: true,
  keys: { forward: 'Z', left: 'Q', back: 'S', right: 'D', up: 'Espace', down: 'Ctrl', fast: 'Maj', slow: 'Alt' },
  toggleKey: 'F11',
  speed: 12,
  fastMultiplier: 4,
  slowMultiplier: 0.25,
};

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
    id: 'noclip',
    label: 'Noclip',
    open: () => {
      enterPvp();
      sendNui({ action: 'noclip', data: NOCLIP });
    },
  },
  {
    id: 'pause',
    label: 'Menu pause',
    open: () => {
      enterPvp();
      sendNui({
        action: 'pause',
        data: {
          open: true,
          info: {
            name: 'Dev', serverId: 1, mode: 'pvp', level: 3, kills: 42, deaths: 17, npcKills: 312, isAdmin: true,
            keys: { menu: 'F2', hotbar: 'TAB', chat: 'T', admin: 'F10', noclip: 'F11' },
          },
        },
      });
    },
  },
  {
    id: 'freeroam',
    label: 'Freeroam (menu)',
    open: () => {
      resetScreens();
      sendNui({ action: 'mode', data: { mode: 'freeroam' } });
      sendNui({
        action: 'freeroamMenu',
        data: {
          open: true,
          pvp: false,
          weapons: [
            { weapon: 'WEAPON_PISTOL', label: 'Pistolet' },
            { weapon: 'WEAPON_CARBINERIFLE', label: 'Carabine' },
            { weapon: 'WEAPON_RPG', label: 'Lance-roquettes' },
          ],
          vehicles: [
            { model: 'sultan', label: 'Sultan', category: 'Voitures' },
            { model: 'zentorno', label: 'Zentorno', category: 'Voitures' },
            { model: 'bati', label: 'Bati 801', category: 'Motos' },
            { model: 'buzzard2', label: 'Buzzard', category: 'Aérien' },
          ],
        },
      });
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
  {
    label: 'Groupe (3 joueurs)',
    run: () => {
      sendNui({
        action: 'group',
        data: { group: { id: 1, leader: 1, members: [{ id: 1, name: 'Dev' }, { id: 7, name: 'Bravo' }, { id: 12, name: 'Kilo' }] } },
      });
      sendNui({
        action: 'groupVitals',
        data: [{ id: 1, health: 90, armor: 50 }, { id: 7, health: 64, armor: 20 }, { id: 12, health: false, armor: 0 }],
      });
    },
  },
  {
    label: 'Mort (récap)',
    run: () =>
      sendNui({
        action: 'death',
        data: {
          seconds: 8,
          recap: {
            killer: 'Bravo', killerId: 7, weapon: 'Carabine', distance: 42, killerHealth: 37, killerArmor: 0,
            taken: { damage: 148, hits: 6, headshots: 1 }, dealt: { damage: 63, hits: 4, headshots: 0 },
          },
        },
      }),
  },
  {
    label: 'Primes',
    run: () => sendNui({ action: 'bounties', data: [{ id: 7, name: 'Bravo', amount: 1500, streak: 7 }, { id: 9, name: 'Nova', amount: 1000, streak: 5 }] }),
  },
  { label: 'Nuit (23:40)', run: () => sendNui({ action: 'clock', data: { hour: 23, minute: 40, night: true } }) },
  {
    label: 'Horde',
    run: () => sendNui({ action: 'horde', data: { horde: { zoneId: 'port', label: 'Port de Los Santos', endsIn: 282, kills: 27 } } }),
  },
  {
    label: 'Zone de contrôle',
    run: () =>
      sendNui({
        action: 'controlZone',
        data: { zone: { label: 'Carrière de Davis', ownerLabel: 'Groupe de Bravo', mine: false, capturing: true, enemyCapturing: false, progress: 45, contested: false } },
      }),
  },
  { label: 'Fin horde', run: () => sendNui({ action: 'horde', data: { horde: false } }) },
  { label: 'Invitation groupe', run: () => sendNui({ action: 'groupInvite', data: { from: 9, fromName: 'Nova' } }) },
  { label: 'Quitter groupe', run: () => sendNui({ action: 'group', data: { group: false } }) },
  { label: 'En combat (20 s)', run: () => sendNui({ action: 'combat', data: { seconds: 20 } }) },
  { label: 'Fin du combat', run: () => sendNui({ action: 'combat', data: { seconds: 0 } }) },
  {
    label: 'Killfeed déco',
    run: () => sendNui({ action: 'killfeed', data: { killer: pick(PLAYERS), victim: pick(PLAYERS), reason: 'disconnect' } }),
  },
  { label: 'Touche corps', run: () => sendNui({ action: 'hit', data: { damage: 18, armor: 0, headshot: false, fatal: false } }) },
  { label: 'Touche armure', run: () => sendNui({ action: 'hit', data: { damage: 14, armor: 14, headshot: false, fatal: false } }) },
  { label: 'Tir tête', run: () => sendNui({ action: 'hit', data: { damage: 64, armor: 0, headshot: true, fatal: false } }) },
  { label: 'Coup mortel', run: () => sendNui({ action: 'hit', data: { damage: 32, armor: 0, headshot: false, fatal: true } }) },
  {
    label: 'Rafale (5 balles)',
    run: () => {
      for (let i = 0; i < 5; i += 1) {
        window.setTimeout(() => sendNui({ action: 'hit', data: { damage: 9, armor: 0, headshot: i === 3, fatal: false } }), i * 110);
      }
    },
  },
  { label: 'Noclip : avancer + Maj', run: () => sendNui({ action: 'noclipHeld', data: { held: ['forward', 'fast'] } }) },
  { label: 'Noclip : monter + Alt', run: () => sendNui({ action: 'noclipHeld', data: { held: ['up', 'slow'] } }) },
  { label: 'Noclip : relâcher', run: () => sendNui({ action: 'noclipHeld', data: { held: [] } }) },
];
