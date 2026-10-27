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

-- ---------------------------------------------------------------------------
-- Sacs de butin
-- ---------------------------------------------------------------------------

Config.LootLifetime = 300 -- secondes avant disparition
Config.LootPickupDistance = 2.0
Config.LootModel = 'prop_cs_heist_bag_02'

-- ---------------------------------------------------------------------------
-- PvE
-- ---------------------------------------------------------------------------

Config.PveActivationDistance = 200.0 -- les PNJ apparaissent quand un joueur est à radius + cette distance
Config.PveDespawnDelay = 60 -- secondes sans joueur avant de supprimer les PNJ
Config.NpcCorpseTime = 20 -- secondes avant suppression du corps
Config.NpcAggroRange = 70.0

-- ---------------------------------------------------------------------------
-- Interface
-- ---------------------------------------------------------------------------

Config.MenuKey = 'F2'
