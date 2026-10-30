Config = {}

Config.Debug = false

-- ---------------------------------------------------------------------------
-- Joueur
-- ---------------------------------------------------------------------------

Config.AutoSaveInterval = 5 * 60 -- secondes
Config.RespawnDelay = 8 -- secondes avant de réapparaître
-- Repère sur la carte à l'endroit de sa dernière mort (310 = tête de mort, 4 = blanc)
Config.DeathBlip = { duration = 60, sprite = 310, color = 4 }
Config.XpPerLevel = 1000 -- niveau = floor(xp / XpPerLevel) + 1
-- Kits de départ et inventaire : voir config/items.lua

-- ---------------------------------------------------------------------------
-- Combat / économie
-- ---------------------------------------------------------------------------

-- L'argent des récompenses arrive dans le sac (donc perdu à la mort s'il n'est pas protégé)
Config.Rewards = {
    playerKill = { money = 250, xp = 100 },
    npcKill = { money = 0, xp = 25 }, -- l'argent des PNJ est dans leur sac (voir config/loot.lua)
}

-- Distance max entre tueur et victime pour valider un kill (anti-triche basique)
Config.MaxKillDistance = 500.0

-- Un joueur qui touche ou est touché par un autre joueur est « en combat » pendant cette durée
-- (secondes, relancée à chaque touche). Se déconnecter en combat compte comme une mort :
-- sac au sol, mort comptée, kill et récompense pour le dernier joueur qui l'a touché.
-- Retourner au lobby est aussi bloqué pendant ce temps.
Config.CombatTagDuration = 20

-- Séries de kills : à partir de `threshold` kills sans mourir, la tête du joueur est mise à prix
-- (base + perKill par kill supplémentaire). Son tueur encaisse la prime. Repère rouge sur la carte.
Config.Bounty = {
    threshold = 5,
    base = 1000,
    perKill = 250,
    announceEvery = 2, -- annonce dans le chat tous les N kills au-delà du seuil
    blip = { sprite = 303, color = 1 },
}

-- Groupes (escouades) en PvP : pas de tir allié, coéquipiers sur la minimap et dans le HUD
Config.Groups = {
    maxSize = 4,
    inviteTimeout = 60, -- secondes pour accepter une invitation
    blipColor = 3, -- couleur des coéquipiers sur la minimap (3 = bleu)
}

-- ---------------------------------------------------------------------------
-- Échanges entre joueurs (/trade) : PvP seulement, à côté l'un de l'autre, hors combat.
-- Chacun propose des objets portés (sac + conteneur protégé), passe « Prêt », puis les deux
-- confirment. Toute modification d'une offre retire les « Prêt » des deux joueurs.
-- ---------------------------------------------------------------------------

Config.Trade = {
    requestTimeout = 30, -- secondes pour accepter une demande
    maxDistance = 5.0, -- au-delà, l'échange est annulé
    maxItems = 12, -- objets différents par offre
    blocked = {}, -- objets interdits à l'échange, ex : { weapon_rpg = true }
}

-- ---------------------------------------------------------------------------
-- Sacs de butin
-- ---------------------------------------------------------------------------

Config.LootLifetime = 300 -- secondes avant disparition d'un sac ou d'un corps de zombie non fouillé
Config.LootPickupDistance = 2.0
Config.LootModel = 'prop_cs_heist_bag_02'

-- ---------------------------------------------------------------------------
-- PvE
-- ---------------------------------------------------------------------------

Config.PveActivationDistance = 200.0 -- les zombies apparaissent quand un joueur est à radius + cette distance
Config.PveDespawnDelay = 60 -- secondes sans joueur avant de supprimer les zombies
Config.NpcCorpseTime = 20 -- secondes avant suppression d'un corps sans butin (sinon : fouillé ou après LootLifetime)

