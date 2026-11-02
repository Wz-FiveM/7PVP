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
        damage = { label = 'Dégâts anormaux', action = 'log', strikes = 1 }, -- la touche n'est jamais annulée
        explosion = { label = 'Explosion interdite', action = 'ban', strikes = 2, banDays = 0 },
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

    -- Dégâts d'une touche au-delà desquels une alerte part (le sniper fait ~100). Les tirs à la tête
    -- et le corps à corps peuvent dépasser ce seuil sans triche : alerte seulement, jamais d'annulation.
    maxWeaponDamage = 250,
    -- Vie maximum d'un joueur (200 dans GTA, dont 100 sous le seuil de mort) et armure maximum
    maxHealth = 200,
    maxArmor = 100,
    -- Invincible hors zone safe : alerte après la durée du mode passif + cette marge, en s
    godmodeMargin = 10,
    -- Touches d'armes à feu encaissées d'affilée sans perdre de vie ni d'armure, et silence (s) qui remet à zéro
    immunityHits = 15,
    immunityGap = 8,
    -- Armes à feu observées (munitions de Config.Items) : ni fusils à pompe (plusieurs plombs par tir),
    -- ni explosifs. `head` : compte pour la part de tirs à la tête (un bon sniper vise la tête, c'est normal).
    trackedAmmo = {
        ammo_9mm = { head = true },
        ammo_45acp = { head = true },
        ammo_556 = { head = true },
        ammo_mg = { head = true },
        ammo_762 = { head = false },
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
        dungeonHit = 12, -- balles sur un mur de donjon, par paquet (au plus 2/s)
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
}
