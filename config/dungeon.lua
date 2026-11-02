-- Donjon (mode PvP) : parcours à objectifs joué en groupe, dans une instance privée (bucket à part).
-- /donjon ouvre une salle d'attente, le groupe la rejoint avec /donjon rejoindre, le chef lance avec
-- /donjon lancer. Chaque joueur a ses vies ; à la fin, chacun a son coffre et le temps de le vider.
--
-- Le parcours se joue dans les sous-sols du casino du braquage (intérieurs du DLC, sans IPL à charger).
-- Ces étages ne sont pas reliés entre eux dans le jeu et leurs portes sont fermées d'origine : quand une
-- étape a `warp`, le groupe passe dans la salle suivante avec un fondu, comme par un ascenseur.
-- Dans une salle, les objectifs restent près du point d'arrivée : une porte du décor peut ne pas s'ouvrir.
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
--     chest       coffre de fin, devant chaque joueur      spawns : inutilisés
--   coords, radius  centre de l'étape ; avec `warp`, c'est le point d'arrivée et de reprise de la salle
--   warp, heading l'étape ouvre une nouvelle salle : le groupe y est amené, tourné vers `heading`
--   prop          modèle posé sur spawns[1] jusqu'à la fin de l'étape (keep : il reste ensuite)
--   item          modèle de l'objet caché (fetch) ou de la charge posée (plant)
--
-- Les hauteurs sont celles du sol + 1 m, relevées sur le mobilier du jeu (dumps DurtyFree/gta-v-data-dumps) :
-- déchets -61.32, sécurité et laverie -59.72, bureaux -56.12, grand hall -40.12, coffre et tunnel -71.69.
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
    leashDistance = 75.0, -- à cette distance de l'étape en cours, on est ramené au point de reprise (chute sous la carte)
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
    -- Portes du décor ouvertes pendant le donjon : tout objet fin de cette taille, en mètres
    doors = {
        range = 30.0,
        interval = 1500,
        maxThickness = 0.5,
        width = { 0.6, 6.0 },
        height = { 1.8, 4.5 },
        -- Derrière, il n'y a que le vide de la cage
        keepClosed = {
            'ch_prop_ch_liftdoor_l_01a', 'ch_prop_ch_liftdoor_r_01a', 'ch_prop_ch_bay_elev_door', 'ch_prop_ch_hatch_liftshaft_01a',
        },
    },
    -- Intérieurs gardés chargés pendant le donjon (origines : ch_dlc_casino_back, hotel, vault, tunnel)
    interiors = {
        vector3(2523.3608, -270.0, -59.7231),
        vector3(2504.386, -257.2196, -40.123),
        vector3(2488.3477, -267.3637, -71.6456),
        vector3(2497.7075, -312.7705, -71.47),
    },
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
        coords = vector3(2548.0, -218.0, -60.32),
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
        vector3(2550.3, -220.0, -60.32), -- couloir des déchets
        vector3(2536.0, -274.5, -58.72), -- salle de sécurité
        vector3(2520.0, -263.5, -39.12), -- grand hall
        vector3(2484.0, -264.5, -70.69), -- hall du coffre
    },
    -- Parcours par défaut. À ajuster en jeu dans F10 > Positions.
    steps = {
        -- Sous-sol : le couloir des déchets
        {
            id = 'room_1', type = 'kill', count = 8, label = 'Sous-sol : zombies', warp = true, heading = 180.0,
            objective = 'Tue les zombies', hint = 'Le courant est coupé : reste près des autres.',
            coords = vector3(2548.0, -218.0, -60.32), radius = 35.0,
            spawns = {
                vector4(2548.0, -226.0, -60.32, 0.0), vector4(2548.0, -231.0, -60.32, 0.0),
                vector4(2545.5, -223.0, -60.32, 0.0), vector4(2550.0, -229.0, -60.32, 0.0),
            },
        },
        {
            id = 'key_1', type = 'fetch', item = 'p_car_keys_01', label = 'Sous-sol : clé',
            objective = 'Trouve la clé', hint = 'Elle est cachée quelque part dans la salle.',
            coords = vector3(2548.0, -222.0, -60.32), radius = 15.0,
            spawns = {
                vector4(2550.3, -216.0, -60.32, 0.0), vector4(2545.5, -220.0, -60.32, 0.0), vector4(2550.3, -226.5, -60.32, 0.0),
            },
        },
        {
            id = 'door_1', type = 'use', prop = 'ch_prop_ch_service_door_01a', label = 'Porte de service',
            objective = 'Utilise la clé sur la porte',
            coords = vector3(2548.0, -229.0, -60.32), radius = 15.0,
            spawns = { vector4(2548.0, -232.5, -60.32, 0.0) },
        },
        -- Salle de sécurité : les bureaux sombres
        {
            id = 'room_2', type = 'kill', count = 12, label = 'Salle de sécurité : zombies', warp = true, heading = 180.0,
            objective = 'Tue les zombies', hint = 'Ils sont entrés par la porte.',
            coords = vector3(2532.5, -273.5, -58.72), radius = 20.0,
            spawns = {
                vector4(2526.5, -275.0, -58.72, 0.0), vector4(2541.0, -281.0, -58.72, 0.0),
                vector4(2529.0, -283.0, -58.72, 0.0), vector4(2540.0, -274.0, -58.72, 0.0),
            },
        },
        {
            id = 'wall_1', type = 'destroy', health = 1500, healthPerPlayer = 750, prop = 'prop_fncply_01a', label = 'Mur de planches 1',
            objective = 'Détruis le mur', hint = 'Tire dessus jusqu\'à ce qu\'il cède.', barLabel = 'Mur',
            coords = vector3(2531.0, -278.0, -58.72), radius = 15.0, hitRadius = 5.0,
            spawns = { vector4(2530.0, -283.0, -58.72, 0.0) },
        },
        -- Laverie : le générateur
        {
            id = 'room_3', type = 'kill', count = 14, label = 'Laverie : zombies', warp = true, heading = 90.0,
            objective = 'Tue les zombies',
            coords = vector3(2536.8, -298.3, -58.72), radius = 15.0,
            spawns = {
                vector4(2532.0, -296.0, -58.72, 0.0), vector4(2542.0, -300.0, -58.72, 0.0),
                vector4(2531.0, -301.0, -58.72, 0.0), vector4(2543.0, -295.0, -58.72, 0.0),
            },
        },
        {
            id = 'generator', type = 'repair', hold = 12, prop = 'prop_generator_01a', keep = true, label = 'Générateur',
            objective = 'Répare le générateur', hint = 'Maintiens E : tu reviens à zéro si tu lâches.',
            coords = vector3(2536.8, -298.3, -58.72), radius = 15.0,
            spawns = { vector4(2541.5, -296.5, -58.72, 90.0) },
        },
        {
            id = 'wall_2', type = 'destroy', health = 2000, healthPerPlayer = 1000, prop = 'prop_fncply_01a', label = 'Mur de planches 2',
            objective = 'Détruis le mur', hint = 'Tire dessus jusqu\'à ce qu\'il cède.', barLabel = 'Mur',
            coords = vector3(2533.0, -298.0, -58.72), radius = 15.0, hitRadius = 5.0,
            spawns = { vector4(2529.2, -297.5, -58.72, 90.0) },
        },
        -- Grand hall de l'hôtel : on y remonte par l'escalier ; la clé traîne près des canapés
        {
            id = 'room_4', type = 'kill', count = 16, label = 'Grand hall : zombies', warp = true, heading = 90.0,
            objective = 'Tue les zombies',
            coords = vector3(2517.0, -262.0, -39.12), radius = 30.0,
            spawns = {
                vector4(2506.0, -262.0, -39.12, 0.0), vector4(2511.0, -265.0, -39.12, 0.0),
                vector4(2522.0, -262.0, -39.12, 0.0), vector4(2510.0, -259.5, -39.12, 0.0),
            },
        },
        {
            id = 'key_2', type = 'fetch', item = 'p_car_keys_01', label = 'Grand hall : clé',
            objective = 'Trouve la clé', hint = 'Elle est cachée quelque part dans la salle.',
            coords = vector3(2512.0, -262.0, -39.12), radius = 25.0,
            spawns = {
                vector4(2507.2, -258.8, -39.12, 0.0), vector4(2515.0, -258.8, -39.12, 0.0),
                vector4(2518.7, -258.8, -39.12, 0.0), vector4(2517.5, -265.5, -39.12, 0.0),
            },
        },
        {
            id = 'door_2', type = 'use', prop = 'ch_prop_ch_glassdoor_01', label = 'Porte vitrée',
            objective = 'Utilise la clé sur la porte', hint = 'Tu vois déjà ce qui t\'attend derrière.',
            coords = vector3(2507.5, -262.0, -39.12), radius = 15.0,
            spawns = { vector4(2505.0, -262.0, -39.12, 90.0) },
        },
        -- Le long tunnel en arches
        {
            id = 'room_5', type = 'kill', count = 20, label = 'Tunnel : zombies', warp = true, heading = 270.0,
            objective = 'Tue les zombies', hint = 'La horde arrive de partout.',
            coords = vector3(2497.7075, -312.7705, -70.7), radius = 35.0,
            spawns = {
                vector4(2507.3, -310.7, -70.7, 0.0), vector4(2488.0, -318.0, -70.7, 0.0),
                vector4(2519.0, -305.0, -70.7, 0.0), vector4(2483.0, -322.0, -70.7, 0.0),
            },
        },
        -- Les bureaux : le C4 est caché entre les rangées
        {
            id = 'c4', type = 'fetch', item = 'prop_c4_final_green', label = 'Bureaux : C4', warp = true, heading = 0.0,
            objective = 'Trouve le C4', hint = 'Il est caché quelque part dans la salle.',
            coords = vector3(2509.0, -247.0, -55.12), radius = 25.0,
            spawns = {
                vector4(2509.5, -240.5, -55.12, 0.0), vector4(2512.0, -244.5, -55.12, 0.0), vector4(2506.5, -249.5, -55.12, 0.0),
            },
        },
        -- Le hall du coffre : le C4 sur la porte, le boss derrière
        {
            id = 'vault', type = 'plant', hold = 4, prop = 'v_ilev_bk_vaultdoor', item = 'prop_c4_final_green', label = 'Porte du coffre-fort', warp = true, heading = 180.0,
            objective = 'Pose le C4 sur la porte', hint = 'Maintiens E sur chaque emplacement, puis éloigne-toi.',
            coords = vector3(2488.348, -267.3637, -70.69), radius = 25.0,
            spawns = {
                vector4(2488.35, -271.5, -70.69, 0.0),
                vector4(2486.5, -270.5, -70.69, 0.0), vector4(2488.35, -270.5, -70.69, 0.0), vector4(2490.2, -270.5, -70.69, 0.0),
            },
        },
        {
            id = 'boss', type = 'boss', label = 'Boss', warp = true, heading = 270.0,
            objective = 'Tue le boss',
            coords = vector3(2503.0, -279.0, -70.69), radius = 30.0,
            spawns = {
                vector4(2526.0, -279.0, -70.69, 90.0),
                vector4(2512.0, -276.0, -70.69, 0.0), vector4(2516.0, -282.0, -70.69, 0.0), vector4(2532.0, -276.0, -70.69, 0.0),
            },
        },
        {
            id = 'chest', type = 'chest', label = 'Coffres de fin',
            objective = 'Ouvre ton coffre', hint = 'Vide-le avant la fin du compteur.',
            coords = vector3(2516.88, -278.97, -70.69), radius = 30.0,
            spawns = { vector4(2516.88, -278.97, -70.69, 0.0) },
        },
    },
}
