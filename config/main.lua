Config = {}

Config.Debug = false

-- ---------------------------------------------------------------------------
-- Joueur
-- ---------------------------------------------------------------------------

Config.AutoSaveInterval = 5 * 60 -- secondes
Config.RespawnDelay = 8 -- secondes avant de réapparaître
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

Config.MenuKey = 'F2'
Config.HotbarKey = 'TAB' -- maintenir pour afficher la barre de raccourcis (remplace la roue des armes)

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
    fallTime = 25, -- secondes de chute en parachute
    fallHeight = 150.0,
    unlockDelay = 60, -- secondes entre l'atterrissage et l'ouverture
    lifetime = 600, -- secondes avant que le butin ouvert disparaisse
    loot = 'airdrop', -- table de config/loot.lua
    model = 'prop_drop_armscrate_01',
    parachute = 'p_cargo_chute_s',
    blip = { sprite = 94, color = 5 },
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

-- Types de zombies : `weight` = probabilité relative d'apparition.
-- health / damage : multiplicateurs ; speed : vitesse imposée (sinon celle de la zone) ;
-- range : distance de vomissement (m) ; cooldown : ms entre deux vomissements ;
-- models : modèles imposés (sinon ceux de la zone) ; lootRolls : tirages de butin en plus.
Config.ZombieTypes = {
    walker = { label = 'Rôdeur', weight = 70, health = 1.0, damage = 1.0 },
    runner = { label = 'Coureur', weight = 15, health = 0.6, damage = 0.8, speed = 3.0 },
    tank = {
        label = 'Colosse', weight = 7, health = 3.5, damage = 2.0, speed = 1.0, lootRolls = 2,
        models = { 'u_m_y_zombie_01', 'a_m_m_hillbilly_02', 's_m_y_construct_01' },
    },
    spitter = { label = 'Cracheur', weight = 8, health = 0.8, damage = 0.7, speed = 1.0, range = 10.0, cooldown = 4000 },
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
