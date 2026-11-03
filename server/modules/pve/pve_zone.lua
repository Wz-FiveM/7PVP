---Une zone PvE : gère l'apparition, la réapparition et la mort de ses zombies.
---Les zombies sont créés côté serveur (OneSync) et pilotés par le client
---propriétaire de l'entité (voir client/modules/pve/pve.lua).
---@class PveZone
---@field zone table entrée de Config.Zones
---@field config table bloc `npc` de la zone
---@field peds table<integer, string> ped -> type de zombie (Config.ZombieTypes)
---@field horde { endsAt: integer, kills: integer, boss: integer|nil, bossMax: integer|nil, bossKilled: boolean|nil }|nil horde en cours (voir HordeService)
---@field respawnQueue integer[] timestamps (ms) auxquels une place se libère
---@field emptySince integer|nil
local PveZone = PVP.define('PveZone')
local CombatService = PVP.use('CombatService')
local LootService = PVP.use('LootService')
local Utils = PVP.use('Utils')
local ModeRegistry = PVP.use('ModeRegistry')
local PveWorldService = PVP.use('PveWorldService')
local DungeonService = PVP.use('DungeonService')
local Clock = PVP.use('Clock')
local HordeService = PVP.use('HordeService')
local Events = PVP.use('Events')

PveZone.__index = PveZone
-- Les joueurs à cette distance voient le nuage toxique (les particules sont locales à chaque client)
PveZone.GAS_BROADCAST_RANGE = 120.0

---@param zone table
---@return PveZone
function PveZone.new(zone)
    return setmetatable({
        zone = zone,
        config = zone.npc,
        peds = {},
        respawnQueue = {},
        emptySince = nil,
        horde = nil,
    }, PveZone)
end

---Seuls les joueurs du mode PvP comptent (ceux du lobby ou du Freeroam sont ailleurs).
---@param extra number distance ajoutée au rayon de la zone
---@return boolean
function PveZone:hasPlayersNear(extra)
    for _, id in ipairs(ModeRegistry.getPlayers('pvp')) do
        local ped = GetPlayerPed(id)
        -- Un donjon peut se jouer au même endroit : ces joueurs sont dans leur instance
        if ped ~= 0 and not DungeonService.isInRun(id) and #(GetEntityCoords(ped) - self.zone.coords) <= self.zone.radius + extra then
            return true
        end
    end
    return false
end

---@param ped integer
---@return boolean
function PveZone:owns(ped)
    return self.peds[ped] ~= nil
end

