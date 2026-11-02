import type { AdminPlayer, FreeroamAdminData, FreeroamSetting, LootAdminData, ResaleAdminData, ShopAdminData } from '../types/admin';
import type { CreatorPayload, Rgb } from '../types/appearance';

export const mockAdminPlayers: AdminPlayer[] = [
  { id: 1, name: 'Wezor', mode: 'pvp', dead: false, money: 33851, level: 3 },
  { id: 2, name: 'Alpha', mode: 'pvp', dead: true, money: 1200, level: 8 },
  { id: 4, name: 'Bravo', mode: false, dead: false, money: 500, level: 1 },
  { id: 7, name: 'Kilo', mode: 'pvp', dead: false, money: 7400, level: 5 },
];

/** Onglet « Freeroam » du panneau admin (hors jeu) */
export const mockFreeroamAdmin: FreeroamAdminData = {
  ok: true,
  chaseQueue: 1,
  chases: [
    {
      id: 3, round: 1, phase: 'running',
      players: [
        { id: 2, name: 'Alpha', role: 'thief', score: 0, warns: 1 },
        { id: 7, name: 'Kilo', role: 'cop', score: 0, warns: 0 },
      ],
    },
    {
      id: 4, round: 0, phase: 'vote',
      players: [
        { id: 9, name: 'Delta', role: false, score: 0, warns: 0 },
        { id: 11, name: 'Echo', role: false, score: 0, warns: 0 },
      ],
    },
  ],
  settings: [
    {
      name: 'chaseVehicles', group: 'vehicles', label: 'Course poursuite', kind: 'vehicles', category: false, modified: true,
      hint: 'Véhicules proposés au vote avant chaque partie (image : web/public/items/<modèle>.png).',
      value: [
        { model: 'kuruma', label: 'Kuruma' },
        { model: 'sentinel', label: 'Sentinel' },
        { model: 'felon', label: 'Felon' },
        { model: 'granger', label: 'Granger' },
      ],
    },
    {
      name: 'menuVehicles', group: 'vehicles', label: 'Menu Freeroam', kind: 'vehicles', category: true, modified: false,
      hint: 'Véhicules gratuits du menu (Tab), rangés par catégorie.',
      value: [
        { model: 'sultan', label: 'Sultan', category: 'Voitures' },
        { model: 'bati', label: 'Bati 801', category: 'Motos' },
        { model: 'buzzard2', label: 'Buzzard', category: 'Aérien' },
      ],
    },
    { name: 'cvcVehicle', group: 'vehicles', label: 'CVC', kind: 'model', category: false, modified: false, hint: 'Véhicule du convoi de chaque équipe.', value: 'granger' },
    { name: 'bikeVehicle', group: 'vehicles', label: '1VS1 Bike', kind: 'model', category: false, modified: false, hint: 'Moto des deux joueurs, recréée à chaque manche.', value: 'bati' },
    {
      name: 'pvpSafeZones', group: 'pvp', label: 'Zones safe', point: 'Apparition', kind: 'zones', category: false, modified: false,
      hint: 'Centre et rayon de chaque zone safe, et points où l\'on apparaît (réapparition, téléportation F1), dans ta direction. Garde les apparitions et les PNJ dans le cercle.',
      value: [
        {
          id: 'legion', label: 'Zone safe - Legion Square', center: { x: 195.2, y: -933.8, z: 30.7, w: 0 }, radius: 80,
          spawns: [{ x: 195.2, y: -933.8, z: 30.7, w: 144 }, { x: 210, y: -920, z: 30.7, w: 160 }],
        },
        {
          id: 'sandy', label: 'Zone safe - Sandy Shores', center: { x: 1853.2, y: 3686.6, z: 34.3, w: 0 }, radius: 70,
          spawns: [{ x: 1853.2, y: 3686.6, z: 34.3, w: 210 }],
        },
      ],
    },
    {
      name: 'pvpNpcs', group: 'pvp', label: 'PNJ de service', short: 'PNJ', kind: 'places', category: false, modified: false,
      hint: 'Banquier, armurier, tailleur... de chaque zone safe. Place-toi à l\'endroit voulu : le PNJ regardera dans la même direction que toi. Les PNJ doivent rester dans la zone safe.',
      value: [
        { key: 'legion/stash', label: 'Zone safe - Legion Square · Banquier', coords: { x: 186.8, y: -941.6, z: 30.1, w: 340 } },
        { key: 'legion/shop', label: 'Zone safe - Legion Square · Armurier', coords: { x: 202.6, y: -925.5, z: 30.7, w: 150 } },
        { key: 'sandy/stash', label: 'Zone safe - Sandy Shores · Banquier', coords: { x: 1849, y: 3680, z: 34.3, w: 300 } },
      ],
    },
    {
      name: 'pvpPveZones', group: 'pvp', label: 'Zones zombies', point: 'Apparition', kind: 'zones', category: false, modified: false,
      hint: 'Centre et rayon de chaque zone zombies, et points où ils apparaissent. Les zombies déjà là restent jusqu\'à leur mort ou au départ des joueurs.',
      value: [
        {
          id: 'port', label: 'Port de Los Santos', center: { x: 1050, y: -3100, z: 5.9, w: 0 }, radius: 140,
          spawns: [{ x: 1020, y: -3080, z: 5.9, w: 0 }, { x: 1060, y: -3120, z: 5.9, w: 90 }],
        },
      ],
    },
    {
      name: 'pvpControlZones', group: 'pvp', label: 'Zones de contrôle', kind: 'zones', category: false, modified: false,
      hint: 'Centre et rayon de chaque zone à capturer. Une zone déplacée garde son propriétaire.',
      value: [
        { id: 'quarry', label: 'Carrière de Davis', center: { x: 2950, y: 2790, z: 41, w: 0 }, radius: 45 },
        { id: 'refinery', label: 'Raffinerie de Murrieta', center: { x: 1450, y: -2150, z: 60, w: 0 }, radius: 40 },
      ],
    },
    {
      name: 'pvpConflictZones', group: 'pvp', label: 'Zones de conflit', kind: 'zones', category: false, modified: false,
      hint: 'Centre et rayon de chaque zone de conflit, tirée au sort. Reste loin des zones safe et des zones zombies. Une zone en cours se déplace aussitôt.',
      value: [
        { id: 'mirror_park', label: 'Mirror Park', center: { x: 1150, y: -640, z: 57, w: 0 }, radius: 110 },
        { id: 'vespucci', label: 'Plage de Vespucci', center: { x: -1300, y: -1500, z: 4.4, w: 0 }, radius: 120 },
      ],
    },
    {
      name: 'airdropLocations', group: 'pvp', label: 'Largages', point: 'Point de chute', flat: true, kind: 'points', category: false, modified: false,
      hint: 'Une caisse tombe sur un de ces points, tiré au sort. Choisis des endroits dégagés : la hauteur est recalée sur le sol.',
      value: [
        { x: 501, y: 5604, z: 797.9, w: 0 },
        { x: -150, y: 6350, z: 31.5, w: 0 },
      ],
    },
    {
      name: 'places', group: 'positions', label: 'PNJ et tableau', kind: 'places', category: false, modified: false,
      hint: 'PNJ des modes de jeu et tableau du classement. Place-toi à l\'endroit voulu : le PNJ (ou l\'écran) regardera dans la même direction que toi.',
      value: [
        { key: 'freeroam_hub/chase', label: 'PNJ · Course poursuite', coords: { x: 213.4, y: -943, z: 30.7, w: 60 } },
        { key: 'freeroam_hub/cvc', label: 'PNJ · CVC', coords: { x: 202.6, y: -925.5, z: 30.7, w: 150 } },
        { key: 'freeroam_hub/gunfight', label: 'PNJ · 1VS1 GunFight', coords: { x: 196.6, y: -912.6, z: 30.7, w: 180 } },
        { key: 'freeroam_hub/bike', label: 'PNJ · 1VS1 Bike', coords: { x: 190, y: -914, z: 30.7, w: 180 } },
        { key: 'freeroam_hub/gungame', label: 'PNJ · Gungame', coords: { x: 184, y: -915.5, z: 30.7, w: 180 } },
        { key: 'chase/board', label: 'Tableau du classement · Course poursuite', coords: { x: 216.4, y: -944.8, z: 30.7, w: 60 } },
        { key: 'cvc/board', label: 'Tableau du classement · CVC', coords: { x: 204.1, y: -922.9, z: 30.7, w: 150 } },
        { key: 'gunfight/board', label: 'Tableau du classement · 1VS1 GunFight', coords: { x: 196.6, y: -909.6, z: 30.7, w: 180 } },
        { key: 'bike/board', label: 'Tableau du classement · 1VS1 Bike', coords: { x: 190.0, y: -911.0, z: 30.7, w: 180 } },
        { key: 'gungame/board', label: 'Tableau du classement · Gungame', coords: { x: 184.0, y: -912.5, z: 30.7, w: 180 } },
      ],
    },
    {
      name: 'chaseStarts', group: 'positions', label: 'Départs course poursuite', short: 'Course poursuite', point: 'Départ', kind: 'points', category: false, modified: true,
      hint: 'Un départ est tiré au sort à chaque manche : le voleur part ici, dans ta direction, le policier juste derrière.',
      value: [
        { x: 220, y: -1040, z: 29.2, w: 160 },
        { x: -1300, y: -420, z: 34.6, w: 125 },
        { x: 1110, y: -760, z: 57.7, w: 0 },
      ],
    },
    {
      name: 'cvcSpawns', group: 'positions', label: 'Spawns CVC', short: 'CVC', kind: 'arenas', category: false, modified: false,
      hint: 'Départ de chaque équipe dans chaque arène : les véhicules sont alignés derrière ce point, tournés vers le centre.',
      value: [
        { label: 'Désert de Senora', spawns: [{ x: 2050, y: 3050, z: 45, w: 0 }, { x: 2640, y: 3230, z: 50, w: 0 }] },
        { label: 'Port de Los Santos', spawns: [{ x: 820, y: -3020, z: 5.9, w: 0 }, { x: 1280, y: -3190, z: 5.9, w: 0 }] },
      ],
    },
    {
      name: 'gunfightSpawns', group: 'positions', label: 'Spawns 1VS1 GunFight', short: '1VS1 GunFight', kind: 'pair', category: false, modified: false,
      hint: 'Départ de chaque joueur (ils échangent de côté à chaque manche), dans ta direction : place-les face à face.',
      value: [{ x: 1000, y: -3090, z: 5.9, w: 270 }, { x: 1040, y: -3090, z: 5.9, w: 90 }],
    },
    {
      name: 'bikeSpawns', group: 'positions', label: 'Spawns 1VS1 Bike', short: '1VS1 Bike', kind: 'pair', category: false, modified: false,
      hint: 'Départ de chaque moto (les joueurs échangent de côté à chaque manche), dans ta direction : place-les loin l\'un de l\'autre.',
      value: [{ x: 1300, y: 3120, z: 40.4, w: 286 }, { x: 1640, y: 3220, z: 41, w: 106 }],
    },
    {
      name: 'gungameSpawns', group: 'positions', label: 'Spawns Gungame', short: 'Gungame', point: 'Apparition', kind: 'points', category: false, modified: false,
      hint: 'Points d\'apparition des joueurs, dans ta direction : on réapparaît sur celui le plus loin des autres.',
      value: [
        { x: 1020, y: -3045, z: 5.9, w: 180 },
        { x: 1065, y: -3090, z: 5.9, w: 90 },
        { x: 1020, y: -3135, z: 5.9, w: 0 },
        { x: 975, y: -3090, z: 5.9, w: 270 },
      ],
    },
    ...['port', 'scrapyard', 'sawmill', 'map1'].flatMap((map) => [
      { key: 'alpha', short: 'Départs 1', point: 'Apparition', letters: false, count: 5, min: 2, hint: 'Apparitions du premier camp, dans ta direction.' },
      { key: 'bravo', short: 'Départs 2', point: 'Apparition', letters: false, count: 5, min: 2, hint: 'Apparitions du second camp, dans ta direction.' },
      { key: 'flags', short: 'Drapeaux', point: 'Drapeau', letters: true, count: 3, min: 3, hint: "Drapeaux de la Domination : A, B, C dans l'ordre de la liste. Évite de les placer à côté des départs." },
      { key: 'sites', short: 'Sites de bombe', point: 'Site', letters: true, count: 2, min: 2, hint: "Sites de Recherche & Destruction : A, B dans l'ordre de la liste." },
    ].map(({ key, count, ...list }): FreeroamSetting => ({
      ...list,
      name: `cod_${map}_${key}`, group: 'cod', label: `${map} · ${list.short}`, map, kind: 'points', category: false, modified: map === 'port' && key === 'flags',
      value: map === 'map1' && key !== 'alpha' ? [] : Array.from({ length: count }, (_, index) => ({ x: 995 + index * 15, y: -3045, z: 5.9, w: 180 })),
    }))),
  ],
  codMaps: [
    { id: 'port', label: 'Terminal', place: 'Port de Los Santos', radius: 85, enabled: true, custom: false },
    { id: 'scrapyard', label: 'La Casse', place: 'Rogers Salvage, La Puerta', radius: 70, enabled: false, custom: false },
    { id: 'sawmill', label: 'La Scierie', place: 'Paleto Bay', radius: 80, enabled: true, custom: false },
    { id: 'map1', label: 'Aéroport', place: 'LSIA', radius: 120, enabled: true, custom: true },
  ],
  codMapsRemoved: [{ id: 'construction', label: 'Le Chantier' }],
};
import type { CaseDefinition, CaseReelEntry, LeaderboardRow, LobbyMode, Vitals, MarketState, ResaleState } from '../types/game';

