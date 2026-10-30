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
    -- Carte en haut à gauche pendant les parties : décalage depuis sa position par défaut (y négatif = vers le haut),
    -- retiré en quittant le mode
    minimapShift = { x = 0.01, y = -0.77 },
    -- Heure et météo imposées dans tout le mode (menu et parties), à la place de l'heure commune du jeu
    sky = { hour = 13, minute = 0, weather = 'EXTRASUNNY' },

    queueDelay = 25, -- secondes de vote de carte une fois `minPlayers` atteint
    voteChoices = 3, -- cartes proposées au vote
    joinMinRemaining = 90, -- secondes : en dessous, une partie en cours n'accepte plus de nouveaux joueurs
    loadTime = 6, -- secondes d'écran de chargement à chaque arrivée dans une partie, avant le compte à rebours
    countdown = 15, -- secondes bloqué au point de départ au lancement, une fois l'écran de chargement passé
    loadoutTime = 12, -- secondes pour choisir sa classe, à l'arrivée dans une partie (après l'écran de chargement)
    loadoutCamera = { height = 1.3, fov = 50.0 }, -- vue aérienne de l'écran de classe (height : en rayons de la zone de combat)
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
    primaryKey = '1',
    secondaryKey = '2',

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
        unitDestroyed = 200, -- tourelle ou appareil ennemi détruit
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
    defaultStreaks = { 'uav', 'counter_uav', 'predator' },
    streaks = {
        -- target : ce que le client envoie à l'utilisation ('aim' : le point visé, 'front' : le sol devant le joueur)
        { id = 'uav', kills = 3, rank = 1, duration = 30, label = 'Drone', description = 'Les ennemis apparaissent sur la carte pendant 30 s.' },
        { id = 'care_package', kills = 4, rank = 3, target = 'aim', label = 'Colis de ravitaillement', description = 'Un colis tombe là où tu vises, avec une série au hasard.' },
        { id = 'counter_uav', kills = 4, rank = 1, duration = 30, label = 'Contre-drone', description = 'Coupe la carte des ennemis pendant 30 s.' },
        { id = 'sentry', kills = 5, rank = 5, target = 'front', label = 'Tourelle', description = 'Une tourelle devant toi tire seule sur les ennemis.' },
        { id = 'predator', kills = 5, rank = 1, label = 'Missile Predator', description = 'Guide un missile depuis ta tablette jusqu\'au sol.' },
        { id = 'precision', kills = 6, rank = 8, target = 'aim', label = 'Frappe de précision', description = 'Des avions bombardent en ligne l\'endroit que tu vises.' },
        { id = 'harrier', kills = 7, rank = 14, target = 'aim', label = 'Harrier', description = 'Bombarde l\'endroit que tu vises, puis reste sur place et tire.' },
        { id = 'helicopter', kills = 7, rank = 10, label = 'Hélicoptère d\'attaque', description = 'Un hélicoptère tourne au-dessus de la carte et tire sur les ennemis.' },
        { id = 'juggernaut', kills = 7, rank = 12, label = 'Juggernaut', description = 'Armure pleine et minigun jusqu\'à ta mort.' },
        { id = 'airdrop', kills = 8, rank = 17, target = 'aim', label = 'Largage d\'urgence', description = 'Quatre colis tombent là où tu vises.' },
        { id = 'pave_low', kills = 9, rank = 22, label = 'Pave Low', description = 'Un hélicoptère blindé, plus puissant et plus résistant.' },
        { id = 'stealth', kills = 9, rank = 20, target = 'aim', label = 'Bombardier furtif', description = 'Un long tapis de bombes, sans repère ni alerte pour les ennemis.' },
        { id = 'chopper_gunner', kills = 11, rank = 26, label = 'Hélico mitrailleur', description = 'Prends le minigun d\'un hélicoptère depuis ta tablette.' },
        { id = 'ac130', kills = 11, rank = 28, label = 'AC-130', description = 'Prends les trois canons d\'un AC-130 depuis ta tablette.' },
        { id = 'emp', kills = 15, rank = 34, duration = 60, label = 'EMP', description = 'Détruit les séries ennemies et bloque carte et séries pendant 60 s.' },
        { id = 'nuke', kills = 15, rank = 30, duration = 10, label = 'Frappe nucléaire', description = 'Après 10 s, ton camp remporte la partie.' },
    },
    uavSweep = 3, -- secondes entre deux relevés du drone
    tabletTime = 1.4, -- secondes pour sortir la tablette (missile Predator, hélico mitrailleur, AC-130)
    -- Bombardements en ligne, centrés sur le point visé, dans la direction du regard du joueur.
    -- delay : secondes avant les bombes ; length : m ; interval : ms entre deux bombes ; radius : m de chaque bombe ;
    -- damage : dégâts au centre, décroissant jusqu'au bord ; plane : avion qui passe ; warn : alerte sonore pour tous
    precision = { delay = 3, bombs = 8, length = 50.0, interval = 150, radius = 10.0, damage = 220, explosion = 5, plane = 'lazer', planes = 3, warn = true },
    stealth = { delay = 4, bombs = 16, length = 130.0, interval = 120, radius = 11.0, damage = 240, explosion = 5, plane = 'hydra', planes = 1, warn = false },
    harrierBombing = { delay = 3, bombs = 6, length = 36.0, interval = 150, radius = 9.0, damage = 200, explosion = 5, plane = 'hydra', planes = 2, warn = true },

    -- Colis : ils tombent là où le joueur vise et s'ouvrent en maintenant la touche d'action
    crates = {
        fallTime = 8, -- secondes de chute
        lifetime = 60, -- secondes au sol avant de disparaître
        ownerHold = 1.5, -- secondes pour ouvrir son propre colis
        otherHold = 6, -- secondes pour ouvrir celui d'un autre, ennemi ou allié
        takeRange = 3.5, -- m
        spread = 8.0, -- m entre le point visé et les colis du largage d'urgence
        airdropCount = 4,
        -- Contenu tiré au sort : plus le poids est grand, plus la série est fréquente
        contents = {
            { id = 'uav', weight = 22 }, { id = 'counter_uav', weight = 16 }, { id = 'predator', weight = 14 },
            { id = 'sentry', weight = 14 }, { id = 'precision', weight = 10 }, { id = 'harrier', weight = 8 },
            { id = 'helicopter', weight = 8 }, { id = 'pave_low', weight = 4 }, { id = 'chopper_gunner', weight = 2 },
            { id = 'ac130', weight = 1 }, { id = 'emp', weight = 1 },
        },
    },

    -- Unités : affichées localement par chaque client, les dégâts sont appliqués par le serveur.
    --   duration : secondes ; hits : touches à encaisser avant d'être détruite ; label : arme du fil des kills
    --   orbit : tourne autour du milieu de la carte (rayon en part de celui de la carte), orbitSpeed : radians/s
    --   height : m au-dessus du point ; aircraft : modèle de véhicule, sinon model et base sont des objets
    --   interval : ms entre deux tirs ; damage : par tir ; accuracy : chance de toucher ; range : m (toute la carte sinon)
    --   piloted : le joueur tire lui-même depuis sa tablette (weapons, cooldown en ms ; explosion : type de GTA)
    units = {
        sentry = {
            model = 'w_mg_minigun', base = 'prop_box_ammo03a', gunHeight = 0.75,
            duration = 60, hits = 25, range = 50.0, interval = 220, damage = 8, accuracy = 0.75, label = 'Tourelle',
        },
        helicopter = {
            aircraft = 'buzzard', orbit = 0.65, orbitSpeed = 0.18, height = 50.0, blip = 43,
            duration = 45, hits = 45, interval = 240, damage = 22, accuracy = 0.55, label = 'Hélicoptère d\'attaque',
        },
        pave_low = {
            aircraft = 'savage', orbit = 0.5, orbitSpeed = 0.15, height = 55.0, blip = 43,
            duration = 60, hits = 110, interval = 160, damage = 26, accuracy = 0.6, label = 'Pave Low',
        },
        harrier = {
            aircraft = 'hydra', height = 40.0, blip = 16,
            duration = 30, hits = 40, interval = 200, damage = 24, accuracy = 0.55, label = 'Harrier',
        },
        chopper_gunner = {
            aircraft = 'annihilator', orbit = 1.0, orbitSpeed = 0.12, height = 65.0, blip = 43, fov = 55.0,
            duration = 40, hits = 80, piloted = true, label = 'Hélico mitrailleur',
            weapons = {
                { label = 'Minigun', cooldown = 100, radius = 3.0, damage = 45 },
            },
        },
        ac130 = {
            aircraft = 'titan', orbit = 2.2, orbitSpeed = 0.08, height = 230.0, blip = 16, fov = 40.0,
            duration = 40, hits = 200, piloted = true, label = 'AC-130',
            weapons = {
                { label = '105 mm', cooldown = 5000, radius = 12.0, damage = 320, explosion = 5 },
                { label = '40 mm', cooldown = 1200, radius = 6.0, damage = 150, explosion = 3 },
                { label = '25 mm', cooldown = 120, radius = 2.5, damage = 45 },
            },
        },
    },

    predator = {
        height = 250.0, -- m au-dessus du milieu de la carte au départ
        floor = 20.0, -- m sous le milieu de la carte : explose là si le sol n'est pas chargé
        speed = 35.0, -- m/s
        boostSpeed = 90.0, -- m/s, clic gauche maintenu
        steer = 0.14, -- déplacement à la souris, en proportion de l'altitude (l'image défile à la même vitesse)
        steerKeys = 30.0, -- m/s avec les touches de déplacement
        minSteerHeight = 15.0, -- m : altitude minimale prise en compte pour la souris
        fov = 60.0,
        radius = 12.0, -- m
        damage = 300, -- dégâts au centre, décroissant jusqu'au bord
        explosion = 5,
    },
    juggernaut = { weapon = 'WEAPON_MINIGUN', ammo = 1000, armor = 100 },
    bombExplosion = 5, -- type d'explosion de la bombe (Recherche & Destruction)

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

    -- Écran de chargement : caméra derrière le point de départ, regardant le milieu de la carte.
    -- distance et height sont en proportion du rayon de la carte ; push = part du trajet vers le milieu parcourue.
    loadingView = { distance = 1.0, height = 0.7, fov = 55.0, push = 0.08 },
    loadingTips = {
        'La santé remonte toute seule après quelques secondes sans dégâts.',
        'Tu peux changer de classe en pleine partie : elle s\'applique à ta prochaine apparition.',
        'Tirer met fin à ta protection d\'apparition.',
        'Hors de la zone de combat, tu perds de la vie chaque seconde.',
        'Toucher un ennemi juste avant qu\'un allié ne l\'élimine te rapporte une assistance.',
        'En Domination, plus vous êtes nombreux sur un drapeau, plus vite il est capturé.',
        'En Recherche & Destruction, tu n\'as qu\'une seule vie par manche.',
        'Enchaîner les kills en quelques secondes rapporte de l\'XP en plus.',
        'Le premier kill de la partie rapporte un bonus d\'XP.',
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