---@param now integer
function PveZone:pruneRespawnQueue(now)
    local queue = {}
    for _, t in ipairs(self.respawnQueue) do
        if t > now then queue[#queue + 1] = t end
    end
    self.respawnQueue = queue
end

function PveZone:pruneMissingPeds()
    for ped in pairs(self.peds) do
        if not DoesEntityExist(ped) then
            self.peds[ped] = nil
        end
    end
end

---Zombies en même temps : plus la nuit, beaucoup plus pendant une horde.
---@return integer
function PveZone:getMax()
    local max = self.config.max
    if Clock.isNight() then max = max * Config.Night.maxMultiplier end
    if self.horde then max = max * Config.Hordes.maxMultiplier end
    return math.floor(max)
end

---@return boolean
function PveZone:hasFreeSlot()
    -- Pendant une horde, pas d'attente de réapparition
    local waiting = self.horde and 0 or #self.respawnQueue
    return Utils.count(self.peds) + waiting < self:getMax()
end

---Poids d'apparition d'un type : les zombies équipés sont plus fréquents la nuit.
---@param zombieType table
---@param night boolean
---@return number
function PveZone.getWeight(zombieType, night)
    return night and zombieType.nightWeight or zombieType.weight
end

---Tire un type de zombie selon les poids de Config.ZombieTypes, ou ceux imposés par la zone.
---@param weights? table<string, number> poids par type (npc.types de la zone)
---@return string
function PveZone.pickType(weights)
    local night = Clock.isNight()
    local total = 0
    for id, zombieType in pairs(Config.ZombieTypes) do total = total + PveZone.weightOf(id, zombieType, night, weights) end
    local roll = math.random() * total
    for id, zombieType in pairs(Config.ZombieTypes) do
        local weight = PveZone.weightOf(id, zombieType, night, weights)
        roll = roll - weight
        if weight > 0 and roll <= 0 then return id end
    end
    return weights and next(weights) or 'walker'
end

---@param id string
---@param zombieType table
---@param night boolean
---@param weights? table<string, number>
---@return number
function PveZone.weightOf(id, zombieType, night, weights)
    if weights then return weights[id] or 0 end
    return PveZone.getWeight(zombieType, night)
end

function PveZone:spawnNpc()
    local typeId = PveZone.pickType(self.config.types)
    local zombieType = Config.ZombieTypes[typeId]
    local ped = self:createPed(Utils.pick(self.config.spawns), Utils.pick(zombieType.models or self.config.models), typeId)
    if ped then self.peds[ped] = typeId end
end

---PNJ de la zone, dans le monde zombies et sans arme (le client propriétaire équipe les humains).
---@param point vector4
---@param model string
---@param typeId string entrée de Config.ZombieTypes
---@return integer|nil
function PveZone:createPed(point, model, typeId)
    local ped = CreatePed(4, GetHashKey(model), point.x, point.y, point.z, point.w, true, true)

    local timeout = GetGameTimer() + 2000
    while not DoesEntityExist(ped) and GetGameTimer() < timeout do Wait(0) end
    if not DoesEntityExist(ped) then return nil end

    -- Garde l'entité même si son propriétaire se déconnecte
    SetEntityOrphanMode(ped, 2)
    -- Seulement dans le monde zombies (Config.PveWorld)
    SetEntityRoutingBucket(ped, Config.PveWorld.bucket)
    -- Zombie : aucune arme, il attaque en vomissant (voir client/modules/pve/pve.lua)
    RemoveAllPedWeapons(ped, true)
    -- Le type avant la zone : le client ne regarde que les PNJ qui ont une zone, et doit déjà savoir s'il est armé
    Entity(ped).state:set('zombieType', typeId, true)
    Entity(ped).state:set('pvpNpc', self.zone.id, true)
    return ped
end

---Nuage toxique d'un zombie mort : chaque joueur proche du monde zombies affiche la fumée et subit
---les dégâts tant qu'il reste dedans (voir client/modules/pve/zombie_gear.lua).
---@param coords vector3
---@param typeId string
---@param bucket? integer défaut : le monde zombies
function PveZone.releaseGas(coords, typeId, bucket)
    bucket = bucket or Config.PveWorld.bucket
    for _, id in ipairs(ModeRegistry.getPlayers('pvp')) do
        if GetPlayerRoutingBucket(id) == bucket and PveWorldService.isInside(id)
            and #(GetEntityCoords(GetPlayerPed(id)) - coords) <= PveZone.GAS_BROADCAST_RANGE then
            TriggerClientEvent(Events.client.zombieGasCloud, id, coords, typeId)
        end
    end
end

function PveZone:despawnAll()
    for ped in pairs(self.peds) do
        if DoesEntityExist(ped) then DeleteEntity(ped) end
    end
    self.peds = {}
    self.respawnQueue = {}
end

---@param ped integer
---@param killer PvpPlayer|nil
function PveZone:onNpcDeath(ped, killer)
    -- Le mini boss de la horde n'est pas compté dans les zombies de la zone
    if self.horde and self.horde.boss == ped then return HordeService.onBossDeath(self, ped, killer) end
    if not self:owns(ped) then return end
    local typeId = self.peds[ped]
    local zombieType = Config.ZombieTypes[typeId] or Config.ZombieTypes.walker
    self.peds[ped] = nil
    self.respawnQueue[#self.respawnQueue + 1] = GetGameTimer() + self.config.respawn * 1000
    -- Mort comptée : le prochain propriétaire du corps ne la signalera pas (Pve.reportDeath)
    Entity(ped).state:set('pvpNpcDead', true, true)

    if killer then
        CombatService.rewardNpcKill(killer, self.zone.id)
    end

    -- Le butin reste sur le corps : il disparaît une fois fouillé (ou à l'expiration du butin)
    if self.horde then self.horde.kills = self.horde.kills + 1 end

    if zombieType.gasCloud then
        PveZone.releaseGas(GetEntityCoords(ped), typeId)
    end

    -- Plus de butin la nuit et sur les zombies spéciaux
    local rolls = 1 + (zombieType.lootRolls or 0) + (Clock.isNight() and Config.Night.extraLootRolls or 0)
    local lootId = LootService.drop(GetEntityCoords(ped), LootService.rollMany(self.config.loot, rolls),
        { netId = NetworkGetNetworkIdFromEntity(ped), bucket = Config.PveWorld.bucket })
    if lootId then return end

    -- Rien à fouiller : le corps est supprimé rapidement
    SetTimeout(Config.NpcCorpseTime * 1000, function()
        if DoesEntityExist(ped) then DeleteEntity(ped) end
    end)
end

---@param now integer
function PveZone:tick(now)
    self:pruneMissingPeds()

    if not self:hasPlayersNear(Config.PveActivationDistance) then
        self.emptySince = self.emptySince or now
        if now - self.emptySince >= Config.PveDespawnDelay * 1000 and next(self.peds) then
            self:despawnAll()
        end
        return
    end

    self.emptySince = nil
    self:pruneRespawnQueue(now)

    -- Un zombie par tick pour étaler les spawns (plusieurs pendant une horde)
    local count = self.horde and Config.Hordes.spawnPerTick or 1
    for _ = 1, count do
        if not self:hasFreeSlot() then break end
        self:spawnNpc()
    end
end