/** Ouverture de caisse hors jeu : même tirage pondéré que CaseService.roll côté serveur */
export function mockCaseReel(definition: CaseDefinition, length = 56): CaseReelEntry[] {
  const total = definition.rewards.reduce((sum, reward) => sum + reward.weight, 0);
  return Array.from({ length }, () => {
    let target = Math.random() * total;
    const reward = definition.rewards.find((r) => (target -= r.weight) < 0) ?? definition.rewards[definition.rewards.length - 1];
    const count = Array.isArray(reward.count)
      ? reward.count[0] + Math.floor(Math.random() * (reward.count[1] - reward.count[0] + 1))
      : reward.count ?? 1;
    return { item: reward.item, count, rarity: reward.rarity };
  });
}

export const mockLobbyModes: LobbyMode[] = [
  {
    id: 'pvp',
    label: 'PvP',
    tagline: 'Survie & butin',
    description: 'Zones PvE, combats entre joueurs, inventaire perdu à la mort. Protège ce qui compte.',
    enabled: true,
    players: 12,
  },
  {
    id: 'freeroam',
    label: 'Freeroam',
    tagline: 'Liberté totale',
    description: 'Explore Los Santos librement, sans perte d\'équipement.',
    enabled: false,
    players: 0,
  },
  {
    id: 'cod',
    label: 'Call of Duty',
    tagline: 'Multijoueur',
    description: 'Parties rapides en équipes sur des cartes fermées : classes à composer, rangs à monter, séries d\'éliminations.',
    enabled: true,
    players: 8,
  },
];
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
    crew: { maxMembers: 20, createPrice: 5000, nameMaxLength: 24, maxTerritories: 2, territoryInterval: 300 },
    nameColors: {
      maxLetters: 32,
      list: [
        { code: 'r', label: 'Rouge', hex: '#E03232' },
        { code: 'o', label: 'Orange', hex: '#FF8555' },
        { code: 'y', label: 'Jaune', hex: '#F0C850' },
        { code: 'g', label: 'Vert', hex: '#72CC72' },
        { code: 'b', label: 'Bleu', hex: '#5DB6E5' },
        { code: 'p', label: 'Violet', hex: '#8466E2' },
        { code: 'q', label: 'Rose', hex: '#CB3694' },
      ],
    },
    killfeedBackgrounds: [
      { id: 'nuit', label: 'Bleu nuit', price: 200, css: 'rgba(28, 62, 130, 0.5)' },
      { id: 'bordeaux', label: 'Bordeaux', price: 200, css: 'rgba(105, 22, 40, 0.55)' },
      { id: 'kaki', label: 'Kaki', price: 200, css: 'rgba(66, 84, 40, 0.55)' },
      { id: 'violet', label: 'Violet', price: 200, css: 'rgba(82, 44, 135, 0.5)' },
      { id: 'braise', label: 'Braise', price: 400, css: 'linear-gradient(90deg, rgba(190, 60, 20, 0.6), rgba(90, 20, 15, 0.45))' },
      { id: 'ocean', label: 'Océan', price: 400, css: 'linear-gradient(90deg, rgba(15, 130, 160, 0.55), rgba(20, 45, 110, 0.5))' },
      { id: 'neon', label: 'Néon', price: 400, css: 'linear-gradient(90deg, rgba(190, 30, 130, 0.55), rgba(80, 40, 170, 0.5))' },
      { id: 'or', label: 'Or', price: 750, css: 'linear-gradient(90deg, rgba(190, 140, 30, 0.65), rgba(95, 65, 15, 0.5))' },
      { id: 'carbone', label: 'Carbone', price: 750, css: 'repeating-linear-gradient(135deg, rgba(55, 58, 62, 0.65) 0 0.25rem, rgba(15, 16, 18, 0.65) 0.25rem 0.5rem)' },
    ],
    shortcutSlots: 7,
    containers: {
      bag: { label: 'Mon sac', capacity: 50 },
      protected: { label: 'Conteneur protégé', capacity: 40 },
      stash: { label: 'Coffre 1', capacity: 500, safeOnly: true, order: 1 },
      stash2: { label: 'Coffre 2', capacity: 500, safeOnly: true, order: 2, price: 15000 },
      stash3: { label: 'Coffre 3', capacity: 500, safeOnly: true, order: 3, price: 50000 },
    },
    attachments: {
      att_suppressor: { weapon_pistol: 'COMPONENT_AT_PI_SUPP_02', weapon_carbinerifle: 'COMPONENT_AT_AR_SUPP' },
      att_scope: { weapon_carbinerifle: 'COMPONENT_AT_SCOPE_MEDIUM' },
    },
    recipes: [
      { id: 'bandage', result: { item: 'bandage', count: 2 }, ingredients: { mat_cloth: 3 }, level: 1 },
      { id: 'ammo_9mm', result: { item: 'ammo_9mm', count: 24 }, ingredients: { mat_powder: 4, mat_scrap: 1 }, level: 1 },
      { id: 'medkit', result: { item: 'medkit', count: 1 }, ingredients: { mat_cloth: 4, mat_chemicals: 2 }, level: 3 },
      { id: 'armor', result: { item: 'armor', count: 1 }, ingredients: { mat_scrap: 8, mat_cloth: 6 }, level: 5 },
    ],
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
      att_suppressor: { label: 'Silencieux', type: 'attachment', weight: 0.4 },
      att_scope: { label: 'Lunette', type: 'attachment', weight: 0.4 },
      att_extclip: { label: 'Chargeur grande capacité', type: 'attachment', weight: 0.5 },
      mat_cloth: { label: 'Tissu', type: 'material', weight: 0.05 },
      mat_scrap: { label: 'Ferraille', type: 'material', weight: 0.2 },
      mat_powder: { label: 'Poudre', type: 'material', weight: 0.02 },
      mat_chemicals: { label: 'Produits chimiques', type: 'material', weight: 0.1 },
      case_street: { label: 'Caisse de rue', type: 'case', weight: 0.5 },
      case_elite: { label: 'Caisse d\'élite', type: 'case', weight: 0.5 },
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
    caseRarities: {
      common: { label: 'Commun', color: '#a7ada4', order: 1 },
      uncommon: { label: 'Peu commun', color: '#6fcf6a', order: 2 },
      rare: { label: 'Rare', color: '#4f8dff', order: 3 },
      epic: { label: 'Épique', color: '#b36bff', order: 4 },
      legendary: { label: 'Légendaire', color: '#ff9f1c', order: 5 },
    },
    shopPoints: { label: 'Points boutique', short: 'PB', storeUrl: 'https://example.tebex.io' },
    classes: {
      keyLabel: 'G',
      list: [
        {
          id: 'tank',
          label: 'Tank',
          icon: 'armor',
          summary: 'Mur vivant : encaisse en première ligne et tient les positions.',
          role: 'Première ligne, capture de zone',
          passives: [
            'Dégâts des zombies réduits de 30 %',
            'Corps à corps : +30 %',
            'Ne peut pas être renversé à pied'
          ],
          signature: [ 'weapon_bat', 'weapon_pumpshotgun', 'heavy_kevlar' ],
          health: 170,
          speed: 85,
          damage: 0.8,
          ability: {
            id: 'roar',
            label: 'Rugissement',
            description: 'Renverse et étourdit les zombies autour de toi (zone zombies).',
            cooldown: 45
          }
        },
        {
          id: 'assault',
          label: 'Assaut',
          icon: 'knife',
          summary: 'Spécialiste de la mêlée : le plus dangereux au contact.',
          role: 'Percée, combat rapproché',
          passives: [ 'Corps à corps : +20 %', 'Armes à feu : dégâts normaux' ],
          signature: [ 'weapon_machete', 'weapon_battleaxe', 'weapon_sawnoffshotgun' ],
          health: 110,
          damageLabel: '120 mêlée',
          ability: {
            id: 'frenzy',
            label: 'Frénésie',
            description: 'Corps à corps : +30 % pendant 10 s.',
            cooldown: 45
          }
        },
        {
          id: 'demolisher',
          label: 'Démolisseur',
          icon: 'bomb',
          summary: 'Dégâts de zone : redoutable contre un groupe, faible en duel.',
          role: 'Nettoyage de hordes, assaut de position',
          passives: [ 'Fusils à pompe, armes lourdes et explosifs : +40 %', 'Autres armes et corps à corps : -30 %' ],
          signature: [ 'weapon_grenadelauncher', 'weapon_grenade', 'weapon_pumpshotgun' ],
          speed: 95,
          damage: 0.7,
          damageLabel: '140 zone / 70',
          ability: {
            id: 'blast',
            label: 'Charge explosive',
            description: "Fait exploser le point que tu vises, jusqu'à 40 m (zone zombies). Attention à ton équipe.",
            cooldown: 60
          }
        },
        {
          id: 'mercenary',
          label: 'Mercenaire',
          icon: 'contract',
          summary: 'Chasseur de primes : spécialiste du combat entre joueurs.',
          role: 'Agressif, chasse et contestation',
          passives: [ 'Contre les joueurs : dégâts +25 %' ],
          signature: [ 'weapon_pistol50', 'weapon_assaultrifle', 'weapon_carbinerifle' ],
          health: 90,
          speed: 105,
          damageLabel: '100 (+25 % PvP)',
          ability: {
            id: 'contract',
            label: 'Contrat',
            description: 'Suit pendant 30 s le joueur le plus recherché, sinon le plus proche. Il en est prévenu.',
            cooldown: 180
          }
        },
        {
          id: 'scout',
          label: 'Éclaireur',
          icon: 'crosshair',
          summary: 'Détection et tir de précision : fragile, mais voit le danger avant les autres.',
          role: 'Repérage, élimination à distance',
          passives: [
            'Radar : zombies et ennemis à moins de 60 m sur la minimap, hors zones safe',
            'Fusils de précision : +30 %, autres armes : -20 %'
          ],
          signature: [ 'weapon_sniperrifle', 'weapon_marksmanrifle', 'att_suppressor' ],
          health: 85,
          speed: 110,
          damage: 0.8,
          damageLabel: '130 précision / 80',
          ability: {
            id: 'mark',
            label: 'Marquage',
            description: 'Marque ce que tu vises pour ton équipe pendant 15 s. La nuit, active aussi la vision nocturne.',
            cooldown: 30
          }
        },
        {
          id: 'medic',
          label: 'Médecin',
          icon: 'bandage',
          summary: 'Soutien : soigne son équipe et la protège des infections.',
          role: 'Soutien à protéger, très recherché en groupe',
          passives: [ 'Soins consommés : +50 %', 'Tes soins profitent à moitié aux coéquipiers à moins de 10 m' ],
          signature: [ 'weapon_pistol', 'weapon_combatpistol', 'medkit' ],
          health: 95,
          damage: 0.7,
          ability: {
            id: 'antidote',
            label: 'Antidote',
            description: 'Immunise ton équipe proche contre le vomi et les gaz pendant 45 s.',
            cooldown: 120
          }
        },
        {
          id: 'engineer',
          label: 'Ingénieur',
          icon: 'craft',
          summary: 'Fabrication et défense : fait plus avec moins de matériaux.',
          role: 'Défense, contrôle de zone',
          passives: [ "Fabrication : ingrédients réduits d'un tiers", 'Piège électrique : 50 % plus long' ],
          signature: [ 'weapon_wrench', 'weapon_hammer', 'weapon_microsmg' ],
          speed: 95,
          damage: 0.8,
          craftCost: 0.66666666666667,
          ability: {
            id: 'trap',
            label: 'Piège électrique',
            description: 'Pose à tes pieds un piège qui bloque les zombies pendant 38 s (zone zombies).',
            cooldown: 75
          }
        },
        {
          id: 'logistician',
          label: 'Logisticien',
          icon: 'inventory',
          summary: 'Ravitailleur : transporte plus et couvre les replis.',
          role: 'Transport du butin, couverture du groupe',
          passives: [ 'Sac : 20 kg de capacité en plus' ],
          signature: [ 'weapon_combatpistol', 'weapon_smokegrenade', 'repairkit' ],
          health: 90,
          damage: 0.75,
          ability: {
            id: 'smoke',
            label: 'Écran de fumée',
            description: 'Fumée épaisse à tes pieds pendant 20 s pour couvrir un repli.',
            cooldown: 90
          }
        }
      ],
    },
    cases: [
      {
        id: 'case_street',
        label: 'Caisse de rue',
        description: 'Le kit de survie du quartier : munitions, soins et une petite chance de gros lot.',
        price: 750,
        points: 100,
        rewards: [
          { item: 'ammo_9mm', count: [48, 96], weight: 22, rarity: 'common' },
          { item: 'bandage', count: [3, 5], weight: 18, rarity: 'common' },
          { item: 'money', count: [300, 600], weight: 12, rarity: 'common' },
          { item: 'medkit', count: [2, 3], weight: 8, rarity: 'uncommon' },
          { item: 'weapon_pistol', weight: 10, rarity: 'uncommon' },
          { item: 'armor', weight: 3, rarity: 'rare' },
          { item: 'weapon_pumpshotgun', weight: 4, rarity: 'rare' },
          { item: 'att_suppressor', weight: 0.8, rarity: 'epic' },
          { item: 'weapon_carbinerifle', weight: 0.3, rarity: 'legendary' },
        ],
      },
      {
        id: 'case_elite',
        label: 'Caisse d\'élite',
        description: 'Le haut du panier : armes Mk II, snipers lourds et véhicules blindés.',
        price: 12000,
        points: 800,
        level: 12,
        rewards: [
          { item: 'money', count: [5000, 8000], weight: 18, rarity: 'common' },
          { item: 'armor', count: 2, weight: 14, rarity: 'common' },
          { item: 'weapon_carbinerifle', weight: 10, rarity: 'uncommon' },
          { item: 'att_scope', weight: 5, rarity: 'rare' },
          { item: 'att_suppressor', weight: 2, rarity: 'epic' },
          { item: 'weapon_pumpshotgun', weight: 0.5, rarity: 'legendary' },
        ],
      },
    ],
  },
  player: {
    source: 1,
    name: 'Dev',
    streak: 6,
    bounty: 1250,
    season: { label: 'Saison octobre 2026', kills: 9, deaths: 4, npcKills: 141 },
    contracts: {
      resetIn: 18720,
      list: [
        { id: 'zombies_20', label: 'Tue 20 zombies', goal: 20, progress: 13, done: false, reward: { money: 400, xp: 150 } },
        { id: 'airdrop_1', label: 'Fouille un largage aérien', goal: 1, progress: 1, done: true, reward: { money: 700, xp: 250 } },
        { id: 'craft_5', label: 'Fabrique 5 objets', goal: 5, progress: 2, done: false, reward: { money: 300, xp: 150 } },
      ],
    },
    money: 33851,
    shopPoints: 450,
    killfeedOwned: ['nuit'],
    playerClass: { id: 'scout', cooldown: 12, changeIn: 0 },
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
        att_suppressor: 1,
        mat_cloth: 7,
        mat_scrap: 3,
        mat_powder: 9,
        case_street: 3,
      },
      protected: { money: 33327, medkit: 2, ammo_9mm: 40 },
      stash: { weapon_smg: 1, ammo_45acp: 180, medkit: 4, armor: 2, money: 120000 },
      stash2: { mat_scrap: 40, case_street: 2 },
      stash3: [],
      unlocked: { stash2: true },
      shortcuts: ['weapon_pistol', 'weapon_carbinerifle', false, false, false, 'medkit', false],
    },
  },
  zone: { id: 'legion', label: 'Zone safe - Legion Square', type: 'safe' },
};

