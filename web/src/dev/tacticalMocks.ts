import type { TacBoardRow, TacCatalog, TacDead, TacEnd, TacLineup, TacProfile, TacSelf, TacState } from '../types/tactical';

/** Copie de config/tactical.lua pour le navigateur */
export const mockTacCatalog: TacCatalog = {
  keys: { buy: 'B', abilityC: 'C', abilityQ: 'Q', ultimate: 'X' },
  roundsToWin: 7,
  divisions: [
    { min: 0, label: 'Bronze' }, { min: 1100, label: 'Argent' }, { min: 1250, label: 'Or' },
    { min: 1400, label: 'Platine' }, { min: 1550, label: 'Diamant' }, { min: 1700, label: 'Élite' },
  ],
  armor: [
    { id: 'light', label: 'Gilet léger', price: 400, value: 25 },
    { id: 'heavy', label: 'Gilet lourd', price: 1000, value: 50 },
  ],
  weapons: [
    { id: 'WEAPON_PISTOL', label: 'Pistolet', category: 'Pistolets', slot: 'secondary', price: 0, ammo: 72 },
    { id: 'WEAPON_COMBATPISTOL', label: 'Pistolet de combat', category: 'Pistolets', slot: 'secondary', price: 300, ammo: 72 },
    { id: 'WEAPON_HEAVYPISTOL', label: 'Pistolet lourd', category: 'Pistolets', slot: 'secondary', price: 500, ammo: 54 },
    { id: 'WEAPON_PISTOL50', label: 'Pistolet .50', category: 'Pistolets', slot: 'secondary', price: 800, ammo: 54 },
    { id: 'WEAPON_MICROSMG', label: 'Micro SMG', category: 'Mitraillettes', slot: 'primary', price: 1200, ammo: 180 },
    { id: 'WEAPON_SMG', label: 'SMG', category: 'Mitraillettes', slot: 'primary', price: 1600, ammo: 180 },
    { id: 'WEAPON_PUMPSHOTGUN', label: 'Fusil à pompe', category: 'Fusils à pompe', slot: 'primary', price: 1800, ammo: 40 },
    { id: 'WEAPON_ASSAULTSHOTGUN', label: 'Fusil à pompe d\'assaut', category: 'Fusils à pompe', slot: 'primary', price: 2400, ammo: 48 },
    { id: 'WEAPON_CARBINERIFLE', label: 'Carabine', category: 'Fusils d\'assaut', slot: 'primary', price: 2900, ammo: 210 },
    { id: 'WEAPON_ASSAULTRIFLE', label: 'Fusil d\'assaut', category: 'Fusils d\'assaut', slot: 'primary', price: 2900, ammo: 210 },
    { id: 'WEAPON_SPECIALCARBINE', label: 'Carabine spéciale', category: 'Fusils d\'assaut', slot: 'primary', price: 3200, ammo: 210 },
    { id: 'WEAPON_COMBATMG', label: 'Mitrailleuse de combat', category: 'Mitrailleuses', slot: 'primary', price: 3400, ammo: 300 },
    { id: 'WEAPON_MARKSMANRIFLE', label: 'Fusil de tireur d\'élite', category: 'Fusils de précision', slot: 'primary', price: 3600, ammo: 40 },
    { id: 'WEAPON_HEAVYSNIPER', label: 'Fusil de précision lourd', category: 'Fusils de précision', slot: 'primary', price: 4700, ammo: 20 },
  ],
  roles: [
    {
      id: 'scout', label: 'Éclaireur', description: 'Trouve les ennemis avant qu\'ils ne te trouvent.',
      abilities: {
        c: { id: 'sensor', label: 'Capteur', description: 'Lance un capteur qui révèle les ennemis proches à toute l\'équipe.', price: 200, max: 2 },
        q: { id: 'sprint', label: 'Course', description: 'Court beaucoup plus vite pendant quelques secondes.', free: 1, max: 1 },
        x: { id: 'scan', label: 'Balayage', description: 'Révèle tous les ennemis, trois fois de suite.', cost: 6 },
      },
    },
    {
      id: 'smoker', label: 'Artificier', description: 'Coupe les lignes de tir et aveugle les défenses.',
      abilities: {
        c: { id: 'smoke', label: 'Fumée', description: 'Un nuage épais au point visé, qui bloque la vue.', price: 100, max: 2 },
        q: { id: 'flash', label: 'Flash', description: 'Éclate au point visé et aveugle ceux qui la regardent.', price: 250, max: 1 },
        x: { id: 'curtain', label: 'Rideau', description: 'Trois fumées en ligne au point visé.', cost: 7 },
      },
    },
    {
      id: 'warden', label: 'Rempart', description: 'Tient un site et ralentit ceux qui le prennent.',
      abilities: {
        c: { id: 'alarm', label: 'Alarme', description: 'Piège posé à tes pieds : l\'ennemi qui passe est révélé et ralenti.', price: 200, max: 1 },
        q: { id: 'barrier', label: 'Barricade', description: 'Trois blocs de béton devant toi, pendant 30 secondes.', free: 1, max: 1 },
        x: { id: 'lockdown', label: 'Verrou', description: 'Après deux secondes, ralentit et révèle les ennemis de la zone visée.', cost: 7 },
      },
    },
    {
      id: 'medic', label: 'Soigneur', description: 'Garde l\'équipe en vie, et la relève.',
      abilities: {
        c: { id: 'heal', label: 'Soin', description: 'Soigne l\'allié visé, ou toi-même, en quelques secondes.', price: 150, max: 2 },
        q: { id: 'shield', label: 'Bouclier', description: 'Donne de l\'armure à l\'allié visé, ou à toi-même.', free: 1, max: 1 },
        x: { id: 'revive', label: 'Relève', description: 'Ramène à côté de toi le dernier allié tombé, avec ses armes.', cost: 7 },
      },
    },
  ],
};

