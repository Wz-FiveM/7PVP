-- Anti-cheat (server/modules/anticheat/anticheat_service.lua). Tout est vérifié par le serveur :
-- le client d'un tricheur ne peut pas le désactiver. Les admins ne sont jamais contrôlés.
--
-- Chaque détection donne une alerte. Quand un joueur en cumule `strikes` du même type en moins
-- de `window` secondes (sinon `Config.AntiCheat.strikeWindow`), la sanction `action` s'applique :
--   'log'  : journal du serveur + salon Discord « sanctions » seulement
--   'kick' : expulsion
--   'ban'  : bannissement enregistré en base (`banDays` jours, 0 = définitif)
Config.AntiCheat = {
    enabled = true,
    strikeWindow = 300,

    detections = {
        weapon = { label = 'Arme non possédée', action = 'kick', strikes = 3 },
        -- L'arme est retirée à chaque alerte. Il faut donc qu'elle revienne pour atteindre l'expulsion.
        heldWeapon = { label = 'Arme donnée par un menu', action = 'kick', strikes = 3 },
        -- Damage boost, jamais vus sur de vrais joueurs : alerte seulement tant que le journal n'a pas montré
        -- qu'ils épargnent les joueurs honnêtes. Passer action à 'kick' pour sanctionner. La touche n'est jamais annulée.
        damage = { label = 'Dégâts anormaux', action = 'log', strikes = 3 },
        damageModifier = { label = 'Multiplicateur de dégâts', action = 'log', strikes = 3 },
        -- L'explosion est toujours annulée : l'expulsion suffit. Le 03/11, 4 joueurs ont été bannis à tort
        -- (voir explosionSharedTime)
        explosion = { label = 'Explosion interdite', action = 'kick', strikes = 3 },
        entity = { label = 'Véhicule créé en PvP', action = 'kick', strikes = 3 },
        health = { label = 'Vie / armure au-dessus du maximum', action = 'kick', strikes = 3 },
        -- Une alerte toutes les 15 s d'invincibilité continue (godmodeMargin) : expulsion après 45 s
        godmode = { label = 'Invincibilité', action = 'kick', strikes = 3 },
        -- Déductions à partir des touches : alerte seulement tant que le journal n'a pas montré qu'elles
        -- épargnent les joueurs honnêtes. Passer action à 'kick' pour sanctionner.
        immunity = { label = 'Touches sans aucun effet', action = 'log', strikes = 3 },
        aimbot = { label = 'Aimbot suspecté', action = 'log', strikes = 3 },
        -- Un seul joueur signalé du 28/10 au 02/11 (51 alertes en une minute, à 150 m/s) : le seuil épargne les autres
        teleport = { label = 'Téléportation / vitesse impossible', action = 'kick', strikes = 3 },
        noclip = { label = 'Noclip', action = 'kick', strikes = 3 },
        -- Lus dans l'état envoyé par le jeu et jamais vus sur de vrais joueurs : alerte seulement tant que le
        -- journal n'a pas montré qu'ils épargnent les joueurs honnêtes. Passer action à 'kick' pour sanctionner.
        collision = { label = 'Collisions coupées', action = 'log', strikes = 3 },
        freecam = { label = 'Freecam', action = 'log', strikes = 3 },
        -- Une alerte par seconde de dépassement : seul un envoi en boucle tient 5 s sur 10, pas un pic de combat.
        spam = { label = 'Requêtes en rafale', action = 'kick', strikes = 5, window = 10 },
        heartbeat = { label = 'Script client arrêté', action = 'kick', strikes = 1 },
        -- Le kill n'est pas compté. Alerte seulement : un kill rare peut échapper au contrôle (pompe à essence...)
        kill = { label = 'Kill annoncé sans touche', action = 'log', strikes = 1 },
    },

    -- Dégâts d'une touche sur un joueur : le maximum vient de weaponDamage, avec le multiplicateur de la classe du
    -- tireur et cette marge. Une alerte part à `damageHits` touches au-dessus en `damageWindow` secondes.
    damageMargin = 1.3,
    damageHits = 3,
    damageWindow = 30,
    -- Maximum des armes absentes de weaponDamage : corps à corps et explosifs (une grenade fait 500)
    maxWeaponDamage = 600,
    -- Armes à balles de config/items.lua, lues dans les weapons.meta de GTA : dégâts d'une balle, multiplicateur
    -- d'un tir à la tête sur un joueur, plombs par tir. Le journal confirme : canon scié 320 (40 x 8), tête au pistolet ~520.
    weaponDamage = {
        WEAPON_PISTOL = { damage = 26, head = 20 },
        WEAPON_PISTOL_MK2 = { damage = 32, head = 20 },
        WEAPON_COMBATPISTOL = { damage = 27, head = 20 },
        WEAPON_APPISTOL = { damage = 25, head = 18 },
        WEAPON_PISTOL50 = { damage = 51, head = 18 },
        WEAPON_HEAVYPISTOL = { damage = 40, head = 20 },
        WEAPON_SNSPISTOL = { damage = 28, head = 20 },
        WEAPON_SNSPISTOL_MK2 = { damage = 30, head = 20 },
        WEAPON_VINTAGEPISTOL = { damage = 34, head = 20 },
        WEAPON_CERAMICPISTOL = { damage = 32, head = 20 },
        WEAPON_MARKSMANPISTOL = { damage = 220, head = 18 },
        WEAPON_REVOLVER = { damage = 160, head = 18 },
        WEAPON_REVOLVER_MK2 = { damage = 200, head = 18 },
        WEAPON_DOUBLEACTION = { damage = 81, head = 18 },
        WEAPON_NAVYREVOLVER = { damage = 160, head = 18 },
        WEAPON_MICROSMG = { damage = 21, head = 18 },
        WEAPON_MINISMG = { damage = 22, head = 18 },
        WEAPON_MACHINEPISTOL = { damage = 27, head = 18 },
        WEAPON_SMG = { damage = 22, head = 18 },
        WEAPON_SMG_MK2 = { damage = 25, head = 18 },
        WEAPON_ASSAULTSMG = { damage = 23, head = 18 },
        WEAPON_COMBATPDW = { damage = 28, head = 18 },
        WEAPON_PUMPSHOTGUN = { damage = 29, head = 18, pellets = 8 },
        WEAPON_PUMPSHOTGUN_MK2 = { damage = 32, head = 18, pellets = 8 },
        WEAPON_SAWNOFFSHOTGUN = { damage = 40, head = 18, pellets = 8 },
        WEAPON_DBSHOTGUN = { damage = 30, head = 2.5, pellets = 8 },
        WEAPON_BULLPUPSHOTGUN = { damage = 14, head = 18, pellets = 8 },
        WEAPON_ASSAULTSHOTGUN = { damage = 32, head = 18, pellets = 6 },
        WEAPON_AUTOSHOTGUN = { damage = 27, head = 8, pellets = 6 },
        WEAPON_HEAVYSHOTGUN = { damage = 117, head = 18 },
        WEAPON_COMBATSHOTGUN = { damage = 31, head = 18, pellets = 6 },
        WEAPON_MUSKET = { damage = 165, head = 18 },
        WEAPON_CARBINERIFLE = { damage = 32, head = 18 },
        WEAPON_CARBINERIFLE_MK2 = { damage = 33, head = 18 },
        WEAPON_ASSAULTRIFLE = { damage = 30, head = 18 },
        WEAPON_ASSAULTRIFLE_MK2 = { damage = 40, head = 18 },
        WEAPON_ADVANCEDRIFLE = { damage = 34, head = 18 },
        WEAPON_SPECIALCARBINE = { damage = 32, head = 18 },
        WEAPON_SPECIALCARBINE_MK2 = { damage = 32.5, head = 18 },
        WEAPON_BULLPUPRIFLE = { damage = 32, head = 18 },
        WEAPON_BULLPUPRIFLE_MK2 = { damage = 33, head = 18 },
        WEAPON_COMPACTRIFLE = { damage = 34, head = 18 },
        WEAPON_MILITARYRIFLE = { damage = 37.5, head = 18 },
        WEAPON_HEAVYRIFLE = { damage = 34, head = 18 },
        WEAPON_TACTICALRIFLE = { damage = 34.75, head = 18 },
        WEAPON_MG = { damage = 40, head = 18 },
        WEAPON_COMBATMG = { damage = 45, head = 18 },
        WEAPON_COMBATMG_MK2 = { damage = 47, head = 18 },
        WEAPON_GUSENBERG = { damage = 34, head = 18 },
        WEAPON_RAYCARBINE = { damage = 45, head = 18 },
        WEAPON_SNIPERRIFLE = { damage = 101, head = 18 },
        WEAPON_HEAVYSNIPER = { damage = 216, head = 18 },
        WEAPON_HEAVYSNIPER_MK2 = { damage = 230, head = 18 },
        WEAPON_MARKSMANRIFLE = { damage = 65, head = 18 },
        WEAPON_MARKSMANRIFLE_MK2 = { damage = 75, head = 18 },
        WEAPON_PRECISIONRIFLE = { damage = 101, head = 18 },
        WEAPON_MINIGUN = { damage = 30, head = 18 },
        WEAPON_RAYMINIGUN = { damage = 30, head = 18 },
    },
    -- Multiplicateur de dégâts envoyé par le jeu, comparé à ce que permet la classe du joueur. `tolerance` couvre
    -- l'arrondi du réseau (0,01 pour les armes, 0,1 pour le corps à corps). Relevés toutes les 2 s, `readings` de suite.
    damageModifier = {
        weaponTolerance = 0.02,
        meleeTolerance = 0.15,
        readings = 3,
    },
    -- Vie maximum d'un joueur (200 dans GTA, dont 100 sous le seuil de mort) et armure maximum
    maxHealth = 200,
    maxArmor = 100,
    -- Invincible hors zone safe : alerte après la durée du mode passif + cette marge, en s
    godmodeMargin = 10,
    -- Touches d'armes à feu encaissées d'affilée sans perdre de vie ni d'armure, et silence (s) qui remet à zéro
    immunityHits = 15,
    immunityGap = 8,
    -- TEMPORAIRE (enquête du 2026-11-03 : touches entre joueurs sans dégâts) : chaque touche d'un joueur
    -- sur un autre est écrite dans la console, avec la vie de la cible juste après. À retirer ensuite.
    hitJournal = true,
    -- Armes à feu observées (munitions de Config.Items) : ni fusils à pompe (plusieurs plombs par tir),
    -- ni explosifs. `head` : compte pour la part de tirs à la tête (un bon sniper vise la tête, c'est normal).
    trackedAmmo = {
        mag_9mm = { head = true },
        mag_45acp = { head = true },
        mag_556 = { head = true },
        mag_mg = { head = true },
        mag_762 = { head = false },
    },
    -- Touches sur des joueurs, sur les `window` dernières secondes et au-delà de `minDistance` m (de près,
    -- viser la tête est facile et la caméra décalée fausse l'angle)
    aimbot = {
        window = 120,
        minDistance = 12.0,
        headComponent = 20, -- partie touchée : la tête
        headSamples = 25, -- touches minimum avant de juger
        headRatio = 0.8,
        -- Silent aim : la balle touche un joueur que la caméra ne regarde pas
        offAimAngle = 25.0, -- degrés entre la caméra et la cible
        offAimHits = 8,
        offAimRatio = 0.5,
    },
    -- Vitesse maximum en PvP (m/s), toutes directions. Une voiture rapide fait ~60 m/s.
    maxSpeed = 120.0,
    -- Vitesse horizontale d'un saut à pied, loin de tout véhicule (m/s). Le sprint fait ~8 m/s.
    maxFootJumpSpeed = 60.0,
    -- Les déplacements plus courts ne comptent pas (chute, ragdoll, petit décalage réseau)
    minTeleportDistance = 60.0,
    -- Délai de grâce après une téléportation légitime (réapparition, admin, lobby), en s
    teleportGrace = 10,
    -- Temps de coupure réseau (s) pris en compte quand la position d'un joueur en mouvement ne change plus
    lagCredit = 15,
    -- Après un véhicule, le personnage garde son élan : pas de contrôle à pied pendant ce délai, en s
    vehicleExitGrace = 8,
    -- Relevés (un par seconde) : un signal doit tenir `*Readings` relevés de suite pour donner une alerte
    noclip = {
        maxSpeed = 30.0, -- horizontale à pied, m/s
        fallSpeed = 5.0, -- descend plus vite que ça (m/s) : chute ou parachute, la vitesse à pied ne compte pas
        fastReadings = 3,
        maxClimb = 8.0, -- montée à pied, m/s (échelle, escalier et pente restent en dessous)
        climbReadings = 3,
        frozenDistance = 3.0, -- personnage figé qui se déplace de plus que ça entre deux relevés, en m
        frozenReadings = 2,
        collisionReadings = 10,
    },
    freecam = {
        distance = 40.0, -- à pied, en m
        vehicleDistance = 150.0, -- en véhicule, en m
        readings = 10,
    },
    -- Requêtes réseau par seconde et par joueur avant d'être ignorées
    rateLimits = {
        callback = 25, -- menus, inventaire, achats...
        -- Combat : un client honnête reste en dessous quel que soit le nombre de zombies, il regroupe ses envois
        hit = 40, -- touches sur ce joueur (au plus 20/s)
        npcHit = 25, -- touches sur ses zombies, par paquet (au plus 10/s)
        zombieAttack = 40, -- vomis de ses zombies (au plus 24/s)
        npcDeath = 40, -- morts de ses zombies (au plus 24/s)
        loot = 10, -- ramassage de butin
        dungeonHit = 12, -- balles sur une porte de donjon, par paquet (au plus 2/s)
        dungeonBarrel = 12, -- bonbonnes touchées dans un donjon
        ui = 2, -- erreurs d'interface signalées (journal)
    },
    -- Le client envoie un signal toutes les `heartbeatInterval` s ; sans signal pendant
    -- `heartbeatTimeout` s, son script a été arrêté (menu de triche « resource stopper »)
    heartbeatInterval = 20,
    heartbeatTimeout = 90,
    -- Types d'explosion interdits en PvP (armes explosives : grenade, roquette, bombe collante...),
    -- sauf pour un joueur qui possède (ou vient de lancer) l'arme correspondante (explosionWeapons).
    -- Les explosions de véhicules ou de pompes à essence touchées par balle restent permises.
    blockedExplosions = {
        [0] = true, [1] = true, [2] = true, [3] = true, [4] = true, [5] = true, [18] = true, [19] = true,
        [20] = true, [21] = true, [25] = true, [32] = true, [33] = true, [35] = true, [36] = true,
        [38] = true, [40] = true, [43] = true, [59] = true, [60] = true, [64] = true, [70] = true,
    },
    -- Type d'explosion GTA -> objets qui la provoquent (config/items.lua)
    explosionWeapons = {
        [0] = { 'weapon_grenade' },
        [1] = { 'weapon_grenadelauncher', 'weapon_compactlauncher' },
        [2] = { 'weapon_stickybomb' },
        [3] = { 'weapon_molotov' },
        [4] = { 'weapon_rpg', 'weapon_hominglauncher' },
        [20] = { 'weapon_smokegrenade' },
        [21] = { 'weapon_bzgas' },
        [36] = { 'weapon_railgun' },
        [38] = { 'weapon_firework' },
        [40] = { 'weapon_proxmine' },
        [43] = { 'weapon_pipebomb' },
    },
    -- Secondes pendant lesquelles une arme de jet lancée (donc plus dans l'inventaire) reste permise
    throwGrace = 30,
    -- Même explosion envoyée par plusieurs joueurs à moins de `explosionSharedTime` ms et `explosionSharedRange` m
    -- l'une de l'autre : elle ne vient d'aucun d'eux (ou l'un d'eux avait l'arme), pas d'alerte
    explosionSharedTime = 1500,
    explosionSharedRange = 15.0,
}
