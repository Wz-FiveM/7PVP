-- Zones de conflit (PvP) : de temps en temps, une zone apparaît sur la carte avec un compteur.
-- Un kill compte si le tueur et la victime sont dans le cercle. Le joueur qui a le plus de kills
-- est le team leader ; à la fin du compteur, il remporte l'argent, l'XP et le butin.
-- À égalité, le leader reste celui qui a atteint ce score le premier.
-- Les hauteurs (z) servent au marqueur : le client le recale sur le sol.
Config.ConflictZones = {
    enabled = true,
    firstDelay = 600, -- secondes avant la première zone après le démarrage
    interval = 1500, -- secondes entre le début de deux zones (plus long que duration)
    retryDelay = 120, -- secondes avant de réessayer s'il n'y a pas assez de joueurs
    duration = 600, -- secondes du compteur
    minPlayers = 2, -- joueurs en PvP nécessaires
    sameVictimDelay = 60, -- secondes avant qu'un kill sur la même victime compte à nouveau
    wallHeight = 40.0, -- hauteur du mur rouge autour de la zone
    adminRadius = 120.0, -- rayon d'une zone lancée par un admin sur lui
    reward = { money = 2000, xp = 500, loot = 'airdrop' }, -- loot : table de config/loot.lua
    blip = { sprite = 303, color = 1 },
    -- Loin des zones safe et des zones zombies (monde à part : on ne s'y croise pas)
    zones = {
        { id = 'mirror_park', label = 'Mirror Park', coords = vector3(1150.0, -640.0, 57.0), radius = 110.0 },
        { id = 'vespucci', label = 'Plage de Vespucci', coords = vector3(-1300.0, -1500.0, 4.4), radius = 120.0 },
        { id = 'galileo', label = 'Observatoire Galileo', coords = vector3(-430.0, 1130.0, 325.0), radius = 100.0 },
        { id = 'arena', label = 'Maze Bank Arena', coords = vector3(-260.0, -2030.0, 30.1), radius = 120.0 },
        { id = 'chumash', label = 'Chumash', coords = vector3(-3170.0, 1100.0, 20.8), radius = 110.0 },
        { id = 'stab_city', label = 'Stab City', coords = vector3(60.0, 3700.0, 39.7), radius = 110.0 },
        { id = 'grapeseed', label = 'Ferme de Grapeseed', coords = vector3(2450.0, 4950.0, 45.0), radius = 130.0 },
        { id = 'humane', label = 'Humane Labs', coords = vector3(3500.0, 3770.0, 30.0), radius = 120.0 },
    },
}