export const mockMarket: MarketState = {
  balance: 2375,
  fee: 0.05,
  maxListings: 10,
  listings: [
    { id: 12, item: 'weapon_carbinerifle', count: 1, price: 4200, sellerName: 'Bravo', mine: false },
    { id: 13, item: 'weapon_carbinerifle', count: 1, price: 3900, sellerName: 'Kilo', mine: false },
    { id: 14, item: 'weapon_carbinerifle', count: 1, price: 4999, sellerName: 'Echo', mine: false },
    { id: 15, item: 'weapon_pistol', count: 1, price: 350, sellerName: 'Nova', mine: false },
    { id: 16, item: 'weapon_pistol', count: 2, price: 600, sellerName: 'Delta', mine: false },
    { id: 17, item: 'armor', count: 1, price: 750, sellerName: 'Mike', mine: false },
    { id: 11, item: 'ammo_556', count: 120, price: 450, sellerName: 'Nova', mine: false },
    { id: 10, item: 'medkit', count: 3, price: 900, sellerName: 'Kilo', mine: false },
    { id: 9, item: 'att_suppressor', count: 1, price: 2100, sellerName: 'Alpha', mine: false },
    { id: 8, item: 'mat_scrap', count: 20, price: 300, sellerName: 'Dev', mine: true },
  ],
};

