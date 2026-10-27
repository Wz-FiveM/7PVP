import type { LeaderboardRow, Vitals } from '../types/game';

export const mockVitals: Vitals = {
  health: 90, maxHealth: 100, armor: 50, weapon: 'weapon_carbinerifle', clip: 30, reserve: 90,
};
import type { InitPayload } from '../types/nui';

/** Données factices utilisées par `npm run dev` hors de FiveM. */
export const mockInit: InitPayload = {
  config: {
    xpPerLevel: 1000,
    shortcutSlots: 7,
    containers: {
      bag: { label: 'Mon sac', capacity: 40 },
      protected: { label: 'Conteneur protégé', capacity: 5 },
    },
    items: {
      money: { label: 'Argent', type: 'money', weight: 0 },
      ammo_9mm: { label: '9mm', type: 'ammo', weight: 0.01 },
      ammo_556: { label: '5.56mm', type: 'ammo', weight: 0.012 },
      weapon_knife: { label: 'Couteau', type: 'weapon', weight: 0.3, weapon: 'WEAPON_KNIFE' },
      weapon_pistol: { label: 'Pistolet', type: 'weapon', weight: 1, weapon: 'WEAPON_PISTOL', ammo: 'ammo_9mm' },
      weapon_pumpshotgun: { label: 'Fusil à pompe', type: 'weapon', weight: 3.5, weapon: 'WEAPON_PUMPSHOTGUN' },
      weapon_carbinerifle: {
        label: 'Carabine', type: 'weapon', weight: 3.5, weapon: 'WEAPON_CARBINERIFLE', ammo: 'ammo_556',
      },
      bandage: { label: 'Bandage', type: 'consumable', weight: 0.1, heal: 25 },
      medkit: { label: 'Trousse de soins', type: 'consumable', weight: 0.5, heal: 100 },
      armor: { label: 'Gilet pare-balles', type: 'consumable', weight: 3, armor: 50 },
    },
    shop: [
      { item: 'weapon_pistol', count: 1, price: 400 },
      { item: 'weapon_carbinerifle', count: 1, price: 5500 },
      { item: 'ammo_9mm', count: 48, price: 80 },
      { item: 'ammo_556', count: 60, price: 250 },
      { item: 'bandage', count: 1, price: 100 },
      { item: 'medkit', count: 1, price: 350 },
      { item: 'armor', count: 1, price: 800 },
    ],
  },
  player: {
    name: 'Dev',
    money: 33851,
    xp: 2450,
    level: 3,
    kills: 12,
    deaths: 5,
    npcKills: 34,
    inventory: {
      bag: {
        money: 524,
        weapon_carbinerifle: 1,
        weapon_pistol: 1,
        weapon_pumpshotgun: 1,
        weapon_knife: 1,
        ammo_9mm: 96,
        ammo_556: 120,
        bandage: 3,
        armor: 1,
      },
      protected: { money: 33327, medkit: 2, ammo_9mm: 40 },
      shortcuts: ['weapon_pistol', 'weapon_carbinerifle', false, false, false, 'medkit', false],
    },
  },
  zone: { id: 'legion', label: 'Zone safe - Legion Square', type: 'safe' },
};

export const mockLeaderboard: LeaderboardRow[] = [
  { name: 'Alpha', level: 8, xp: 7400, kills: 54, deaths: 20, npcKills: 120, online: true },
  { name: 'Bravo', level: 5, xp: 4100, kills: 31, deaths: 28, npcKills: 64, online: false },
  { name: 'Dev', level: 3, xp: 2450, kills: 12, deaths: 5, npcKills: 34, online: true },
];
