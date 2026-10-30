import type { CodBoardEntry, CodCardAsset, CodCatalog, CodOperatorEntry, CodPlayerCardData, CodProfile } from '../types/cod';

/** Données factices du mode Call of Duty (npm run dev uniquement), extraites de config/cod.lua et cod_player_cards.lua. */
const prestigeAssets: CodCardAsset[] = Array.from({ length: 10 }, (_, index) => ({
  id: `prestige${index + 1}`, label: `Prestige ${index + 1}`, rank: 1, prestige: index + 1,
}));
const banners: CodCardAsset[] = [
  ['steel', 'Acier brossé', 1], ['woodland', 'Camouflage forêt', 1], ['desert', 'Camouflage désert', 1], ['digital', 'Camouflage urbain', 1],
  ['carbon', 'Carbone', 1], ['hazard', 'Zone dangereuse', 2], ['skyline', 'Los Santos', 4], ['radar', 'Balayage radar', 8],
  ['million', 'Un million', 6], ['flames', 'Fournaise', 11], ['thermal', 'Vision thermique', 14], ['arctic', 'Camouflage arctique', 17],
  ['storm', 'Orage', 20], ['skulls', 'Ossuaire', 23], ['circuit', 'Circuit imprimé', 26], ['squadron', 'Escadrille', 29],
  ['scope', 'Lunette de tir', 32], ['blood', 'Bain de sang', 36], ['chopper', 'Soleil couchant', 40], ['nuke', 'Champignon', 45],
  ['gold', 'Or massif', 50], ['legend', 'Légende', 55],
].map(([id, label, rank]) => ({ id, label, rank } as CodCardAsset)).concat(prestigeAssets);
const emblems: CodCardAsset[] = [
  ['star', 'Étoile', 1], ['skull', 'Crâne', 1], ['crosshair', 'Viseur', 1], ['shield', 'Écusson', 1], ['bolt', 'Éclair', 1],
  ['cherries', 'Cerises', 2], ['spade', 'As de pique', 3], ['heart', 'Cœur', 5], ['flame', 'Flamme', 7], ['dice', 'Dés', 9],
  ['grenade', 'Grenade à main', 12], ['knives', 'Couteaux', 15], ['clover', 'Trèfle', 18], ['anchor', 'Ancre', 21], ['eye', 'Œil', 24],
  ['dollar', 'Billet vert', 27], ['eightball', 'Boule 8', 30], ['moon', 'Lune', 33], ['helmet', 'Casque', 35], ['wings', 'Ailes', 38],
  ['radiation', 'Radiation', 41], ['pirate', 'Pavillon noir', 43], ['diamond', 'Diamant', 46], ['swords', 'Épées', 48], ['crown', 'Couronne', 51],
  ['medal', 'Médaille', 53], ['king', 'Roi des morts', 55],
].map(([id, label, rank]) => ({ id, label, rank } as CodCardAsset)).concat(prestigeAssets);

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
    { id: 'care_package', kills: 4, rank: 3, label: 'Colis de ravitaillement', description: 'Un colis tombe là où tu vises, avec une série au hasard.' },
    { id: 'counter_uav', kills: 4, rank: 1, label: 'Contre-drone', description: 'Coupe la carte des ennemis pendant 30 s.' },
    { id: 'sentry', kills: 5, rank: 5, label: 'Tourelle', description: 'Une tourelle devant toi tire seule sur les ennemis.' },
    { id: 'predator', kills: 5, rank: 1, label: 'Missile Predator', description: 'Guide un missile depuis ta tablette jusqu\'au sol.' },
    { id: 'precision', kills: 6, rank: 8, label: 'Frappe de précision', description: 'Des avions bombardent en ligne l\'endroit que tu choisis sur la carte.' },
    { id: 'harrier', kills: 7, rank: 14, label: 'Harrier', description: 'Bombarde l\'endroit que tu choisis sur la carte, puis reste sur place et tire.' },
    { id: 'helicopter', kills: 7, rank: 10, label: 'Hélicoptère d\'attaque', description: 'Un hélicoptère tourne au-dessus de la carte et tire sur les ennemis.' },
    { id: 'juggernaut', kills: 7, rank: 12, label: 'Juggernaut', description: 'Armure pleine et minigun jusqu\'à ta mort.' },
    { id: 'airdrop', kills: 8, rank: 17, label: 'Largage d\'urgence', description: 'Quatre colis tombent là où tu vises.' },
    { id: 'pave_low', kills: 9, rank: 22, label: 'Pave Low', description: 'Un hélicoptère blindé, plus puissant et plus résistant.' },
    { id: 'stealth', kills: 9, rank: 20, label: 'Bombardier furtif', description: 'Un long tapis de bombes, sans repère ni alerte pour les ennemis.' },
    { id: 'chopper_gunner', kills: 11, rank: 26, label: 'Hélico mitrailleur', description: 'Prends le minigun d\'un hélicoptère depuis ta tablette.' },
    { id: 'ac130', kills: 11, rank: 28, label: 'AC-130', description: 'Prends les trois canons d\'un AC-130 depuis ta tablette.' },
    { id: 'emp', kills: 15, rank: 34, label: 'EMP', description: 'Détruit les séries ennemies et bloque carte et séries pendant 60 s.' },
    { id: 'nuke', kills: 15, rank: 30, label: 'Frappe nucléaire', description: 'Après 10 s, ton camp remporte la partie.' },
  ],
  maxStreaks: 3,
  classNameLength: 20,
  banners,
  emblems,
  tagLength: 4,
  operators: [
    ['ghost_desert', 'Ghost Desert', 'Call of Duty', 1000, 'oliver8979', true],
    ['ghost_nightwar', 'Ghost NightWar', 'Call of Duty', 1200, 'Lee_Costumes', true],
    ['price_mw4', 'John Price', 'Call of Duty', 1200, 'YourWelshRaptor', true],
    ['venerated', 'Venerated US Army', 'Call of Duty', 1000, 'YourWelshRaptor', true],
    ['horangi', 'Horangi', 'Call of Duty', 1000, 'oliver8979', true],
    ['nikto', 'Nikto Dark Side', 'Call of Duty', 1000, 'kritbualad', true],
    ['templar', 'Templar', 'Call of Duty', 1000, 'kritbualad', true],
    ['witch_warden', 'Witch Warden', 'Call of Duty', 1000, 'oliver8979', false],
    ['spiderman', 'Spider-Man', 'Marvel', 1500, 'zio321', true],
    ['ultron', 'Ultron', 'Marvel', 1500, 'zio321', true],
    ['black_knight', 'Black Knight', 'Fortnite', 1200, 'kazuya4x4', true],
    ['drakon', 'Silverwing Drakon', 'Fortnite', 1200, 'zio321', true],
    ['naruto', 'Naruto Akatsuki', 'Naruto', 300, 'Kong2545', true],
    ['bull', 'Bull Comes', 'Original', 800, 'NcNc', true],
  ].map(([id, label, universe, price, credit, available]) => ({ id, label, universe, price, credit, available } as CodOperatorEntry)),
  maxPrestige: 10,
  prestigeTokens: 1,
  keys: { streak: 'G', class: 'B', scoreboard: 'TAB' },
};