export const mockResale: ResaleState = {
  prices: {
    weapon_pistol: 200,
    weapon_carbinerifle: 2750,
    ammo_9mm: 1,
    ammo_556: 2,
    medkit: 175,
    bandage: 50,
    armor: 400,
    mat_scrap: 8,
    mat_cloth: 5,
    vehicle_panto: 300,
  },
};

/** Onglet « Revente » du panneau admin (hors jeu) */
export const mockResaleAdmin: ResaleAdminData = {
  ok: true,
  maxPrice: 1000000,
  items: [
    { name: 'ammo_556', label: 'Munitions de fusil', type: 'ammo', price: 2, default: 2, shop: 4.17 },
    { name: 'ammo_9mm', label: 'Munitions de pistolet', type: 'ammo', price: 1, default: 1, shop: 1.67 },
    { name: 'bandage', label: 'Bandage', type: 'consumable', price: 50, default: 50, shop: 100 },
    { name: 'case_street', label: 'Caisse de rue', type: 'case', price: 375, default: 375, shop: 750 },
    { name: 'mat_scrap', label: 'Ferraille', type: 'material', price: 8, default: 8, shop: false },
    { name: 'medkit', label: 'Trousse de soins', type: 'consumable', price: 175, default: 175, shop: 350 },
    { name: 'weapon_carbinerifle', label: 'Carabine', type: 'weapon', price: 3000, default: 2750, shop: 5500 },
    { name: 'weapon_pistol', label: 'Pistolet', type: 'weapon', price: 450, default: 200, shop: 400 },
    { name: 'att_scope', label: 'Lunette', type: 'attachment', price: 750, default: 750, shop: 1500 },
    { name: 'vehicle_panto', label: 'Panto', type: 'vehicle', price: 300, default: 300, shop: false },
  ],
};

