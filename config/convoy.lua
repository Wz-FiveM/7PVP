-- Convoi blindé : un fourgon suit une route, annoncé dans le chat et sur la carte. Détruit, ou son chauffeur
-- tué, il lâche son butin ; à la fin de la route ou du temps, il s'échappe. Le fourgon ne roule que si un
-- joueur est assez près pour le faire exister sur sa machine : loin de tout le monde, il attend sur place.
-- Routes et réglages à ajuster en jeu : les positions sont approximatives (/pvp_coords).
Config.Convoy = {
    enabled = true,
    firstDelay = 1800, -- secondes avant le premier passage après le démarrage
    interval = { 2700, 4500 }, -- secondes entre deux convois (au hasard)
    duration = 1200, -- secondes avant qu'il ne s'échappe
    minPlayers = 3, -- joueurs en PvP pour qu'il parte
    vehicle = 'stockade',
    driver = 's_m_m_armoured_01',
    speed = 18.0, -- m/s
    drivingStyle = 786603,
    arriveDistance = 40.0, -- mètres pour passer au point suivant
    destroyHealth = 100.0, -- santé du moteur en dessous de laquelle il est hors d'usage (1000 = neuf)
    wreckTime = 60, -- secondes que l'épave reste sur place
    blip = { sprite = 67, color = 1 },
    reward = { money = 5000, loot = 'airdrop' }, -- loot : table de config/loot.lua
    lootLifetime = 600, -- secondes
    routes = {
        { -- Route 68, de Harmony à Grapeseed
            vector4(615.0, 2700.0, 41.5, 270.0),
            vector3(1200.0, 2690.0, 38.0),
            vector3(1700.0, 3400.0, 37.0),
            vector3(1700.0, 4850.0, 42.0),
        },
        { -- Great Ocean Highway, de Paleto Bay à Chumash
            vector4(-150.0, 6350.0, 31.5, 135.0),
            vector3(-1500.0, 5100.0, 62.0),
            vector3(-2500.0, 3500.0, 30.0),
            vector3(-3100.0, 1200.0, 20.0),
        },
        { -- Des docks vers le nord de Los Santos
            vector4(1215.0, -3225.0, 5.8, 0.0),
            vector3(800.0, -2200.0, 29.0),
            vector3(1200.0, -1400.0, 35.0),
            vector3(1150.0, -500.0, 66.0),
        },
    },
}