const defaultPerks = ['lightweight', 'hardline', 'marathon'];

export const mockCodProfile: CodProfile = {
  name: 'Wezor',
  rank: 7,
  maxRank: 55,
  prestige: 0,
  tokens: 0,
  permanent: [],
  canPrestige: false,
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
  streaks: ['uav', 'predator'],
  card: { banner: 'million', emblem: 'cherries', tag: 'thic' },
  operator: false,
  ownedOperators: [],
  vipDays: 0,
};

/** Au rang maximum : le Prestige est disponible */
export const mockCodProfilePrestige: CodProfile = {
  ...mockCodProfile,
  rank: 55,
  xpInto: 0,
  xpNeeded: 0,
  prestige: 2,
  tokens: 1,
  permanent: ['WEAPON_COMBATMG', 'emp'],
  canPrestige: true,
  operator: 'ghost_nightwar',
  ownedOperators: ['price_mw4'],
  vipDays: 23,
};

export const mockCodCards: Record<string, CodPlayerCardData> = {
  rook: { name: 'Rook', tag: 'thic', banner: 'prestige7', emblem: 'prestige7', rank: 43, prestige: 7 },
  kaze: { name: 'Kaze', tag: 'KZ', banner: 'flames', emblem: 'skull', rank: 27, prestige: 2 },
  nyx: { name: 'Nyx', tag: '', banner: 'skyline', emblem: 'moon', rank: 12, prestige: 0 },
};

export const mockCodBoard: CodBoardEntry[] = [
  { id: 2, name: 'Kaze', rank: 27, prestige: 2, team: 'alpha', kills: 18, deaths: 6, assists: 4, score: 2150, alive: true },
  { id: 1, name: 'Wezor', rank: 7, prestige: 0, team: 'alpha', kills: 12, deaths: 8, assists: 3, score: 1640, alive: true },
  { id: 3, name: 'Nyx', rank: 12, prestige: 0, team: 'bravo', kills: 11, deaths: 10, assists: 2, score: 1320, alive: false },
  { id: 4, name: 'Rook', rank: 43, prestige: 7, team: 'bravo', kills: 7, deaths: 14, assists: 5, score: 980, alive: true },
];
