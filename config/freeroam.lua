-- Mode Freeroam (bac à sable) : pas d'inventaire ni de perte, armes et véhicules gratuits
-- depuis le menu (Verr. Maj), PvP désactivé par défaut (chaque joueur l'active pour lui-même :
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
        description = "Chacun vote pour un véhicule. Le voleur doit mettre 1,5 km entre lui et le policier en 3 minutes ; le policier gagne s'il l'immobilise 5 secondes. À la deuxième manche, on inverse les rôles et les véhicules.",
        icon = 'vehicle',
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
