-- Sabotage : mode tactique en manches (choisi au lobby), à part du PvP et de Seven of Duty.
--  1. Le joueur choisit son rôle et lance une recherche depuis le menu du mode.
--  2. Dès `minPlayers` joueurs, la partie se lance après `queueDelay` secondes (tout de suite à `maxPlayers`).
--  3. Deux équipes, une seule vie par manche. Les attaquants posent la charge sur un site, les défenseurs
--     l'empêchent ou la désamorcent. Changement de camp après `swapAfter` manches, premier à `roundsToWin`.
--  4. Chaque manche commence par `buyTime` secondes d'achat (touche B) dans sa zone de départ.
--     Survivre garde ses armes pour la manche suivante.
-- Cartes : celles de Seven of Duty qui ont leurs apparitions et deux sites (panneau admin F10, onglet Positions,
-- section Seven of Duty), sauf `excludedMaps`. Les apparitions alpha et bravo sont les deux camps.
-- Profils (classement, statistiques) : table pvp_tactical_profiles. Rien ne touche à l'inventaire du PvP.
Config.Tactical = {
    bucket = 9, -- bucket du mode à l'arrivée (voir Config.Lobby.Modes)
    bucketBase = 30000, -- buckets des parties : bucketBase + numéro de la partie
    menuBucketBase = 40000, -- menu du mode : chaque joueur seul, menuBucketBase + son id
    sky = { hour = 16, minute = 0, weather = 'CLEAR' },

    minPlayers = 4, -- 2 contre 2
    maxPlayers = 10, -- 5 contre 5
    queueDelay = 20, -- secondes d'attente une fois `minPlayers` atteint, pour laisser venir les autres
    excludedMaps = { nuketown = true }, -- cartes de Seven of Duty jamais jouées ici

    roundsToWin = 7,
    swapAfter = 6, -- manches avant le changement de camp
    loadTime = 8, -- secondes de présentation des équipes (écran noir) à l'arrivée dans la partie
    buyTime = 30, -- secondes d'achat, bloqué dans sa zone de départ
    buyRadius = 12.0, -- m autour de son point de départ pendant l'achat
    roundTime = 100, -- secondes pour poser la charge
    roundPause = 7, -- secondes entre la fin d'une manche et la suivante
    plantTime = 4,
    defuseTime = 7,
    bombTime = 45, -- secondes entre la pose et l'explosion
    siteRadius = 6.0, -- m autour du point du site pour poser
    endScreen = 15, -- secondes de résultats avant le retour au menu
    killRange = 400.0, -- m : au-delà, le kill signalé par la victime est refusé
    assistWindow = 8, -- secondes : une touche récente sur la victime donne une assistance
    outsideDamage = 10, -- dégâts par seconde hors de la zone de jeu

    -- Argent de la partie (remis à `start` au changement de camp)
    economy = {
        start = 800,
        max = 9000,
        kill = 200,
        plant = 300, -- pour chaque attaquant, à la pose
        win = 3000,
        loss = { 1900, 2400, 2900 }, -- 1re, 2e, 3e défaite d'affilée et plus
        overtime = 5000, -- manche décisive à égalité : tout le monde repart avec cette somme
    },

    knife = 'WEAPON_KNIFE',
    defaultPistol = 'WEAPON_PISTOL', -- donné à chaque manche à qui n'a pas d'arme secondaire

    -- Armes à vendre. slot : 'secondary' ou 'primary' ; ammo : munitions données à l'achat et à chaque manche
    weapons = {
        { id = 'WEAPON_PISTOL', label = 'Pistolet', category = 'Pistolets', slot = 'secondary', price = 0, ammo = 72 },
        { id = 'WEAPON_COMBATPISTOL', label = 'Pistolet de combat', category = 'Pistolets', slot = 'secondary', price = 300, ammo = 72 },
        { id = 'WEAPON_HEAVYPISTOL', label = 'Pistolet lourd', category = 'Pistolets', slot = 'secondary', price = 500, ammo = 54 },
        { id = 'WEAPON_PISTOL50', label = 'Pistolet .50', category = 'Pistolets', slot = 'secondary', price = 800, ammo = 54 },
        { id = 'WEAPON_MICROSMG', label = 'Micro SMG', category = 'Mitraillettes', slot = 'primary', price = 1200, ammo = 180 },
        { id = 'WEAPON_SMG', label = 'SMG', category = 'Mitraillettes', slot = 'primary', price = 1600, ammo = 180 },
        { id = 'WEAPON_PUMPSHOTGUN', label = 'Fusil à pompe', category = 'Fusils à pompe', slot = 'primary', price = 1800, ammo = 40 },
        { id = 'WEAPON_ASSAULTSHOTGUN', label = 'Fusil à pompe d\'assaut', category = 'Fusils à pompe', slot = 'primary', price = 2400, ammo = 48 },
        { id = 'WEAPON_CARBINERIFLE', label = 'Carabine', category = 'Fusils d\'assaut', slot = 'primary', price = 2900, ammo = 210 },
        { id = 'WEAPON_ASSAULTRIFLE', label = 'Fusil d\'assaut', category = 'Fusils d\'assaut', slot = 'primary', price = 2900, ammo = 210 },
        { id = 'WEAPON_SPECIALCARBINE', label = 'Carabine spéciale', category = 'Fusils d\'assaut', slot = 'primary', price = 3200, ammo = 210 },
        { id = 'WEAPON_COMBATMG', label = 'Mitrailleuse de combat', category = 'Mitrailleuses', slot = 'primary', price = 3400, ammo = 300 },
        { id = 'WEAPON_MARKSMANRIFLE', label = 'Fusil de tireur d\'élite', category = 'Fusils de précision', slot = 'primary', price = 3600, ammo = 40 },
        { id = 'WEAPON_HEAVYSNIPER', label = 'Fusil de précision lourd', category = 'Fusils de précision', slot = 'primary', price = 4700, ammo = 20 },
    },

    -- Gilets : armure ajoutée à la vie, perdue à la mort
    armor = {
        { id = 'light', label = 'Gilet léger', price = 400, value = 25 },
        { id = 'heavy', label = 'Gilet lourd', price = 1000, value = 50 },
    },

    -- Rôles : deux capacités (touches C et Q) et une capacité ultime (X).
    --   price : prix d'une charge à l'achat, max : charges au plus ; free : charges rendues à chaque manche
    --   cost : points d'ultime nécessaires (1 par kill, 1 par mort, 1 par pose ou désamorçage)
    --   target : 'aim' point visé (jusqu'à range m), 'mate' allié visé ou soi, 'feet' à ses pieds,
    --            'front' devant soi, 'self' ou 'none'
    roles = {
        {
            id = 'scout',
            label = 'Éclaireur',
            description = 'Trouve les ennemis avant qu\'ils ne te trouvent.',
            abilities = {
                c = { id = 'sensor', label = 'Capteur', description = 'Lance un capteur qui révèle les ennemis proches à toute l\'équipe.',
                    price = 200, max = 2, target = 'aim', range = 40.0, radius = 15.0, seconds = 5 },
                q = { id = 'sprint', label = 'Course', description = 'Court beaucoup plus vite pendant quelques secondes.',
                    free = 1, max = 1, target = 'self', seconds = 5, multiplier = 1.4 },
                x = { id = 'scan', label = 'Balayage', description = 'Révèle tous les ennemis, trois fois de suite.',
                    cost = 6, target = 'none', pulses = 3, interval = 2.0, seconds = 2 },
            },
        },
        {
            id = 'smoker',
            label = 'Artificier',
            description = 'Coupe les lignes de tir et aveugle les défenses.',
            abilities = {
                c = { id = 'smoke', label = 'Fumée', description = 'Un nuage épais au point visé, qui bloque la vue.',
                    price = 100, max = 2, target = 'aim', range = 50.0, radius = 5.0, seconds = 15 },
                q = { id = 'flash', label = 'Flash', description = 'Éclate au point visé et aveugle ceux qui la regardent.',
                    price = 250, max = 1, target = 'aim', range = 25.0, delay = 0.6, seconds = 2.5 },
                x = { id = 'curtain', label = 'Rideau', description = 'Trois fumées en ligne au point visé.',
                    cost = 7, target = 'aim', range = 50.0, count = 3, spacing = 8.0, radius = 5.0, seconds = 18 },
            },
        },
        {
            id = 'warden',
            label = 'Rempart',
            description = 'Tient un site et ralentit ceux qui le prennent.',
            abilities = {
                c = { id = 'alarm', label = 'Alarme', description = 'Piège posé à tes pieds : l\'ennemi qui passe est révélé et ralenti.',
                    price = 200, max = 1, target = 'feet', radius = 2.5, reveal = 4, slow = 3 },
                q = { id = 'barrier', label = 'Barricade', description = 'Trois blocs de béton devant toi, pendant 30 secondes.',
                    free = 1, max = 1, target = 'front', seconds = 30, distance = 2.5, panels = 3, spacing = 1.6,
                    model = 'prop_mp_conc_barrier_01' },
                x = { id = 'lockdown', label = 'Verrou', description = 'Après deux secondes, ralentit et révèle les ennemis de la zone visée.',
                    cost = 7, target = 'aim', range = 30.0, radius = 12.0, delay = 2.0, seconds = 5 },
            },
        },
        {
            id = 'medic',
            label = 'Soigneur',
            description = 'Garde l\'équipe en vie, et la relève.',
            abilities = {
                c = { id = 'heal', label = 'Soin', description = 'Soigne l\'allié visé, ou toi-même, en quelques secondes.',
                    price = 150, max = 2, target = 'mate', range = 15.0, amount = 50, seconds = 3 },
                q = { id = 'shield', label = 'Bouclier', description = 'Donne de l\'armure à l\'allié visé, ou à toi-même.',
                    free = 1, max = 1, target = 'mate', range = 15.0, amount = 50 },
                x = { id = 'revive', label = 'Relève', description = 'Ramène à côté de toi le dernier allié tombé, avec ses armes.',
                    cost = 7, target = 'none' },
            },
        },
    },
    slowFactor = 0.6, -- vitesse de marche d'un joueur ralenti
    maxUltimate = 8, -- points d'ultime au plus

    -- Touches (les joueurs peuvent les changer dans les paramètres de GTA > FiveM).
    -- Le tableau des scores se maintient sur la touche du menu (Config.MenuKey), la charge se pose avec E.
    keys = { buy = 'B', abilityC = 'C', abilityQ = 'Q', ultimate = 'X' },

    -- Classement : cote de départ, gagnée ou perdue à chaque partie (MVP : bonus en plus)
    rating = { start = 1000, win = 25, loss = 20, mvp = 5, min = 0 },
    -- Divisions affichées selon la cote (la dernière atteinte)
    divisions = {
        { min = 0, label = 'Bronze' },
        { min = 1100, label = 'Argent' },
        { min = 1250, label = 'Or' },
        { min = 1400, label = 'Platine' },
        { min = 1550, label = 'Diamant' },
        { min = 1700, label = 'Élite' },
    },
    leaderboardSize = 20,
    leaderboardCache = 30, -- secondes
}
