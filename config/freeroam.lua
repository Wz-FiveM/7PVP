-- Mode Freeroam (bac à sable) : pas d'inventaire ni de perte, armes et véhicules gratuits
-- depuis le menu (Verr. Maj), PvP désactivé par défaut (chaque joueur l'active pour lui-même :
-- les dégâts entre deux joueurs ne passent que si les deux l'ont activé). Pas de zombies.
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
