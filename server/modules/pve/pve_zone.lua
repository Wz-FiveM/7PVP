---Une zone PvE : gère l'apparition, la réapparition et la mort de ses zombies.
---Les zombies sont créés côté serveur (OneSync) et pilotés par le client
---propriétaire de l'entité (voir client/modules/pve/pve.lua).
---@class PveZone
---@field zone table entrée de Config.Zones
---@field config table bloc `npc` de la zone
---@field peds table<integer, string> ped -> type de zombie (Config.ZombieTypes)
---@field horde { endsAt: integer, kills: integer }|nil horde en cours (voir HordeService)
---@field respawnQueue integer[] timestamps (ms) auxquels une place se libère
---@field emptySince integer|nil
local PveZone = PVP.define('PveZone')
local CombatService = PVP.use('CombatService')
local LootService = PVP.use('LootService')
local Utils = PVP.use('Utils')
local ModeRegistry = PVP.use('ModeRegistry')
local Clock = PVP.use('Clock')

PveZone.__index = PveZone

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
        if ped ~= 0 and #(GetEntityCoords(ped) - self.zone.coords) <= self.zone.radius + extra then
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

---Tire un type de zombie selon les poids de Config.ZombieTypes.
---@return string
function PveZone.pickType()
    local total = 0
    for _, zombieType in pairs(Config.ZombieTypes) do total = total + zombieType.weight end
    local roll = math.random() * total
    for id, zombieType in pairs(Config.ZombieTypes) do
        roll = roll - zombieType.weight
        if roll <= 0 then return id end
    end
    return 'walker'
end

function PveZone:spawnNpc()
    local point = Utils.pick(self.config.spawns)
    local typeId = PveZone.pickType()
    local zombieType = Config.ZombieTypes[typeId]
    local model = GetHashKey(Utils.pick(zombieType.models or self.config.models))
    local ped = CreatePed(4, model, point.x, point.y, point.z, point.w, true, true)

    local timeout = GetGameTimer() + 2000
    while not DoesEntityExist(ped) and GetGameTimer() < timeout do Wait(0) end
    if not DoesEntityExist(ped) then return end

    -- Garde l'entité même si son propriétaire se déconnecte
    SetEntityOrphanMode(ped, 2)
    -- Zombie : aucune arme, il attaque en vomissant (voir client/modules/pve/pve.lua)
    RemoveAllPedWeapons(ped, true)
    Entity(ped).state:set('pvpNpc', self.zone.id, true)
    Entity(ped).state:set('zombieType', typeId, true)

    self.peds[ped] = typeId
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
    if not self:owns(ped) then return end
    local zombieType = Config.ZombieTypes[self.peds[ped]] or Config.ZombieTypes.walker
    self.peds[ped] = nil
    self.respawnQueue[#self.respawnQueue + 1] = GetGameTimer() + self.config.respawn * 1000

    if killer then
        CombatService.rewardNpcKill(killer, self.zone.id)
    end

    -- Le butin reste sur le corps : il disparaît une fois fouillé (ou à l'expiration du butin)
    if self.horde then self.horde.kills = self.horde.kills + 1 end

    -- Plus de butin la nuit et sur les zombies spéciaux
    local rolls = 1 + (zombieType.lootRolls or 0) + (Clock.isNight() and Config.Night.extraLootRolls or 0)
    local lootId = LootService.drop(GetEntityCoords(ped), LootService.rollMany(self.config.loot, rolls),
        NetworkGetNetworkIdFromEntity(ped))
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
