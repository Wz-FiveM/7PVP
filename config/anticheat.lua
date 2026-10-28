-- Anti-cheat (server/modules/anticheat/anticheat_service.lua). Tout est vérifié par le serveur :
-- le client d'un tricheur ne peut pas le désactiver. Les admins ne sont jamais contrôlés.
--
-- Chaque détection donne une alerte. Quand un joueur en cumule `strikes` du même type en moins
-- de `Config.AntiCheat.strikeWindow` secondes, la sanction `action` s'applique :
--   'log'  : journal du serveur + salon Discord « sanctions » seulement
--   'kick' : expulsion
--   'ban'  : bannissement enregistré en base (`banDays` jours, 0 = définitif)
Config.AntiCheat = {
    enabled = true,
    strikeWindow = 300,

    detections = {
        weapon = { label = 'Arme non possédée', action = 'kick', strikes = 3 },
        damage = { label = 'Dégâts anormaux', action = 'kick', strikes = 3 },
        explosion = { label = 'Explosion interdite', action = 'ban', strikes = 2, banDays = 0 },
        entity = { label = 'Véhicule créé en PvP', action = 'kick', strikes = 3 },
        health = { label = 'Vie / armure au-dessus du maximum', action = 'kick', strikes = 3 },
        godmode = { label = 'Invincibilité', action = 'log', strikes = 1 },
        teleport = { label = 'Téléportation / vitesse impossible', action = 'log', strikes = 1 },
        spam = { label = 'Requêtes en rafale', action = 'kick', strikes = 2 },
        heartbeat = { label = 'Script client arrêté', action = 'kick', strikes = 1 },
    },

    -- Dégâts maximum d'une touche (le sniper fait ~100 ; au-delà, l'arme est modifiée)
    maxWeaponDamage = 250,
    -- Vie maximum d'un joueur (200 dans GTA, dont 100 sous le seuil de mort) et armure maximum
    maxHealth = 200,
    maxArmor = 100,
    -- Vitesse horizontale maximum en PvP (m/s). Une voiture rapide fait ~60 m/s.
    maxSpeed = 120.0,
    -- Les déplacements plus courts ne comptent pas (chute, ragdoll, petit décalage réseau)
    minTeleportDistance = 60.0,
    -- Délai de grâce après une téléportation légitime (réapparition, admin, lobby), en s
    teleportGrace = 10,
    -- Requêtes réseau par seconde et par joueur avant d'être ignorées
    rateLimits = {
        callback = 25, -- menus, inventaire, achats...
        hit = 40, -- touches signalées (hitmarker, zombies)
        loot = 10, -- ramassage de butin
    },
    -- Le client envoie un signal toutes les `heartbeatInterval` s ; sans signal pendant
    -- `heartbeatTimeout` s, son script a été arrêté (menu de triche « resource stopper »)
    heartbeatInterval = 20,
    heartbeatTimeout = 90,
    -- Types d'explosion interdits en PvP (armes explosives : grenade, roquette, bombe collante...).
    -- Les explosions de véhicules ou de pompes à essence touchées par balle restent permises.
    blockedExplosions = {
        [0] = true, [1] = true, [2] = true, [3] = true, [4] = true, [5] = true, [18] = true, [19] = true,
        [20] = true, [21] = true, [25] = true, [32] = true, [33] = true, [35] = true, [36] = true,
        [38] = true, [40] = true, [43] = true, [59] = true, [60] = true, [64] = true, [70] = true,
    },
}
