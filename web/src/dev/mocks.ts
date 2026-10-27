import type { CreatorPayload, Rgb } from '../types/appearance';
import type { LeaderboardRow, Vitals } from '../types/game';
import type { InitPayload } from '../types/nui';

export const mockVitals: Vitals = {
  health: 90, maxHealth: 100, armor: 50, weapon: 'weapon_carbinerifle', clip: 30, reserve: 90,
};

/** Palette factice : dégradé entre deux couleurs (le jeu envoie les vraies couleurs GTA). */
const gradient = (count: number, from: Rgb, to: Rgb): Rgb[] =>
  Array.from({ length: count }, (_, i) => {
    const t = i / (count - 1);
    return from.map((c, k) => Math.round(c + (to[k] - c) * t)) as Rgb;
  });

const FEATURES = [
  'Largeur du nez', 'Hauteur du nez', 'Longueur du nez', 'Arête du nez', 'Pointe du nez', 'Torsion du nez',
  'Hauteur des sourcils', 'Profondeur des sourcils', 'Hauteur des pommettes', 'Largeur des pommettes',
  'Joues', 'Ouverture des yeux', 'Épaisseur des lèvres', 'Largeur de la mâchoire', 'Longueur de la mâchoire',
  'Hauteur du menton', 'Longueur du menton', 'Largeur du menton', 'Fossette du menton', 'Épaisseur du cou',
];

const OVERLAYS = [
  { key: 'eyebrows', label: 'Sourcils', color: 1 as const },
  { key: 'beard', label: 'Barbe', color: 1 as const },
  { key: 'chestHair', label: 'Pilosité du torse', color: 1 as const },
  { key: 'blemishes', label: 'Imperfections' },
  { key: 'ageing', label: 'Rides' },
  { key: 'complexion', label: 'Teint' },
  { key: 'freckles', label: 'Taches de rousseur' },
  { key: 'makeup', label: 'Maquillage', color: 2 as const },
  { key: 'blush', label: 'Fard à joues', color: 2 as const },
  { key: 'lipstick', label: 'Rouge à lèvres', color: 2 as const },
];

export const mockCreator: CreatorPayload = {
  open: true,
  mode: 'create',
  schema: {
    mothers: [21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 45],
    fathers: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 42, 43, 44],
    features: FEATURES,
    overlays: OVERLAYS,
    components: [
      { key: 'top', label: 'Haut' },
      { key: 'undershirt', label: 'Sous-haut' },
      { key: 'arms', label: 'Bras' },
      { key: 'legs', label: 'Pantalon' },
      { key: 'shoes', label: 'Chaussures' },
    ],
    props: [
      { key: 'hat', label: 'Chapeau' },
      { key: 'glasses', label: 'Lunettes' },
    ],
  },
  palettes: {
    hair: gradient(64, [20, 16, 14], [235, 210, 160]),
    makeup: gradient(64, [120, 20, 40], [250, 170, 190]),
  },
  limits: {
    hair: 74,
    overlays: Object.fromEntries(OVERLAYS.map((o) => [o.key, 20])),
    components: Object.fromEntries(
      ['top', 'undershirt', 'arms', 'legs', 'shoes'].map((key) => [key, { drawables: 200, textures: 8 }]),
    ),
    props: { hat: { drawables: 150, textures: 0 }, glasses: { drawables: 40, textures: 0 } },
  },
  appearance: {
    sex: 'male',
    heritage: { mother: 21, father: 0, shapeMix: 0.7, skinMix: 0.5 },
    features: FEATURES.map(() => 0),
    eyeColor: 0,
    hair: { style: 4, color: 0, highlight: 0 },
    overlays: Object.fromEntries(
      OVERLAYS.map((o) => [o.key, { style: o.key === 'eyebrows' ? 0 : -1, opacity: 1, color: 0 }]),
    ),
    components: {
      top: { drawable: 0, texture: 0 },
      undershirt: { drawable: 15, texture: 0 },
      arms: { drawable: 0, texture: 0 },
      legs: { drawable: 0, texture: 0 },
      shoes: { drawable: 1, texture: 0 },
    },
    props: { hat: { drawable: -1, texture: 0 }, glasses: { drawable: -1, texture: 0 } },
  },
};

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
