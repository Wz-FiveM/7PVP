-- Mode Freeroam (bac à sable) : pas d'inventaire ni de perte, armes et véhicules gratuits
-- depuis le menu (Tab), PvP désactivé par défaut (chaque joueur l'active pour lui-même :
-- les dégâts entre deux joueurs ne passent que si les deux l'ont activé). Pas de zombies.
-- Modes de jeu lancés depuis les PNJ de la zone safe du Freeroam (config/npcs.lua, rôle 'activity').
-- enabled = false : le PNJ est là, mais le mode est affiché « Bientôt disponible ».
Config.FreeroamActivities = {
    cvc = {
        label = 'CVC',
        tagline = 'Combat par équipe',
        description = "Deux équipes s'affrontent en convoi, même kit pour tous et une seule vie par manche : la dernière équipe en vie gagne la manche. Première à 3 manches.",
        icon = 'group',
        enabled = true,
    },
    chase = {
        label = 'Course poursuite',
        tagline = '1 contre 1 · 2 manches',
        description = "Chacun vote pour un véhicule. Le voleur doit mettre 500 m entre lui et le policier en 3 minutes, sans repère ni distance affichée ; le policier gagne s'il l'immobilise 5 secondes. À la deuxième manche, on inverse les rôles et les véhicules.",
        icon = 'vehicle',
        enabled = true,
    },
    gunfight = {
        label = '1VS1 GunFight',
        tagline = 'Duel au pistolet · 3 manches',
        description = "Deux joueurs face à face, un pistolet chacun et une seule vie par manche : le premier qui tue l'autre gagne la manche. Premier à 3 manches.",
        icon = 'weapon',
        enabled = true,
    },
    bike = {
        label = '1VS1 Bike',
        tagline = 'Moto et pistolet · 3 manches',
        description = "Deux joueurs apparaissent chacun sur une moto, loin l'un de l'autre, avec un pistolet : à vous de vous rejoindre et de vous affronter. Une seule vie par manche, premier à 3 manches.",
        icon = 'vehicle',
        enabled = true,
    },
    gungame = {
        label = 'Gungame',
        tagline = 'Chacun pour soi · une arme par kill',
        description = "Tout le monde commence au pistolet : chaque kill te fait passer à l'arme suivante, jusqu'au couteau. Le premier qui fait un kill au couteau gagne. Attention : un coup de couteau te fait reculer d'une arme. Partie de 10 minutes, jusqu'à 12 joueurs, on peut la rejoindre en cours.",
        icon = 'crosshair',
        enabled = true,
    },
}

Config.Freeroam = {
    respawnDelay = 3, -- secondes avant de réapparaître sur place après une mort
    spawns = {
        vector4(-1037.7, -2737.6, 20.2, 330.0), -- aéroport de Los Santos
        vector4(-1388.0, -586.0, 30.2, 30.0), -- Del Perro
        vector4(215.8, -810.1, 30.7, 160.0), -- centre-ville
        vector4(1693.0, 3591.0, 35.6, 210.0), -- Sandy Shores
    },
    -- Armes proposées (munitions infinies)
    weapons = {
        { weapon = 'WEAPON_KNIFE', label = 'Couteau' },
        { weapon = 'WEAPON_BAT', label = 'Batte' },
        { weapon = 'WEAPON_PISTOL', label = 'Pistolet' },
        { weapon = 'WEAPON_HEAVYPISTOL', label = 'Pistolet lourd' },
        { weapon = 'WEAPON_MICROSMG', label = 'Micro SMG' },
        { weapon = 'WEAPON_SMG', label = 'SMG' },
        { weapon = 'WEAPON_PUMPSHOTGUN', label = 'Fusil à pompe' },
        { weapon = 'WEAPON_CARBINERIFLE', label = 'Carabine' },
        { weapon = 'WEAPON_ASSAULTRIFLE', label = 'Fusil d\'assaut' },
        { weapon = 'WEAPON_SNIPERRIFLE', label = 'Sniper' },
        { weapon = 'WEAPON_RPG', label = 'Lance-roquettes' },
        { weapon = 'WEAPON_GRENADE', label = 'Grenades' },
        { weapon = 'WEAPON_PARACHUTE', label = 'Parachute' },
    },
    -- Véhicules proposés (n'importe quel modèle GTA peut aussi être tapé dans le menu)
    vehicles = {
        { model = 'sultan', label = 'Sultan', category = 'Voitures' },
        { model = 'elegy2', label = 'Elegy RH8', category = 'Voitures' },
        { model = 'zentorno', label = 'Zentorno', category = 'Voitures' },
        { model = 'kuruma', label = 'Kuruma', category = 'Voitures' },
        { model = 'sanchez', label = 'Sanchez', category = 'Motos' },
        { model = 'bati', label = 'Bati 801', category = 'Motos' },
        { model = 'bf400', label = 'BF400', category = 'Motos' },
        { model = 'sandking', label = 'Sandking', category = 'Tout-terrain' },
        { model = 'mesa3', label = 'Mesa', category = 'Tout-terrain' },
        { model = 'buzzard2', label = 'Buzzard', category = 'Aérien' },
        { model = 'frogger', label = 'Frogger', category = 'Aérien' },
        { model = 'seashark', label = 'Seashark', category = 'Nautique' },
    },
}
