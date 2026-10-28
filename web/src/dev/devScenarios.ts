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
  sendNui({ action: 'lootContainer', data: { open: false } });
  sendNui({ action: 'trade', data: { trade: false } });
  sendNui({ action: 'chaseHud', data: { open: false } });
  sendNui({ action: 'chaseVote', data: { open: false } });
  sendNui({ action: 'cvcHud', data: { open: false } });
  sendNui({ action: 'cvcOutside', data: { outside: false } });
  sendNui({ action: 'chat', data: { open: false } });
  sendNui({ action: 'admin', data: { open: false } });
  sendNui({ action: 'pause', data: { open: false } });
  sendNui({ action: 'interaction', data: { open: false } });
  sendNui({ action: 'teleport', data: { open: false } });
  sendNui({ action: 'teleportChannel', data: { seconds: false } });
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
      sendNui({
        action: 'menu',
        data: { open: true, inSafe: true, near: { stash: true, shop: true, clothing: true, crafting: true, contracts: true } },
      });
    },
  },
  {
    id: 'loot-airdrop',
    label: 'Largage ouvert',
    open: () => {
      enterPvp();
      sendNui({ action: 'menu', data: { open: true, inSafe: false, near: {}, page: 'inventory' } });
      sendNui({
        action: 'lootContainer',
        data: {
          open: true,
          id: 1,
          label: 'Largage',
          items: { weapon_carbinerifle: 1, ammo_556: 120, medkit: 3, armor: 2, money: 1250 },
        },
      });
    },
  },
  {
    id: 'trade',
    label: 'Échange (/trade)',
    open: () => {
      enterPvp();
      sendNui({ action: 'menu', data: { open: true, inSafe: false, near: {}, page: 'inventory' } });
      sendNui({
        action: 'trade',
        data: {
          trade: {
            id: 1,
            partner: { id: 12, name: 'Kaïros' },
            mine: { items: { money: 300, bandage: 2 }, ready: true, confirmed: false },
            theirs: { items: { weapon_carbinerifle: 1, ammo_556: 60 }, ready: false, confirmed: false },
          },
        },
      });
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
            avatar: 'https://cdn.discordapp.com/embed/avatars/2.png',
            name: 'Dev', serverId: 1, mode: 'pvp', level: 3, kills: 42, deaths: 17, npcKills: 312, isAdmin: true,
            keys: { menu: 'TAB', chat: 'T', admin: 'F10', noclip: 'F11', teleport: 'F1' },
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
    id: 'interaction',
    label: 'Menu interaction',
    open: () => {
      enterPvp();
      sendNui({
        action: 'interaction',
        data: {
          open: true,
          items: [
            { kind: 'info', id: 'self:name', label: 'Dev', icon: 'profile' },
            { kind: 'info', id: 'serverId', label: 'ID Serveur', icon: 'contract', value: '1216' },
            { kind: 'info', id: 'level', label: 'Niveau', icon: 'trophy', value: '4' },
            { kind: 'separator', id: 'separator' },
            {
              kind: 'submenu', id: 'team', label: 'Équipe', icon: 'group',
              children: [
                { kind: 'info', id: 'team:size', label: 'Membres', icon: 'group', value: '3' },
                { kind: 'action', id: 'team:invite', label: 'Inviter Bravo', icon: 'group' },
                { kind: 'action', id: 'team:leave', label: "Quitter l'équipe", icon: 'exit' },
              ],
            },
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
  {
    label: 'Killfeed',
    run: () =>
      sendNui({
        action: 'killfeed',
        data: {
          killer: pick(PLAYERS),
          victim: pick(PLAYERS),
          weapon: pick(['weapon_carbinerifle', 'weapon_pistol', 'weapon_pumpshotgun', 'weapon_sniperrifle', 'weapon_smg']),
          headshot: Math.random() < 0.4,
          killerId: 20,
          victimId: 21,
        },
      }),
  },
  {
    label: 'Killfeed : mon kill',
    run: () =>
      sendNui({
        action: 'killfeed',
        data: { killer: 'Dev', victim: pick(PLAYERS), weapon: 'weapon_assaultrifle', headshot: true, killerId: 1, victimId: 22 },
      }),
  },
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
        data: {
          group: {
            id: 1,
            leader: 1,
            members: [
              { id: 1, name: 'Dev', avatar: 'https://cdn.discordapp.com/embed/avatars/2.png' },
              { id: 7, name: 'Bravo', avatar: 'https://cdn.discordapp.com/embed/avatars/4.png' },
              { id: 12, name: 'Kilo' },
            ],
          },
        },
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
  {
    label: 'Parler à l\'armurier',
    run: () => sendNui({ action: 'menu', data: { open: true, inSafe: true, near: { shop: true }, page: 'shop' } }),
  },
  {
    label: 'Commissaire-priseur',
    run: () => sendNui({ action: 'menu', data: { open: true, inSafe: true, near: { market: true }, page: 'market' } }),
  },
  {
    label: 'Téléportation (F1)',
    run: () =>
      sendNui({
        action: 'teleport',
        data: {
          open: true,
          channel: 10,
          pending: false,
          key: 'F1',
          zones: [
            { id: 'legion', label: 'Zone safe - Legion Square', description: 'Centre-ville : tous les services', distance: 420, current: false },
            { id: 'airport', label: 'Zone safe - Aéroport de Los Santos', description: "Terminal de l'aéroport, au sud de la ville", distance: 2930, current: false },
            { id: 'sandy', label: 'Zone safe - Sandy Shores', description: 'Bureau du shérif, au bord du désert', distance: 4710, current: false },
            { id: 'paleto', label: 'Zone safe - Paleto Bay', description: 'Bureau du shérif, tout au nord de la carte', distance: 7080, current: false },
          ],
        },
      }),
  },
  {
    label: 'Téléportation : depuis une zone safe',
    run: () =>
      sendNui({
        action: 'teleport',
        data: {
          open: true,
          channel: 0,
          pending: false,
          key: 'F1',
          zones: [
            { id: 'legion', label: 'Zone safe - Legion Square', description: 'Centre-ville : tous les services', distance: 12, current: true },
            { id: 'airport', label: 'Zone safe - Aéroport de Los Santos', description: "Terminal de l'aéroport, au sud de la ville", distance: 3120, current: false },
          ],
        },
      }),
  },
  {
    label: 'Stimulants (effets)',
    run: () =>
      sendNui({
        action: 'effects',
        data: [
          { id: 'regen', label: 'Régénération', short: 'Régén.', icon: 'drug_health', remaining: 8, duration: 30 },
          { id: 'stamina', label: 'Endurance illimitée', short: 'Endurance', icon: 'drug_stamina', remaining: 42, duration: 60 },
          { id: 'antizin', label: 'Immunité au vomi', short: 'Antizin', icon: 'antizin', remaining: 115, duration: 120 },
        ],
      }),
  },
  { label: 'Fin des effets', run: () => sendNui({ action: 'effects', data: [] }) },
  {
    label: 'Mode de jeu (PNJ)',
    run: () =>
      sendNui({
        action: 'activity',
        data: {
          open: true,
          activity: {
            id: 'cvc',
            label: 'CVC',
            tagline: 'Combat par équipe',
            description: "Deux équipes s'affrontent en convoi : stratégie, placement et communication.",
            icon: 'group',
            enabled: false,
          },
        },
      }),
  },
  { label: 'Course : file', run: () => sendNui({ action: 'chaseQueue', data: { count: 1, needed: 2 } }) },
  {
    label: 'Course : vote',
    run: () =>
      sendNui({
        action: 'chaseVote',
        data: {
          open: true,
          seconds: 20,
          opponent: 'Bravo',
          vehicles: [
            { model: 'sultan', label: 'Sultan' },
            { model: 'kuruma', label: 'Kuruma' },
            { model: 'elegy2', label: 'Elegy RH8' },
            { model: 'comet2', label: 'Comet' },
            { model: 'buffalo2', label: 'Buffalo S' },
            { model: 'dominator', label: 'Dominator' },
            { model: 'sandking', label: 'Sandking' },
            { model: 'bati', label: 'Bati 801' },
          ],
        },
      }),
  },
  {
    label: 'Course : manche (voleur)',
    run: () => {
      sendNui({ action: 'chaseVote', data: { open: false } });
      sendNui({
        action: 'chaseHud',
        data: {
          open: true, round: 1, role: 'thief', scores: { me: 0, opponent: 0 }, opponent: 'Bravo',
          countdown: 3, roundTime: 180, escapeDistance: 500, arrestTime: 5,
        },
      });
      sendNui({ action: 'chaseState', data: { remaining: 142, arrest: 0.4, health: 64, warns: 1, maxWarns: 3 } });
    },
  },
  {
    label: 'Course : manche gagnée',
    run: () =>
      sendNui({ action: 'chaseBanner', data: { won: true, reason: 'Le voleur a semé le policier.', round: 1, scores: { me: 1, opponent: 0 } } }),
  },
  {
    label: 'Course : fin',
    run: () => sendNui({ action: 'chaseEnd', data: { result: 'draw', scores: { me: 1, opponent: 1 } } }),
  },
  { label: 'CVC : file', run: () => sendNui({ action: 'cvcQueue', data: { count: 3, needed: 2, max: 16, startIn: 24 } }) },
  {
    label: 'CVC : manche',
    run: () => {
      sendNui({ action: 'cvcQueue', data: { count: 0 } });
      sendNui({
        action: 'cvcHud',
        data: {
          open: true, round: 2, team: 'Alpha', teamId: 'alpha', arena: 'Désert de Senora',
          countdown: 3, roundTime: 300, roundsToWin: 3, scores: { us: 1, them: 0 },
        },
      });
      sendNui({ action: 'cvcState', data: { remaining: 212, alive: { us: 3, them: 2 } } });
    },
  },
  { label: 'CVC : hors zone', run: () => sendNui({ action: 'cvcOutside', data: { outside: true } }) },
  {
    label: 'CVC : fin',
    run: () => sendNui({ action: 'cvcEnd', data: { result: 'won', scores: { us: 3, them: 1 } } }),
  },
  { label: 'Compteur (en voiture)', run: () => sendNui({ action: 'speedometer', data: { visible: true, speed: 127, rpm: 0.82, gear: '4', engine: 74 } }) },
  { label: 'Compteur : sortir', run: () => sendNui({ action: 'speedometer', data: { visible: false } }) },
  { label: 'Interaction : ciblage', run: () => sendNui({ action: 'interaction', data: { open: true, items: false } }) },
  {
    label: 'Interaction : joueur',
    run: () =>
      sendNui({
        action: 'interaction',
        data: {
          open: true,
          items: [
            { kind: 'info', id: 'player:name', label: 'Bravo', icon: 'profile', value: 'ID 7' },
            { kind: 'info', id: 'player:bounty', label: 'Prime', icon: 'money', value: '$1500' },
            { kind: 'separator', id: 'separator' },
            { kind: 'action', id: 'player:invite', label: "Inviter dans l'équipe", icon: 'group' },
          ],
        },
      }),
  },
  { label: 'Aide (E)', run: () => sendNui({ action: 'helpNotify', data: { help: { key: 'E', text: 'Armurier · Voir la boutique' } } }) },
  { label: 'Masquer aide', run: () => sendNui({ action: 'helpNotify', data: { help: false } }) },
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
