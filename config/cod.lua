-- Call of Duty : mode de jeu à part entière (choisi au lobby), façon multijoueur de CoD.
--  1. Le joueur compose ses classes et lance une recherche depuis le menu du mode.
--  2. Dès `minPlayers` joueurs dans une liste de jeu, un vote de carte de `queueDelay` secondes
--     commence. Une partie en cours qui a de la place (sauf Recherche & Destruction) se rejoint directement.
--  3. Chaque partie se joue dans son propre bucket. À la fin : résultats, XP, puis retour au menu
--     et nouvelle recherche automatique dans la même liste de jeu.
-- La progression (rang, classes, séries) est propre au mode : table pvp_cod_profiles.
-- Rien ne touche à l'inventaire ni à l'argent du PvP.
Config.Cod = {
    bucket = 5, -- bucket du mode à l'arrivée (voir Config.Lobby.Modes)
    bucketBase = 6000, -- buckets des parties : bucketBase + numéro de la partie
    menuBucketBase = 16000, -- menu du mode : chaque joueur seul avec son personnage, menuBucketBase + son id

    -- Décor du menu : le personnage du joueur, de face, avec l'arme principale de sa classe.
    -- Le joueur regarde le personnage depuis `cameraDistance` mètres. Position à ajuster en jeu avec /pvp_coords.
    menuScene = {
        ped = vector4(1020.0, -3090.0, 5.9, 180.0),
        cameraDistance = 3.4,
        cameraHeight = 0.25,
        lookHeight = 0.05,
        fov = 38.0,
    },
    -- Carte en haut à gauche pendant les parties (position remise par défaut en quittant le mode)
    minimapTop = 0.035,
    minimapLeft = 0.012,

    queueDelay = 25, -- secondes de vote de carte une fois `minPlayers` atteint
    voteChoices = 3, -- cartes proposées au vote
    joinMinRemaining = 90, -- secondes : en dessous, une partie en cours n'accepte plus de nouveaux joueurs
    countdown = 8, -- secondes bloqué au point de départ au lancement
    endScreen = 12, -- secondes de résultats avant le retour au menu

    respawnDelay = 3, -- secondes avant de réapparaître après une mort
    spawnProtection = 2, -- secondes sans prendre de dégâts après chaque apparition
    outsideDamage = 10, -- dégâts par seconde hors de la zone de combat
    killRange = 400.0, -- m : au-delà, le kill signalé par la victime est refusé
    assistWindow = 8, -- secondes : une touche récente sur la victime donne une assistance
    multiKillWindow = 4, -- secondes entre deux kills d'un multi-kill

    -- Santé : remontée automatique après `delay` secondes sans dégâts
    regen = { delay = 6.0, fastDelay = 3.0, perSecond = 35 },

    -- Touches (les joueurs peuvent les changer dans les paramètres de GTA > FiveM).
    -- Le tableau des scores se maintient sur la touche du menu (Config.MenuKey).
    streakKey = 'G',
    classKey = 'B',

    knife = 'WEAPON_KNIFE',

    -- XP gagnée (rang du mode)
    xp = {
        kill = 100,
        headshot = 50,
        assist = 50,
        firstBlood = 100,
        revenge = 50,
        multiKill = 50, -- par kill au-delà du premier
        capture = 150,
        flagTick = 5, -- par joueur sur un drapeau tenu, à chaque rentrée de points
        plant = 200,
        defuse = 300,
        roundWin = 100,
        win = 800,
        loss = 300,
        draw = 500,
    },

    -- Rangs : passer du rang n au rang n+1 demande base + growth * (n - 1) XP
    ranks = { max = 55, base = 800, growth = 200 },

    -- Listes de jeu proposées dans le menu.
    --   time = durée en secondes ; scoreLimit = score pour gagner
    playlists = {
        {
            id = 'tdm', label = 'Match à mort par équipe', short = 'MME',
            description = 'Deux équipes, réapparition immédiate : la première à 75 kills gagne.',
            teams = true, minPlayers = 2, maxPlayers = 12, time = 600, scoreLimit = 75,
        },
        {
            id = 'dom', label = 'Domination', short = 'DOM',
            description = 'Capturez et tenez les drapeaux : chaque drapeau rapporte des points à votre équipe.',
            teams = true, minPlayers = 2, maxPlayers = 12, time = 600, scoreLimit = 200,
        },
        {
            id = 'ffa', label = 'Mêlée générale', short = 'MG',
            description = 'Chacun pour soi : le premier à 30 kills gagne.',
            teams = false, minPlayers = 2, maxPlayers = 10, time = 600, scoreLimit = 30,
        },
        {
            id = 'snd', label = 'Recherche & Destruction', short = 'R&D',
            description = 'Une seule vie par manche. Les attaquants posent la bombe, les défenseurs la désamorcent.',
            teams = true, minPlayers = 2, maxPlayers = 10, time = 3600, scoreLimit = 4,
        },
    },

    -- Domination
    domination = {
        captureRadius = 9.0,
        captureTime = 8, -- secondes pour un joueur seul
        captureBonus = 0.25, -- vitesse en plus par joueur supplémentaire
        scoreInterval = 5, -- secondes entre deux rentrées de points
    },

    -- Recherche & Destruction : tous les attaquants peuvent poser la bombe.
    -- Après `swapAfter` manches, les équipes échangent leur rôle.
    searchDestroy = {
        roundTime = 120,
        plantTime = 5,
        defuseTime = 7,
        bombTime = 45,
        siteRadius = 4.0,
        roundPause = 6, -- secondes entre deux manches
        swapAfter = 3,
    },

    teams = {
        { id = 'alpha', label = 'Rangers', blipColor = 3 },
        { id = 'bravo', label = 'Spetsnaz', blipColor = 1 },
    },

    -- Catalogue des armes : rank = rang de déblocage, ammo = munitions de réserve au départ.
    -- L'image vient de web/public/items/<arme en minuscules>.png
    weapons = {
        primary = {
            { id = 'WEAPON_CARBINERIFLE', label = 'Carabine', category = 'Fusils d\'assaut', rank = 1, ammo = 240 },
            { id = 'WEAPON_ASSAULTRIFLE', label = 'Fusil d\'assaut', category = 'Fusils d\'assaut', rank = 3, ammo = 240 },
            { id = 'WEAPON_SPECIALCARBINE', label = 'Carabine spéciale', category = 'Fusils d\'assaut', rank = 14, ammo = 240 },
            { id = 'WEAPON_BULLPUPRIFLE', label = 'Fusil bullpup', category = 'Fusils d\'assaut', rank = 22, ammo = 240 },
            { id = 'WEAPON_ADVANCEDRIFLE', label = 'Fusil avancé', category = 'Fusils d\'assaut', rank = 32, ammo = 240 },
            { id = 'WEAPON_SMG', label = 'SMG', category = 'Mitraillettes', rank = 1, ammo = 300 },
            { id = 'WEAPON_MICROSMG', label = 'Micro SMG', category = 'Mitraillettes', rank = 5, ammo = 300 },
            { id = 'WEAPON_ASSAULTSMG', label = 'SMG d\'assaut', category = 'Mitraillettes', rank = 12, ammo = 300 },
            { id = 'WEAPON_COMBATPDW', label = 'PDW de combat', category = 'Mitraillettes', rank = 20, ammo = 300 },
            { id = 'WEAPON_PUMPSHOTGUN', label = 'Fusil à pompe', category = 'Fusils à pompe', rank = 1, ammo = 48 },
            { id = 'WEAPON_ASSAULTSHOTGUN', label = 'Fusil à pompe d\'assaut', category = 'Fusils à pompe', rank = 18, ammo = 64 },
            { id = 'WEAPON_HEAVYSHOTGUN', label = 'Fusil à pompe lourd', category = 'Fusils à pompe', rank = 28, ammo = 64 },
            { id = 'WEAPON_MG', label = 'Mitrailleuse', category = 'Mitrailleuses', rank = 8, ammo = 320 },
            { id = 'WEAPON_COMBATMG', label = 'Mitrailleuse de combat', category = 'Mitrailleuses', rank = 26, ammo = 400 },
            { id = 'WEAPON_SNIPERRIFLE', label = 'Fusil de précision', category = 'Fusils de précision', rank = 1, ammo = 30 },
            { id = 'WEAPON_MARKSMANRIFLE', label = 'Fusil de tireur d\'élite', category = 'Fusils de précision', rank = 10, ammo = 56 },
            { id = 'WEAPON_HEAVYSNIPER', label = 'Fusil de précision lourd', category = 'Fusils de précision', rank = 30, ammo = 24 },
        },
        secondary = {
            { id = 'WEAPON_PISTOL', label = 'Pistolet', category = 'Pistolets', rank = 1, ammo = 72 },
            { id = 'WEAPON_COMBATPISTOL', label = 'Pistolet de combat', category = 'Pistolets', rank = 2, ammo = 72 },
            { id = 'WEAPON_HEAVYPISTOL', label = 'Pistolet lourd', category = 'Pistolets', rank = 7, ammo = 54 },
            { id = 'WEAPON_PISTOL50', label = 'Pistolet .50', category = 'Pistolets', rank = 11, ammo = 54 },
            { id = 'WEAPON_REVOLVER', label = 'Revolver', category = 'Pistolets', rank = 16, ammo = 36 },
            { id = 'WEAPON_MACHINEPISTOL', label = 'Pistolet mitrailleur', category = 'Pistolets', rank = 24, ammo = 120 },
        },
        -- id = false : pas d'équipement
        equipment = {
            { id = 'WEAPON_GRENADE', label = 'Grenade', category = 'Équipement', rank = 1, ammo = 2 },
            { id = 'WEAPON_SMOKEGRENADE', label = 'Fumigène', category = 'Équipement', rank = 4, ammo = 2 },
            { id = 'WEAPON_MOLOTOV', label = 'Cocktail Molotov', category = 'Équipement', rank = 9, ammo = 2 },
            { id = 'WEAPON_STICKYBOMB', label = 'Charge collante', category = 'Équipement', rank = 17, ammo = 2 },
        },
    },

    -- Atouts : un par niveau (tier) dans chaque classe
    perks = {
        { id = 'lightweight', tier = 1, rank = 1, label = 'Agilité', description = 'Tu cours plus vite (+10 %).' },
        { id = 'scavenger', tier = 1, rank = 6, label = 'Charognard', description = 'Chaque kill recharge tes munitions.' },
        { id = 'flak', tier = 1, rank = 15, label = 'Gilet pare-balles', description = 'Tu apparais avec 40 points d\'armure.' },
        { id = 'hardline', tier = 2, rank = 1, label = 'Détermination', description = 'Tes séries demandent un kill de moins.' },
        { id = 'stopping', tier = 2, rank = 13, label = 'Force de frappe', description = 'Dégâts de tes balles : +15 %.' },
        { id = 'vitality', tier = 2, rank = 21, label = 'Vitalité', description = 'Ta santé remonte deux fois plus tôt.' },
        { id = 'marathon', tier = 3, rank = 1, label = 'Marathon', description = 'Tu ne t\'essouffles jamais.' },
        { id = 'ghost', tier = 3, rank = 19, label = 'Fantôme', description = 'Tu restes invisible aux drones ennemis.' },
        { id = 'revenge', tier = 3, rank = 25, label = 'Vengeance', description = 'Ton tueur apparaît sur ta carte après ta mort.' },
    },
    flakArmor = 40,
    lightweightSpeed = 1.1,
    stoppingPower = 1.15,

    -- Séries d'éliminations : `kills` sans mourir pour en gagner une, utilisée avec streakKey.
    -- Chaque joueur en équipe jusqu'à maxStreaks.
    maxStreaks = 3,
    defaultStreaks = { 'uav' },
    streaks = {
        { id = 'uav', kills = 3, rank = 1, duration = 30, label = 'Drone', description = 'Les ennemis apparaissent sur la carte pendant 30 s.' },
        { id = 'counter_uav', kills = 4, rank = 3, duration = 30, label = 'Contre-drone', description = 'Coupe la carte des ennemis pendant 30 s.' },
        { id = 'airstrike', kills = 5, rank = 5, label = 'Frappe aérienne', description = 'Bombarde l\'endroit que tu vises.' },
        { id = 'juggernaut', kills = 7, rank = 12, label = 'Juggernaut', description = 'Armure pleine et minigun jusqu\'à ta mort.' },
        { id = 'nuke', kills = 15, rank = 30, duration = 10, label = 'Frappe nucléaire', description = 'Après 10 s, ton camp remporte la partie.' },
    },
    uavSweep = 3, -- secondes entre deux relevés du drone
    airstrike = {
        delay = 3, -- secondes entre l'appel et les premières bombes
        bombs = 6,
        interval = 350, -- ms entre deux bombes
        spread = 12.0, -- m autour du point visé
        radius = 9.0, -- m : rayon de chaque bombe
        damage = 140, -- dégâts au centre, décroissant jusqu'au bord
        explosionType = 5,
    },
    juggernaut = { weapon = 'WEAPON_MINIGUN', ammo = 1000, armor = 100 },

    -- Classes de départ (toutes jouables au rang 1), remplacées dès qu'un joueur les modifie
    defaultClasses = {
        { name = 'Assaut', primary = 'WEAPON_CARBINERIFLE', secondary = 'WEAPON_PISTOL', equipment = 'WEAPON_GRENADE', perks = { 'lightweight', 'hardline', 'marathon' } },
        { name = 'Mitraillette', primary = 'WEAPON_SMG', secondary = 'WEAPON_PISTOL', equipment = 'WEAPON_GRENADE', perks = { 'lightweight', 'hardline', 'marathon' } },
        { name = 'Pompe', primary = 'WEAPON_PUMPSHOTGUN', secondary = 'WEAPON_PISTOL', equipment = 'WEAPON_GRENADE', perks = { 'lightweight', 'hardline', 'marathon' } },
        { name = 'Précision', primary = 'WEAPON_SNIPERRIFLE', secondary = 'WEAPON_PISTOL', equipment = 'WEAPON_GRENADE', perks = { 'lightweight', 'hardline', 'marathon' } },
        { name = 'Polyvalent', primary = 'WEAPON_CARBINERIFLE', secondary = 'WEAPON_PISTOL', equipment = false, perks = { 'lightweight', 'hardline', 'marathon' } },
    },
    classNameLength = 20,

    leaderboardSize = 20,
    leaderboardCache = 30, -- secondes

    -- Cartes : lieux de GTA délimités par une arène (cercle autour du milieu des points d'apparition).
    -- Les positions sont dans Config.CodSpawns, <id>_alpha, <id>_bravo, <id>_flags et <id>_sites.
    maps = {
        { id = 'port', label = 'Terminal', place = 'Port de Los Santos', radius = 85.0 },
        { id = 'scrapyard', label = 'La Casse', place = 'Rogers Salvage, La Puerta', radius = 70.0 },
        { id = 'sawmill', label = 'La Scierie', place = 'Paleto Bay', radius = 80.0 },
        { id = 'construction', label = 'Le Chantier', place = 'Pillbox Hill', radius = 70.0 },
    },
}

-- Points de chaque carte, modifiables depuis le panneau admin (F10, onglet Freeroam, section Call of Duty) :
--   alpha, bravo : apparitions de chaque camp (cap = direction du regard), aussi réutilisées en réapparition
--   flags        : drapeaux de la Domination (A, B, C dans l'ordre)
--   sites        : sites de bombe de Recherche & Destruction (A, B dans l'ordre)
-- Coordonnées approximatives, placées sans pouvoir tester en jeu : la hauteur est recalée sur le sol,
-- mais un point peut tomber sur un toit ou un conteneur. À ajuster au panneau admin.
Config.CodSpawns = {
    port_alpha = {
        vector4(995.0, -3045.0, 5.9, 180.0), vector4(1010.0, -3040.0, 5.9, 180.0), vector4(1025.0, -3045.0, 5.9, 180.0),
        vector4(1040.0, -3040.0, 5.9, 180.0), vector4(1055.0, -3045.0, 5.9, 180.0),
    },
    port_bravo = {
        vector4(995.0, -3135.0, 5.9, 0.0), vector4(1010.0, -3140.0, 5.9, 0.0), vector4(1025.0, -3135.0, 5.9, 0.0),
        vector4(1040.0, -3140.0, 5.9, 0.0), vector4(1055.0, -3135.0, 5.9, 0.0),
    },
    port_flags = { vector4(1020.0, -3055.0, 5.9, 0.0), vector4(1020.0, -3090.0, 5.9, 0.0), vector4(1020.0, -3125.0, 5.9, 0.0) },
    port_sites = { vector4(985.0, -3090.0, 5.9, 0.0), vector4(1055.0, -3090.0, 5.9, 0.0) },

    scrapyard_alpha = {
        vector4(-490.0, -1720.0, 18.7, 270.0), vector4(-495.0, -1710.0, 18.7, 270.0), vector4(-490.0, -1700.0, 18.7, 270.0),
        vector4(-495.0, -1690.0, 18.7, 270.0), vector4(-490.0, -1680.0, 18.7, 270.0),
    },
    scrapyard_bravo = {
        vector4(-410.0, -1720.0, 18.7, 90.0), vector4(-405.0, -1710.0, 18.7, 90.0), vector4(-410.0, -1700.0, 18.7, 90.0),
        vector4(-405.0, -1690.0, 18.7, 90.0), vector4(-410.0, -1680.0, 18.7, 90.0),
    },
    scrapyard_flags = { vector4(-480.0, -1700.0, 18.7, 0.0), vector4(-450.0, -1700.0, 18.7, 0.0), vector4(-420.0, -1700.0, 18.7, 0.0) },
    scrapyard_sites = { vector4(-450.0, -1730.0, 18.7, 0.0), vector4(-450.0, -1670.0, 18.7, 0.0) },

    sawmill_alpha = {
        vector4(-600.0, 5280.0, 71.0, 0.0), vector4(-585.0, 5275.0, 71.0, 0.0), vector4(-565.0, 5280.0, 71.0, 0.0),
        vector4(-545.0, 5275.0, 71.0, 0.0), vector4(-530.0, 5280.0, 71.0, 0.0),
    },
    sawmill_bravo = {
        vector4(-600.0, 5360.0, 71.0, 180.0), vector4(-585.0, 5365.0, 71.0, 180.0), vector4(-565.0, 5360.0, 71.0, 180.0),
        vector4(-545.0, 5365.0, 71.0, 180.0), vector4(-530.0, 5360.0, 71.0, 180.0),
    },
    sawmill_flags = { vector4(-565.0, 5290.0, 71.0, 0.0), vector4(-565.0, 5320.0, 71.0, 0.0), vector4(-565.0, 5350.0, 71.0, 0.0) },
    sawmill_sites = { vector4(-605.0, 5320.0, 71.0, 0.0), vector4(-525.0, 5320.0, 71.0, 0.0) },

    construction_alpha = {
        vector4(-160.0, -1000.0, 27.3, 270.0), vector4(-165.0, -990.0, 27.3, 270.0), vector4(-160.0, -980.0, 27.3, 270.0),
        vector4(-165.0, -970.0, 27.3, 270.0), vector4(-160.0, -960.0, 27.3, 270.0),
    },
    construction_bravo = {
        vector4(-80.0, -1000.0, 27.3, 90.0), vector4(-75.0, -990.0, 27.3, 90.0), vector4(-80.0, -980.0, 27.3, 90.0),
        vector4(-75.0, -970.0, 27.3, 90.0), vector4(-80.0, -960.0, 27.3, 90.0),
    },
    construction_flags = { vector4(-150.0, -980.0, 27.3, 0.0), vector4(-120.0, -980.0, 27.3, 0.0), vector4(-90.0, -980.0, 27.3, 0.0) },
    construction_sites = { vector4(-120.0, -1010.0, 27.3, 0.0), vector4(-120.0, -950.0, 27.3, 0.0) },
}
