import type { CodBoardEntry, CodCatalog, CodProfile } from '../types/cod';

/** Données factices du mode Call of Duty (npm run dev uniquement), extraites de config/cod.lua. */
export const mockCodCatalog: CodCatalog = {
  playlists: [
    { id: 'tdm', label: 'Match à mort par équipe', short: 'MME', description: 'Deux équipes, réapparition immédiate : la première à 75 kills gagne.', teams: true, minPlayers: 2, maxPlayers: 12, time: 600, scoreLimit: 75 },
    { id: 'dom', label: 'Domination', short: 'DOM', description: 'Capturez et tenez les drapeaux : chaque drapeau rapporte des points à votre équipe.', teams: true, minPlayers: 2, maxPlayers: 12, time: 600, scoreLimit: 200 },
    { id: 'ffa', label: 'Mêlée générale', short: 'MG', description: 'Chacun pour soi : le premier à 30 kills gagne.', teams: false, minPlayers: 2, maxPlayers: 10, time: 600, scoreLimit: 30 },
    { id: 'snd', label: 'Recherche & Destruction', short: 'R&D', description: 'Une seule vie par manche. Les attaquants posent la bombe, les défenseurs la désamorcent.', teams: true, minPlayers: 2, maxPlayers: 10, time: 3600, scoreLimit: 4 },
  ],
  primary: [
    { id: 'WEAPON_CARBINERIFLE', label: 'Carabine', category: 'Fusils d\'assaut', rank: 1, ammo: 240 },
    { id: 'WEAPON_ASSAULTRIFLE', label: 'Fusil d\'assaut', category: 'Fusils d\'assaut', rank: 3, ammo: 240 },
    { id: 'WEAPON_SPECIALCARBINE', label: 'Carabine spéciale', category: 'Fusils d\'assaut', rank: 14, ammo: 240 },
    { id: 'WEAPON_SMG', label: 'SMG', category: 'Mitraillettes', rank: 1, ammo: 300 },
    { id: 'WEAPON_MICROSMG', label: 'Micro SMG', category: 'Mitraillettes', rank: 5, ammo: 300 },
    { id: 'WEAPON_PUMPSHOTGUN', label: 'Fusil à pompe', category: 'Fusils à pompe', rank: 1, ammo: 48 },
    { id: 'WEAPON_MG', label: 'Mitrailleuse', category: 'Mitrailleuses', rank: 8, ammo: 320 },
    { id: 'WEAPON_SNIPERRIFLE', label: 'Fusil de précision', category: 'Fusils de précision', rank: 1, ammo: 30 },
  ],
  secondary: [
    { id: 'WEAPON_PISTOL', label: 'Pistolet', category: 'Pistolets', rank: 1, ammo: 72 },
    { id: 'WEAPON_COMBATPISTOL', label: 'Pistolet de combat', category: 'Pistolets', rank: 2, ammo: 72 },
    { id: 'WEAPON_REVOLVER', label: 'Revolver', category: 'Pistolets', rank: 16, ammo: 36 },
  ],
  equipment: [
    { id: 'WEAPON_GRENADE', label: 'Grenade', category: 'Équipement', rank: 1, ammo: 2 },
    { id: 'WEAPON_MOLOTOV', label: 'Cocktail Molotov', category: 'Équipement', rank: 9, ammo: 2 },
  ],
  perks: [
    { id: 'lightweight', tier: 1, rank: 1, label: 'Agilité', description: 'Tu cours plus vite (+10 %).' },
    { id: 'scavenger', tier: 1, rank: 6, label: 'Charognard', description: 'Chaque kill recharge tes munitions.' },
    { id: 'hardline', tier: 2, rank: 1, label: 'Détermination', description: 'Tes séries demandent un kill de moins.' },
    { id: 'stopping', tier: 2, rank: 13, label: 'Force de frappe', description: 'Dégâts de tes balles : +15 %.' },
    { id: 'marathon', tier: 3, rank: 1, label: 'Marathon', description: 'Tu ne t\'essouffles jamais.' },
    { id: 'ghost', tier: 3, rank: 19, label: 'Fantôme', description: 'Tu restes invisible aux drones ennemis.' },
  ],
  streaks: [
    { id: 'uav', kills: 3, rank: 1, label: 'Drone', description: 'Les ennemis apparaissent sur la carte pendant 30 s.' },
    { id: 'counter_uav', kills: 4, rank: 3, label: 'Contre-drone', description: 'Coupe la carte des ennemis pendant 30 s.' },
    { id: 'airstrike', kills: 5, rank: 5, label: 'Frappe aérienne', description: 'Bombarde l\'endroit que tu vises.' },
    { id: 'juggernaut', kills: 7, rank: 12, label: 'Juggernaut', description: 'Armure pleine et minigun jusqu\'à ta mort.' },
    { id: 'nuke', kills: 15, rank: 30, label: 'Frappe nucléaire', description: 'Après 10 s, ton camp remporte la partie.' },
  ],
  maxStreaks: 3,
  classNameLength: 20,
  keys: { streak: 'G', class: 'B', scoreboard: 'TAB' },
};

const defaultPerks = ['lightweight', 'hardline', 'marathon'];

export const mockCodProfile: CodProfile = {
  name: 'Wezor',
  rank: 7,
  maxRank: 55,
  xp: 9400,
  xpInto: 620,
  xpNeeded: 2000,
  kills: 212,
  deaths: 174,
  assists: 48,
  wins: 19,
  losses: 12,
  bestStreak: 9,
  selected: 1,
  classes: [
    { name: 'Assaut', primary: 'WEAPON_CARBINERIFLE', secondary: 'WEAPON_PISTOL', equipment: 'WEAPON_GRENADE', perks: defaultPerks },
    { name: 'Mitraillette', primary: 'WEAPON_SMG', secondary: 'WEAPON_PISTOL', equipment: 'WEAPON_GRENADE', perks: defaultPerks },
    { name: 'Pompe', primary: 'WEAPON_PUMPSHOTGUN', secondary: 'WEAPON_PISTOL', equipment: 'WEAPON_GRENADE', perks: defaultPerks },
    { name: 'Précision', primary: 'WEAPON_SNIPERRIFLE', secondary: 'WEAPON_PISTOL', equipment: 'WEAPON_GRENADE', perks: defaultPerks },
    { name: 'Polyvalent', primary: 'WEAPON_CARBINERIFLE', secondary: 'WEAPON_PISTOL', equipment: false, perks: defaultPerks },
  ],
  streaks: ['uav', 'airstrike'],
};

export const mockCodBoard: CodBoardEntry[] = [
  { id: 2, name: 'Kaze', team: 'alpha', kills: 18, deaths: 6, assists: 4, score: 2150, alive: true },
  { id: 1, name: 'Wezor', team: 'alpha', kills: 12, deaths: 8, assists: 3, score: 1640, alive: true },
  { id: 3, name: 'Nyx', team: 'bravo', kills: 11, deaths: 10, assists: 2, score: 1320, alive: false },
  { id: 4, name: 'Rook', team: 'bravo', kills: 7, deaths: 14, assists: 5, score: 980, alive: true },
];