-- Monde zombies : en entrant dans une zone PvE, le joueur passe dans un monde à part (bucket de
-- routage), partagé avec les autres joueurs qui farment, sans PvP. Il revient au monde PvP en sortant.
-- Même inventaire ; le butin (corps, sacs) n'est visible et ramassable que dans le monde où il est tombé.
Config.PveWorld = {
    bucket = 1,
    exitMargin = 15.0, -- mètres au-delà du rayon avant de revenir au monde PvP (pas d'allers-retours au bord)
}

-- Zombies des zones PvE : sans arme, ils foncent sur le joueur le plus proche et lui vomissent dessus.
-- Les dégâts, la portée et le délai entre deux attaques sont vérifiés par le serveur.
Config.Zombie = {
    aggroRange = 45.0, -- distance à laquelle un zombie repère un joueur
    attackRange = 1.8, -- distance à laquelle il vomit
    attackCooldown = 2500, -- ms entre deux vomissements d'un même zombie
    damage = 12, -- dégâts par vomissement (l'armure encaisse en premier)
    damageDelay = 600, -- ms entre le début de l'animation et les dégâts
    vomitDuration = 1800, -- ms d'effet de vomi
    walkStyle = 'move_m@drunk@verydrunk', -- démarche titubante
    -- Animation et particules du vomi
    anim = { dict = 'missheistpaletoscore1leadinout', name = 'trv_puking_leadout' },
    particle = { asset = 'scr_paletoscore', name = 'scr_trev_puke' },
    screenEffect = 'DrugsDrivingIn', -- effet d'écran du joueur touché
    damagePacks = { 'BigHitByVehicle', 'SCR_Torture' }, -- sang et blessures sur les zombies
}

-- ---------------------------------------------------------------------------
-- Monde
-- Population ambiante de GTA (piétons, trafic, véhicules garés, police).
-- Les PNJ des zones PvE sont créés par le gamemode et ne sont pas concernés.
-- ---------------------------------------------------------------------------

Config.World = {
    ambientPeds = false, -- piétons
    traffic = false, -- véhicules qui roulent
    parkedVehicles = false, -- véhicules garés
}

-- ---------------------------------------------------------------------------
-- Interface
-- ---------------------------------------------------------------------------

-- Inventaire / menu (nom de touche FiveM). TAB remplace aussi la roue des armes de GTA.
Config.MenuKey = 'TAB'
Config.MenuKeyLabel = 'TAB' -- nom affiché dans l'interface
-- Menu d'interaction : maintenir la touche, viser une cible (soi, joueur, butin, PNJ, véhicule)
-- et cliquer. LMENU = Alt gauche.
Config.InteractionKey = 'LMENU'
-- Barre de raccourcis : affichée quelques secondes quand on utilise un raccourci (1 à 7)
Config.HotbarShowTime = 2500 -- millisecondes

-- ---------------------------------------------------------------------------
-- Chute
-- ---------------------------------------------------------------------------

-- En PvP uniquement : pas de dégâts de chute, ni de chute « bras en l'air », ni de roulade ou de ragdoll à l'atterrissage
Config.Fall = {
    enabled = true,
    minSpeed = 5.0, -- vitesse de descente (m/s) d'une vraie chute : les petits sauts ne sont pas concernés
    -- Pose neutre jouée pendant la chute à la place de l'animation de GTA
    animDict = 'move_fall',
    animName = 'fall_low',
}

-- ---------------------------------------------------------------------------
-- Chat (un salon par mode de jeu)
-- ---------------------------------------------------------------------------

Config.Chat = {
    key = 'T', -- ouvrir la saisie
    maxLength = 200, -- caractères par message
    cooldown = 1000, -- ms minimum entre deux messages d'un même joueur
    announceJoins = true, -- message système quand un joueur rejoint / quitte un mode
}

-- ---------------------------------------------------------------------------
-- Largages aériens (PvP)
-- Une caisse tombe en parachute à un des points ci-dessous, signalée sur la carte.
-- Une fois posée, elle s'ouvre après `unlockDelay` secondes : son butin se fouille avec E.
-- Les hauteurs (z) sont approximatives : le client recale la caisse sur le sol.
-- ---------------------------------------------------------------------------

Config.Airdrops = {
    enabled = true,
    firstDelay = 300, -- secondes avant le premier largage après le démarrage
    interval = 1200, -- secondes entre deux largages
    minPlayers = 2, -- joueurs en PvP nécessaires
    fallTime = 25, -- secondes de chute en parachute (après le largage par l'avion)
    fallHeight = 150.0,
    unlockDelay = 60, -- secondes entre l'atterrissage et l'ouverture
    lifetime = 600, -- secondes avant que le butin ouvert disparaisse
    loot = 'airdrop', -- table de config/loot.lua
    -- Caisse militaire solide (collisions une fois posée). Autres modèles possibles :
    -- 'prop_mil_crate_02', 'gr_prop_gr_rsply_crate04a' (caisse de ravitaillement, plus grande)
    model = 'prop_mil_crate_01',
    parachute = 'p_cargo_chute_s',
    blip = { sprite = 94, color = 5 }, -- point de chute (affiché une fois la caisse larguée)
    -- Avion qui traverse la carte et largue la caisse au-dessus du point de chute
    plane = {
        model = 'titan',
        speed = 70.0, -- m/s
        approach = 2500.0, -- mètres parcourus avant le largage (vol visible avant d'arriver)
        exit = 1500.0, -- mètres parcourus après le largage avant de disparaître
        drawDistance = 1500.0, -- l'avion n'existe que près du joueur ; le repère, lui, est toujours visible
        blip = { sprite = 423, color = 5 },
    },
    locations = {
        vector3(501.0, 5604.0, 797.9), -- sommet du mont Chiliad
        vector3(-150.0, 6350.0, 31.5), -- Paleto Bay
        vector3(2340.0, 3130.0, 48.2), -- désert de Senora
        vector3(711.0, 1198.0, 348.5), -- panneau Vinewood
        vector3(-1650.0, -1000.0, 13.0), -- jetée de Del Perro
        vector3(3500.0, 3770.0, 30.0), -- Humane Labs
        vector3(2450.0, 4950.0, 45.0), -- Grapeseed
        vector3(-260.0, -2030.0, 30.1), -- Maze Bank Arena
    },
}

-- ---------------------------------------------------------------------------
-- Cycle jour / nuit (identique pour tous : calculé depuis l'heure réelle)
-- ---------------------------------------------------------------------------

Config.Time = {
    cycleMinutes = 48, -- minutes réelles pour une journée complète du jeu
    offsetHours = 8, -- décale le cycle (heure du jeu à minuit UTC pile d'un cycle)
}

-- La nuit, les zombies sont plus nombreux, plus rapides, plus résistants et mieux équipés
Config.Night = {
    from = 21, -- heure de début
    to = 6, -- heure de fin
    maxMultiplier = 1.5, -- nombre de zombies par zone
    healthMultiplier = 1.3,
    speedBonus = 0.5, -- ajouté à la vitesse (1.0 marche, 2.0 course, 3.0 sprint)
    extraLootRolls = 1, -- tirages de butin en plus par zombie
}

-- Types de zombies : `weight` = probabilité relative d'apparition (`nightWeight` la nuit, sinon `weight`).
-- health / damage : multiplicateurs ; speed : vitesse imposée (sinon celle de la zone) ;
-- range : distance de vomissement (m) ; cooldown : ms entre deux vomissements ;
-- models : modèles imposés (sinon ceux de la zone) ; lootRolls : tirages de butin en plus ;
-- gear : équipement visible (Config.ZombieGear) ; helmet : casque blindé ; explosion : explose à sa mort.
Config.ZombieTypes = {
    walker = { label = 'Rôdeur', weight = 70, health = 1.0, damage = 1.0 },
    runner = { label = 'Coureur', weight = 15, health = 0.6, damage = 0.8, speed = 3.0 },
    tank = {
        label = 'Colosse', weight = 7, health = 3.5, damage = 2.0, speed = 1.0, lootRolls = 2,
        models = { 'u_m_y_zombie_01', 'a_m_m_hillbilly_02', 's_m_y_construct_01' },
    },
    spitter = { label = 'Cracheur', weight = 8, health = 0.8, damage = 0.7, speed = 1.0, range = 10.0, cooldown = 4000 },
    -- Casque blindé : les tirs à la tête ne le tuent pas d'un coup tant que le casque tient
    armored = {
        label = 'Casqué', weight = 8, nightWeight = 12, health = 1.5, damage = 1.0, lootRolls = 1,
        gear = { 'helmet' },
        helmet = { hits = 3 }, -- tirs dans la tête avant que le casque saute
    },
    -- Bouteille de gaz dans le dos : elle explose à sa mort et blesse joueurs et zombies autour
    bomber = {
        label = 'Bonbonne', weight = 5, nightWeight = 8, health = 0.8, damage = 0.8, speed = 2.0, lootRolls = 1,
        gear = { 'gasTank' },
        explosion = {
            type = 23, -- explosion GTA (23 = bouteille de gaz ; non bloquée par l'anticheat)
            damage = 1.0, -- multiplicateur des dégâts de l'explosion
            delay = 700, -- ms entre la mort et l'explosion
            shake = 1.0, -- tremblement de caméra
        },
    },
    -- Ancien du SWAT : gilet pare-balles qui encaisse les premiers tirs (hitmarker bleu)
    swat = {
        label = 'SWAT', weight = 5, nightWeight = 8, health = 1.0, damage = 1.2, lootRolls = 1,
        models = { 's_m_y_swat_01' },
        armour = 100, -- points de gilet, perdus avant la vie (sauf tirs à la tête)
    },
    -- Bouclier pare-balles devant lui : viser la tête, les jambes, ou le contourner
    riot = {
        label = 'Anti-émeute', weight = 4, nightWeight = 6, health = 1.2, damage = 1.3, speed = 1.0, lootRolls = 1,
        models = { 's_m_y_cop_01' },
        gear = { 'shield' },
    },
    -- Masque à gaz : à sa mort, il libère un nuage toxique qui blesse les joueurs dedans
    -- (l'Antizin protège)
    toxic = {
        label = 'Toxique', weight = 4, nightWeight = 6, health = 1.0, damage = 1.0, lootRolls = 1,
        gear = { 'gasMask' },
        gasCloud = {
            radius = 6.0, -- mètres
            duration = 12, -- secondes
            damage = 6, -- dégâts toutes les `interval` ms (l'armure encaisse en premier)
            interval = 1000,
            particle = { asset = 'core', name = 'exp_grd_bzgas_smoke', scale = 2.0 },
            screenEffect = 'DrugsMichaelAliensFightIn',
        },
    },
}

-- Équipement visible des zombies (objets attachés à un os du ped, recréés par chaque client).
-- `options` : un modèle est choisi par zombie ; pos / rot : décalage par rapport à l'os
-- (à ajuster en jeu si l'objet est mal placé). `dropWhen` : la pièce tombe quand cet état
-- du zombie passe à vrai ; `remove` : elle disparaît au lieu de tomber au sol ;
-- `collision` : l'objet arrête les balles (bouclier).
-- Os utiles : 31086 tête, 12844 tête (IK), 24818 haut du dos.
Config.ZombieGear = {
    helmet = {
        dropWhen = 'helmetOff',
        options = {
            { model = 'prop_hard_hat_01', bone = 12844, pos = vector3(0.1, 0.0, 0.0), rot = vector3(180.0, 90.0, 0.0) },
            { model = 'prop_welding_mask_01', bone = 12844, pos = vector3(0.0, 0.0, 0.0), rot = vector3(180.0, 90.0, 0.0) },
        },
    },
    gasTank = {
        dropWhen = 'gasExploded',
        remove = true,
        options = {
            { model = 'p_s_scuba_tank_s', bone = 24818, pos = vector3(-0.25, -0.25, 0.0), rot = vector3(180.0, 90.0, 0.0) },
        },
    },
    shield = {
        collision = true,
        options = {
            { model = 'prop_ballistic_shield', bone = 24818, pos = vector3(-0.2, 0.4, 0.0), rot = vector3(180.0, 90.0, 0.0) },
        },
    },
    gasMask = {
        options = {
            { model = 'p_s_scuba_mask_s', bone = 12844, pos = vector3(0.0, 0.0, 0.0), rot = vector3(180.0, 90.0, 0.0) },
        },
    },
}

-- Hordes : une zone PvE où se trouvent des joueurs est envahie pendant `duration` secondes.
-- Les joueurs encore en vie dans la zone à la fin touchent la récompense.
Config.Hordes = {
    enabled = true,
    firstDelay = 900, -- secondes avant la première horde
    interval = 1800, -- secondes entre deux hordes
    retryDelay = 120, -- secondes avant de réessayer si aucune zone n'a de joueur
    duration = 300,
    maxMultiplier = 2.5, -- zombies en même temps dans la zone
    spawnPerTick = 3, -- zombies créés toutes les 1,5 s (au lieu d'un)
    reward = { money = 600, xp = 250 },
}