/** Onglet « Boutique » du panneau admin (hors jeu) */
export const mockShopAdmin: ShopAdminData = {
  ok: true,
  maxPrice: 10000000,
  items: [
    { name: 'weapon_pistol', label: 'Pistolet', type: 'weapon', count: 1, price: 400, default: 400, resale: 450, resaleFollows: false },
    { name: 'weapon_carbinerifle', label: 'Carabine', type: 'weapon', count: 1, price: 6000, default: 5500, resale: 3000, resaleFollows: true },
    { name: 'ammo_9mm', label: 'Munitions de pistolet', type: 'ammo', count: 48, price: 80, default: 80, resale: 48, resaleFollows: true },
    { name: 'ammo_556', label: 'Munitions de fusil', type: 'ammo', count: 60, price: 250, default: 250, resale: 120, resaleFollows: true },
    { name: 'att_scope', label: 'Lunette', type: 'attachment', count: 1, price: 1500, default: 1500, resale: 750, resaleFollows: true },
    { name: 'medkit', label: 'Trousse de soins', type: 'consumable', count: 1, price: 350, default: 350, resale: 175, resaleFollows: true },
    { name: 'vehicle_faggio', label: 'Faggio', type: 'vehicle', count: 1, price: 600, default: 600, resale: 300, resaleFollows: true },
  ],
};

