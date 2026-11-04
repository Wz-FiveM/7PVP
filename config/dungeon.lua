-- Donjon « Secret cave » (mode PvP) : joué en groupe, dans une instance privée (bucket à part).
-- On parle à James (config/npcs.lua) pour ouvrir le donjon, il faut `keys.count` clés sur soi. Le chef
-- invite avec /donjon invite <id>, chacun confirme avec /donjon pret, le chef lance avec /donjon lancer.
--
-- Le parcours se joue à pied dans les tunnels du braquage Doomsday (intérieurs du DLC, sans IPL à charger),
-- de hordes en hordes vers la base, puis dans son hangar : zombies, boss, butin.
--
-- Le parcours est une suite d'étapes (`steps`), jouées dans l'ordre et déplaçables en jeu (F10 > Positions) :
--   id, label     identifiant et nom dans le panneau
--   objective     objectif affiché, hint : précision sous l'objectif
--   type          ce qu'il faut faire, et à quoi servent les points `spawns` :
--     kill        tuer `count` zombies par joueur    spawns : apparition des zombies
--     destroy     détruire une porte en tirant       spawns[1] : la porte, les suivants : zombies (`adds` en même temps)
--     boss        tuer le boss                       spawns[1] : le boss, les suivants : ses renforts
--     chest       butin de fin, devant chaque joueur spawns : inutilisés
--   coords, radius  centre de l'étape : ses zombies n'apparaissent qu'une fois un joueur à `radius` de ce point
--   warp, heading l'étape ouvre une nouvelle salle : le groupe y est amené avec un fondu, tourné vers `heading`
--   checkpoint    point de reprise sans téléportation : on y réapparaît, tourné vers `heading`
--   prop          modèle posé sur spawns[1] jusqu'à la fin de l'étape
--
-- Les points du tunnel sont calculés sur l'axe de ses tronçons (origines relevées dans les dumps
-- DurtyFree/gta-v-data-dumps), 1 m sous ces origines : le sol est 2,5 à 4,5 m sous l'origine d'un tronçon (points
-- d'entrée connus du tunnel). Joueurs, zombies et objets sont recalés sur le sol. Les tronçons sont des IPL à
-- demander (config/ipls.lua).
Config.Dungeon = {
    enabled = true,
    label = 'Secret cave',
    bucketBase = 8000, -- buckets des salles : bucketBase + numéro de la salle
    maxRooms = 100,
    maxPlayers = 4,
    lives = 3, -- par joueur ; plus de vie : retour en zone safe
    duration = 1200, -- secondes pour finir le parcours
    exitDuration = 180, -- secondes pour vider son butin, une fois le boss mort
    waitingTime = 300, -- secondes avant que la salle d'attente se ferme toute seule
    keys = { item = 'dungeon_key', count = 7 }, -- par joueur, retirées au lancement (admins dispensés)
    leashDistance = 170.0, -- à cette distance de l'étape en cours, on est ramené au point de reprise
    maxAlive = 30, -- zombies en même temps
    spawnPerTick = 4,
    hitDamage = 10, -- dégâts d'une balle sur une porte
    sky = { hour = 1, minute = 0, weather = 'FOGGY' }, -- nuit imposée pendant tout le donjon
    blip = { sprite = 501, color = 1 },
    reward = { money = 5000, xp = 1500, loot = 'dungeon', rolls = 2, items = 4, model = 'prop_mil_crate_01' }, -- items : objets par joueur, tirés de la table `loot` de config/loot.lua
    -- Intérieurs gardés chargés pendant le donjon : le milieu de chaque tronçon, puis la base
    interiors = {
        vector3(914.1, 5646.8, -119.3),
        vector3(821.7, 5675.7, -129.7),
        vector3(746.4, 5738.6, -139.7),
        vector3(714.0, 5810.1, -147.5),
        vector3(700.3, 5868.9, -150.3),
        vector3(688.3, 5929.3, -151.7),
        vector3(619.47, 5974.29, -151.43),
        vector3(579.52, 5956.2, -153.0),
    },
    -- Bonbonnes : une balle les fait sauter, le souffle blesse les zombies et les joueurs.
    barrel = {
        models = { 'prop_gascyl_01a', 'prop_barrel_exp_01a' }, -- tour à tour
        hitRadius = 1.5, -- une balle à cette distance la touche
        chainRadius = 6.0, -- celles qui sont aussi près sautent avec elle
        chainDelay = 200, -- ms entre deux bonbonnes qui sautent à la suite
        explosion = { type = 23, damage = 2.0, shake = 1.0 }, -- 23 : bouteille de gaz, non bloquée par l'anticheat
    },
    barrels = {
        vector3(887.7, 5648.3, -122.3),
        vector3(846.0, 5669.6, -127.2),
        vector3(843.7, 5669.4, -127.4),
        vector3(815.6, 5674.4, -130.2),
        vector3(798.4, 5694.6, -132.7),
        vector3(766.4, 5710.8, -136.2),
        vector3(755.7, 5733.4, -138.7),
        vector3(753.6, 5734.3, -138.9),
        vector3(732.2, 5752.4, -141.7),
        vector3(721.1, 5799.7, -146.4),
        vector3(707.0, 5820.4, -148.6),
        vector3(707.7, 5821.8, -148.7),
        vector3(706.5, 5857.5, -150.3),
        vector3(695.2, 5874.1, -150.3),
        vector3(696.0, 5875.5, -150.3),
    },
    boss = {
        label = 'Mastodonte',
        type = 'dungeonBoss', -- entrée de Config.ZombieTypes : il se bat au corps à corps, comme un zombie
        model = 'u_m_y_imporage',
        health = 6000,
        healthPerPlayer = 3000, -- par joueur en plus du premier
        loot = 'airdrop',
        lootRolls = 2,
    },
    -- Les zombies du donjon, comme une zone zombies (voir config/zones.lua)
    zone = {
        id = 'dungeon',
        type = 'pve',
        label = 'Donjon',
        modes = {},
        coords = vector3(896.59, 5652.95, -123.66),
        radius = 140.0,
        npc = {
            health = 300,
            speed = 2.0,
            loot = 'military',
            models = { 'u_m_y_zombie_01', 's_m_y_dockwork_01', 'a_m_m_tramp_01', 's_m_m_dockwork_01', 'a_m_y_methhead_01' },
        },
    },
    -- Parcours par défaut. À ajuster en jeu dans F10 > Positions.
    steps = {
        {
            -- Entrée relevée en jeu (/interieur) dans le tronçon int_tun_30d_R d'origine 868.23, 5659.31, -123.68
            id = 'tunnel_1', type = 'kill', count = 10, label = 'Tunnel : entrée', warp = true, heading = 77.3,
            objective = 'Tue tous les zombies', hint = 'Tire sur les bonbonnes pour les faire sauter.',
            coords = vector3(896.59, 5652.95, -123.66), radius = 30.0,
            spawns = {
                vector4(873.6, 5659.9, -124.5, 255.0), vector4(859.1, 5663.8, -126.0, 255.0),
                vector4(844.6, 5667.7, -127.5, 255.0), vector4(830.1, 5671.6, -128.9, 255.0),
            },
        },
        {
            id = 'tunnel_2', type = 'kill', count = 12, label = 'Tunnel : 2e horde',
            objective = 'Tue tous les zombies',
            coords = vector3(870.9, 5658.2, -124.4), radius = 25.0,
            spawns = {
                vector4(838.3, 5665.1, -127.7, 243.1), vector4(827.5, 5676.2, -129.2, 243.1),
                vector4(812.2, 5678.6, -130.7, 243.1), vector4(801.5, 5690.0, -132.2, 243.1),
            },
        },
        {
            id = 'tunnel_3', type = 'kill', count = 14, label = 'Tunnel : 3e horde', checkpoint = true, heading = 37.1,
            objective = 'Tue tous les zombies',
            coords = vector3(792.6, 5694.0, -133.2), radius = 25.0,
            spawns = {
                vector4(763.5, 5714.8, -136.7, 217.1), vector4(758.1, 5729.1, -138.2, 217.1),
                vector4(744.8, 5737.4, -139.7, 217.1), vector4(739.6, 5751.9, -141.2, 217.1),
            },
        },
        {
            id = 'tunnel_4', type = 'kill', count = 16, label = 'Tunnel : 4e horde',
            objective = 'Tue tous les zombies',
            coords = vector3(732.9, 5759.1, -142.2), radius = 25.0,
            spawns = {
                vector4(717.5, 5786.4, -145.3, 195.6), vector4(716.9, 5810.9, -147.5, 195.6),
                vector4(705.8, 5832.4, -149.7, 195.6), vector4(705.7, 5851.1, -150.3, 190.9),
            },
        },
        {
            id = 'tunnel_5', type = 'kill', count = 18, label = 'Tunnel : 5e horde',
            objective = 'Tue tous les zombies',
            coords = vector3(707.7, 5832.9, -149.7), radius = 25.0,
            spawns = {
                vector4(699.1, 5859.2, -150.3, 190.9), vector4(703.2, 5869.4, -150.3, 190.9),
                vector4(696.6, 5877.5, -150.3, 190.9), vector4(698.8, 5887.4, -150.3, 190.9),
            },
        },
        {
            id = 'door', type = 'destroy', label = 'Porte de la base', checkpoint = true, heading = 10.9,
            health = 1500, healthPerPlayer = 500, adds = 8, hitRadius = 9.0,
            prop = 'xm_prop_base_blast_door_01', barLabel = 'Porte de la base',
            objective = 'Détruis la porte', hint = 'Vide tes chargeurs dessus.',
            coords = vector3(697.4, 5884.0, -150.3), radius = 25.0,
            spawns = {
                vector4(690.2, 5920.2, -151.2, 11.6),
                vector4(692.1, 5895.5, -150.3, 190.9), vector4(696.8, 5902.7, -150.4, 191.6),
                vector4(690.7, 5907.8, -150.7, 191.6), vector4(693.7, 5912.8, -150.9, 191.6),
            },
        },
        {
            id = 'hangar', type = 'kill', count = 20, label = 'Hangar : zombies', warp = true, heading = 90.0,
            objective = 'Tue tous les zombies',
            coords = vector3(596.0, 5957.0, -151.0), radius = 30.0,
            spawns = {
                vector4(566.0, 5948.0, -153.0, 270.0), vector4(566.0, 5965.0, -153.0, 270.0),
                vector4(558.0, 5956.0, -153.0, 270.0), vector4(574.0, 5942.0, -153.0, 300.0),
            },
        },
        {
            id = 'boss', type = 'boss', label = 'Hangar : boss',
            objective = 'Tue le boss',
            coords = vector3(580.0, 5956.0, -153.0), radius = 30.0,
            spawns = {
                vector4(558.0, 5956.0, -153.0, 270.0),
                vector4(566.0, 5948.0, -153.0, 270.0), vector4(566.0, 5965.0, -153.0, 270.0), vector4(574.0, 5942.0, -153.0, 300.0),
            },
            adds = 6,
        },
        {
            id = 'chest', type = 'chest', label = 'Butin de fin',
            objective = 'Les loots sont up', hint = 'Ouvre ta caisse avant la fin du compteur.',
            coords = vector3(580.0, 5956.0, -153.0), radius = 30.0,
            spawns = { vector4(580.0, 5956.0, -153.0, 0.0) },
        },
    },
}