export const mockTacProfile: TacProfile = {
  name: 'Dev', role: 'smoker', rating: 1288, division: 'Or', matches: 23, wins: 13, losses: 10,
  kills: 241, deaths: 198, assists: 77, plants: 19, defuses: 8, mvps: 5,
};

export const mockTacBoard: TacBoardRow[] = [
  { id: 1, name: 'Dev', division: 'Or', team: 'alpha', role: 'smoker', alive: true, kills: 14, deaths: 7, assists: 4, damage: 168, firstKills: 3, plants: 2, defuses: 0, score: 3988, ult: 5 },
  { id: 2, name: 'Kaze', division: 'Diamant', team: 'alpha', role: 'scout', alive: false, kills: 11, deaths: 9, assists: 6, damage: 141, firstKills: 2, plants: 1, defuses: 0, score: 3218, ult: 6 },
  { id: 3, name: 'Nyx', division: 'Argent', team: 'alpha', role: 'medic', alive: true, kills: 6, deaths: 8, assists: 9, damage: 98, firstKills: 0, plants: 0, defuses: 1, score: 2264, ult: 7 },
  { id: 4, name: 'Volt', division: 'Platine', team: 'bravo', role: 'warden', alive: true, kills: 12, deaths: 10, assists: 3, damage: 152, firstKills: 2, plants: 0, defuses: 2, score: 3482, ult: 2 },
  { id: 5, name: 'Raven', division: 'Or', team: 'bravo', role: 'smoker', alive: false, kills: 9, deaths: 11, assists: 5, damage: 120, firstKills: 1, plants: 0, defuses: 0, score: 2640, ult: 4 },
  { id: 6, name: 'Orca', division: 'Bronze', team: 'bravo', role: 'scout', alive: true, kills: 7, deaths: 12, assists: 2, damage: 87, firstKills: 1, plants: 0, defuses: 0, score: 1917, ult: 1 },
];

export const mockTacSelf: TacSelf = {
  mates: [
    { id: 2, name: 'Kaze', role: 'scout', money: 2150, primary: 'WEAPON_SMG', alive: true },
    { id: 3, name: 'Nyx', role: 'medic', money: 5600, primary: false, alive: true },
  ],
  alive: true,
  money: 4300,
  loadout: { primary: 'WEAPON_CARBINERIFLE', secondary: 'WEAPON_PISTOL', armor: 50 },
  bought: ['primary', 'ability:c'],
  charges: { c: 2, q: 0 },
  ult: 5,
  ultCost: 7,
  role: 'smoker',
};

export const mockTacState = (phase: TacState['phase'], bomb = false): TacState => ({
  phase,
  round: 9,
  remaining: bomb ? 31 : phase === 'buy' ? 24 : 74,
  attackers: 'bravo',
  scores: { alpha: 5, bravo: 3 },
  bomb: bomb ? { site: 'B' } : false,
  board: mockTacBoard,
});

export const mockTacEnd: TacEnd = {
  result: 'won',
  reason: 'Score atteint.',
  team: 'alpha',
  scores: { alpha: 7, bravo: 4 },
  board: mockTacBoard,
  mvp: 1,
  summary: {
    before: 1263, after: 1293, change: 30, division: 'Platine', promoted: true,
    profile: { ...mockTacProfile, rating: 1293, division: 'Or' },
  },
  seconds: 15,
};

export const mockTacLineup: TacLineup = {
  map: { label: 'Terminal', place: 'Port de Los Santos' },
  attackers: 'bravo',
  players: [
    { id: 1, name: 'Dev', team: 'alpha', role: 'smoker', rating: 1288, division: 'Or' },
    { id: 2, name: 'Kaze', team: 'alpha', role: 'scout', rating: 1612, division: 'Diamant' },
    { id: 3, name: 'Nyx', team: 'alpha', role: 'medic', rating: 1104, division: 'Argent' },
    { id: 4, name: 'Volt', team: 'bravo', role: 'warden', rating: 1420, division: 'Platine' },
    { id: 5, name: 'Raven', team: 'bravo', role: 'smoker', rating: 1251, division: 'Or' },
    { id: 6, name: 'Orca', team: 'bravo', role: 'scout', rating: 1000, division: 'Bronze' },
  ],
};

export const mockTacDead: TacDead = {
  killer: 'Volt',
  killerRole: 'warden',
  weapon: 'Carabine',
  report: [
    { id: 4, name: 'Volt', role: 'warden', killer: true, dealt: 52, dealtHits: 2, taken: 124, takenHits: 4 },
    { id: 6, name: 'Orca', role: 'scout', killer: false, dealt: 100, dealtHits: 3, taken: 26, takenHits: 1 },
  ],
};