export const mockLeaderboard: LeaderboardRow[] = [
  { name: 'Alpha', level: 8, xp: 7400, kills: 54, deaths: 20, npcKills: 120, online: true },
  { name: 'Bravo', level: 5, xp: 4100, kills: 31, deaths: 28, npcKills: 64, online: false },
  { name: 'Dev', level: 3, xp: 2450, kills: 12, deaths: 5, npcKills: 34, online: true },
];

/** Onglet « Butin » du panneau admin (hors jeu) */
export const mockLootAdmin: LootAdminData = {
  ok: true,
  tables: [
    {
      name: 'airdrop', label: 'Largages', money: [600, 1500], usedBy: ['Largages aériens'], modified: false,
      drops: [
        { item: 'medkit', count: [2, 4], chance: 90 },
        { item: 'armor', count: [1, 3], chance: 85 },
        { item: 'weapon_carbinerifle', count: [1, 1], chance: 45 },
        { item: 'ammo_556', count: [90, 180], chance: 70 },
      ],
    },
    {
      name: 'gang', label: 'Zombies — zones communes', money: [20, 80], usedBy: ['Aérodrome de Sandy Shores'], modified: true,
      drops: [
        { item: 'bandage', count: [1, 2], chance: 40 },
        { item: 'ammo_9mm', count: [12, 36], chance: 35 },
        { item: 'weapon_pistol', count: [1, 1], chance: 10 },
      ],
    },
    {
      name: 'military', label: 'Zombies — zones militaires', money: [60, 200], usedBy: ['Port de Los Santos'], modified: false,
      drops: [{ item: 'ammo_556', count: [30, 60], chance: 25 }],
    },
  ],
  zones: [
    { id: 'sandy_airfield', label: 'Aérodrome de Sandy Shores', loot: 'gang' },
    { id: 'port', label: 'Port de Los Santos', loot: 'military' },
  ],
  items: [
    { name: 'ammo_556', label: '5.56mm', type: 'ammo' },
    { name: 'ammo_9mm', label: '9mm', type: 'ammo' },
    { name: 'armor', label: 'Gilet pare-balles', type: 'consumable' },
    { name: 'bandage', label: 'Bandage', type: 'consumable' },
    { name: 'weapon_carbinerifle', label: 'Carabine', type: 'weapon' },
    { name: 'medkit', label: 'Trousse de soins', type: 'consumable' },
    { name: 'weapon_pistol', label: 'Pistolet', type: 'weapon' },
  ],
};
