-- Donjon (mode PvP) : parcours à objectifs joué en groupe, dans une instance privée (bucket à part).
-- /donjon ouvre une salle d'attente, le groupe la rejoint avec /donjon rejoindre, le chef lance avec
-- /donjon lancer. Chaque joueur a ses vies ; à la fin, chacun a son coffre et le temps de le vider.
--
-- Le parcours est une suite d'étapes (`steps`), jouées dans l'ordre et déplaçables en jeu (F10 > Positions) :
--   id, label     identifiant et nom dans le panneau
--   objective     objectif affiché, hint : précision sous l'objectif
--   type          ce qu'il faut faire, et à quoi servent les points `spawns` :
--     kill        tuer `count` zombies par joueur          spawns : apparition des zombies
--     fetch       trouver un objet caché                   spawns : cachettes, une tirée au sort
--     use         utiliser l'objet trouvé                  spawns[1] : la porte
--     destroy     détruire un mur en tirant dessus         spawns[1] : le mur
--     repair      réparer en maintenant E (`hold` s)       spawns[1] : la machine (rallume les lumières)
--     plant       poser les charges (`hold` s chacune)     spawns[1] : la porte, les suivants : les charges
--     boss        tuer le boss                             spawns[1] : le boss, les suivants : ses renforts
--     chest       coffre de fin, un par joueur             spawns : les coffres
--   coords, radius  centre de la salle : on y réapparaît une fois l'étape suivante atteinte
--   prop          modèle posé sur spawns[1] jusqu'à la fin de l'étape (keep : il reste ensuite)
--   item          modèle de l'objet caché (fetch) ou de la charge posée (plant)
Config.Dungeon = {
    enabled = true,
    bucketBase = 8000, -- buckets des salles : bucketBase + numéro de la salle
    maxRooms = 100,
    maxPlayers = 4,
    lives = 3, -- par joueur ; plus de vie : retour en zone safe
    duration = 1800, -- secondes pour finir le parcours
    exitDuration = 180, -- secondes pour vider son coffre, une fois le boss mort
    waitingTime = 300, -- secondes avant que la salle d'attente se ferme toute seule
    cooldown = 1200, -- secondes avant de pouvoir relancer un donjon (compté depuis le lancement, gardé jusqu'au redémarrage)
    leashDistance = 220.0, -- à cette distance de l'étape en cours, on est ramené au dernier point de reprise
    interactDistance = 2.5,
    chestDistance = 2.5,
    maxAlive = 25, -- zombies en même temps
    spawnPerTick = 3,
    hitDamage = 10, -- dégâts d'une balle sur un mur
    revealAfter = 90, -- secondes avant que l'objet caché s'affiche sur la carte
    fuse = 8, -- secondes entre la dernière charge et l'explosion
    explosion = { type = 23, shake = 1.0 }, -- sans dégâts
    sky = { hour = 1, minute = 0, weather = 'FOGGY' }, -- nuit imposée pendant tout le donjon
    chestModel = 'prop_ld_int_safe_01',
    blip = { sprite = 501, color = 1 },
    reward = { money = 5000, xp = 1500, loot = 'dungeon', model = 'prop_mil_crate_01' }, -- loot : table de config/loot.lua
    boss = {
        label = 'Boss',
        model = 's_m_y_blackops_01',
        weapon = 'WEAPON_SPECIALCARBINE',
        health = 2500,
        healthPerPlayer = 1500, -- par joueur en plus du premier
        armour = 100,
        accuracy = 35,
        adds = 8, -- renforts vivants en même temps
        loot = 'airdrop',
        lootRolls = 2,
    },
    -- Les zombies du donjon, comme une zone zombies (voir config/zones.lua)
    zone = {
        id = 'dungeon',
        type = 'pve',
        label = 'Donjon',
        modes = {},
        coords = vector3(1050.0, -3100.0, 5.9),
        radius = 140.0,
        npc = {
            health = 300,
            speed = 2.0,
            loot = 'military',
            models = { 'u_m_y_zombie_01', 's_m_y_dockwork_01', 'a_m_m_tramp_01', 's_m_m_dockwork_01', 'a_m_y_methhead_01' },
        },
    },
    -- Coffres personnels sur le parcours : les mêmes que chez le banquier (hauteur recalée sur le sol)
    chests = {
        vector3(1040.0, -3075.0, 5.9),
        vector3(1065.0, -3110.0, 5.9),
        vector3(1000.0, -3140.0, 5.9),
        vector3(1060.0, -3160.0, 5.9),
    },
    -- Parcours par défaut : le port, dans l'instance privée. À déplacer dans F10 > Positions.
    steps = {
        {
            id = 'room_1', type = 'kill', count = 8, label = 'Salle 1 : zombies',
            objective = 'Tue les zombies', hint = 'Le courant est coupé : reste près des autres.',
            coords = vector3(1020.0, -3080.0, 5.9), radius = 40.0,
            spawns = {
                vector4(1000.0, -3065.0, 5.9, 180.0), vector4(1040.0, -3065.0, 5.9, 180.0),
                vector4(1040.0, -3095.0, 5.9, 0.0), vector4(1000.0, -3095.0, 5.9, 0.0),
            },
        },
        {
            id = 'key_1', type = 'fetch', item = 'p_car_keys_01', label = 'Salle 1 : clé',
            objective = 'Trouve la clé', hint = 'Elle est cachée quelque part dans la salle.',
            coords = vector3(1020.0, -3080.0, 5.9), radius = 40.0,
            spawns = {
                vector4(1005.0, -3060.0, 5.9, 0.0), vector4(1045.0, -3090.0, 5.9, 0.0), vector4(995.0, -3085.0, 5.9, 0.0),
            },
        },
        {
            id = 'door_1', type = 'use', prop = 'prop_gate_docks_ld', label = 'Porte 1',
            objective = 'Utilise la clé sur la porte',
            coords = vector3(1055.0, -3090.0, 5.9), radius = 15.0,
            spawns = { vector4(1055.0, -3090.0, 5.9, 270.0) },
        },
        {
            id = 'room_2', type = 'kill', count = 12, label = 'Salle 2 : zombies',
            objective = 'Tue les zombies', hint = 'Ils sont entrés par la porte.',
            coords = vector3(1080.0, -3070.0, 5.9), radius = 40.0,
            spawns = {
                vector4(1100.0, -3050.0, 5.9, 180.0), vector4(1065.0, -3055.0, 5.9, 180.0), vector4(1095.0, -3085.0, 5.9, 0.0),
            },
        },
        {
            id = 'wall_1', type = 'destroy', health = 1500, healthPerPlayer = 750, prop = 'prop_container_01a', label = 'Mur 1',
            objective = 'Détruis le mur', hint = 'Tire dessus jusqu\'à ce qu\'il cède.', barLabel = 'Mur',
            coords = vector3(1080.0, -3100.0, 5.9), radius = 15.0, hitRadius = 9.0,
            spawns = { vector4(1080.0, -3100.0, 5.9, 0.0) },
        },
        {
            id = 'room_3', type = 'kill', count = 14, label = 'Salle 3 : zombies',
            objective = 'Tue les zombies',
            coords = vector3(1070.0, -3125.0, 5.9), radius = 40.0,
            spawns = {
                vector4(1060.0, -3120.0, 5.9, 90.0), vector4(1085.0, -3135.0, 5.9, 0.0), vector4(1050.0, -3140.0, 5.9, 0.0),
            },
        },
        {
            id = 'generator', type = 'repair', hold = 12, prop = 'prop_generator_01a', keep = true, label = 'Générateur',
            objective = 'Répare le générateur', hint = 'Maintiens E : tu reviens à zéro si tu lâches.',
            coords = vector3(1055.0, -3145.0, 5.9), radius = 15.0,
            spawns = { vector4(1055.0, -3145.0, 5.9, 90.0) },
        },
        {
            id = 'wall_2', type = 'destroy', health = 2000, healthPerPlayer = 1000, prop = 'prop_container_01a', label = 'Mur 2',
            objective = 'Détruis le mur', hint = 'Tire dessus jusqu\'à ce qu\'il cède.', barLabel = 'Mur',
            coords = vector3(1030.0, -3140.0, 5.9), radius = 15.0, hitRadius = 9.0,
            spawns = { vector4(1030.0, -3140.0, 5.9, 90.0) },
        },
        {
            id = 'room_4', type = 'kill', count = 16, label = 'Salle 4 : zombies',
            objective = 'Tue les zombies',
            coords = vector3(1010.0, -3125.0, 5.9), radius = 40.0,
            spawns = {
                vector4(985.0, -3150.0, 5.9, 270.0), vector4(1000.0, -3105.0, 5.9, 180.0), vector4(1025.0, -3110.0, 5.9, 180.0),
            },
        },
        {
            id = 'key_2', type = 'fetch', item = 'p_car_keys_01', label = 'Salle 4 : clé',
            objective = 'Trouve la clé', hint = 'Elle est cachée quelque part dans la salle.',
            coords = vector3(1005.0, -3135.0, 5.9), radius = 40.0,
            spawns = {
                vector4(990.0, -3120.0, 5.9, 0.0), vector4(1020.0, -3125.0, 5.9, 0.0), vector4(995.0, -3160.0, 5.9, 0.0),
            },
        },
        {
            id = 'door_2', type = 'use', prop = 'prop_gate_docks_ld', label = 'Porte 2',
            objective = 'Utilise la clé sur la porte', hint = 'Tu vois déjà ce qui t\'attend derrière.',
            coords = vector3(1015.0, -3160.0, 5.9), radius = 15.0,
            spawns = { vector4(1015.0, -3160.0, 5.9, 0.0) },
        },
        {
            id = 'room_5', type = 'kill', count = 20, label = 'Salle 5 : zombies',
            objective = 'Tue les zombies', hint = 'La horde arrive de partout.',
            coords = vector3(1040.0, -3180.0, 5.9), radius = 40.0,
            spawns = {
                vector4(1040.0, -3180.0, 5.9, 45.0), vector4(1015.0, -3190.0, 5.9, 270.0), vector4(1060.0, -3175.0, 5.9, 90.0),
            },
        },
        {
            id = 'c4', type = 'fetch', item = 'prop_c4_final_green', label = 'Salle 5 : C4',
            objective = 'Trouve le C4', hint = 'Il est caché quelque part dans la salle.',
            coords = vector3(1035.0, -3175.0, 5.9), radius = 40.0,
            spawns = {
                vector4(1060.0, -3165.0, 5.9, 0.0), vector4(1020.0, -3170.0, 5.9, 0.0), vector4(1045.0, -3195.0, 5.9, 0.0),
            },
        },
        {
            id = 'vault', type = 'plant', hold = 4, prop = 'v_ilev_bk_vaultdoor', item = 'prop_c4_final_green', label = 'Porte du coffre-fort',
            objective = 'Pose le C4 sur la porte', hint = 'Maintiens E sur chaque emplacement, puis éloigne-toi.',
            coords = vector3(1075.0, -3180.0, 5.9), radius = 15.0,
            spawns = {
                vector4(1075.0, -3180.0, 5.9, 90.0),
                vector4(1073.0, -3182.0, 5.9, 90.0), vector4(1073.0, -3180.0, 5.9, 90.0), vector4(1073.0, -3178.0, 5.9, 90.0),
            },
        },
        {
            id = 'boss', type = 'boss', label = 'Boss',
            objective = 'Tue le boss',
            coords = vector3(1095.0, -3175.0, 5.9), radius = 40.0,
            spawns = {
                vector4(1105.0, -3175.0, 5.9, 90.0),
                vector4(1085.0, -3195.0, 5.9, 0.0), vector4(1085.0, -3155.0, 5.9, 180.0), vector4(1115.0, -3190.0, 5.9, 0.0),
            },
        },
        {
            id = 'chest', type = 'chest', label = 'Coffres de fin',
            objective = 'Ouvre ton coffre', hint = 'Vide-le avant la fin du compteur.',
            coords = vector3(1095.0, -3175.0, 5.9), radius = 15.0,
            spawns = {
                vector4(1095.0, -3175.0, 5.9, 0.0), vector4(1099.0, -3175.0, 5.9, 0.0),
                vector4(1091.0, -3175.0, 5.9, 0.0), vector4(1095.0, -3171.0, 5.9, 0.0),
            },
        },
    },
}
