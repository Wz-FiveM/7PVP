---Une zone PvE : gère l'apparition, la réapparition et la mort de ses PNJ.
---Les PNJ sont créés côté serveur (OneSync) et pilotés par le client
---propriétaire de l'entité (voir client/modules/pve/pve.lua).
---@class PveZone
---@field zone table entrée de Config.Zones
---@field config table bloc `npc` de la zone
---@field peds table<integer, boolean>
---@field respawnQueue integer[] timestamps (ms) auxquels une place se libère
---@field emptySince integer|nil
local PveZone = PVP.define('PveZone')
local CombatService = PVP.use('CombatService')
local LootService = PVP.use('LootService')
local Utils = PVP.use('Utils')

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
    }, PveZone)
end

---@param extra number distance ajoutée au rayon de la zone
---@return boolean
function PveZone:hasPlayersNear(extra)
    for _, id in ipairs(GetPlayers()) do
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
    return self.peds[ped] == true
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

---@return boolean
function PveZone:hasFreeSlot()
    return Utils.count(self.peds) + #self.respawnQueue < self.config.max
end

function PveZone:spawnNpc()
    local point = Utils.pick(self.config.spawns)
    local model = GetHashKey(Utils.pick(self.config.models))
    local ped = CreatePed(4, model, point.x, point.y, point.z, point.w, true, true)

    local timeout = GetGameTimer() + 2000
    while not DoesEntityExist(ped) and GetGameTimer() < timeout do Wait(0) end
    if not DoesEntityExist(ped) then return end

    -- Garde l'entité même si son propriétaire se déconnecte
    SetEntityOrphanMode(ped, 2)
    GiveWeaponToPed(ped, GetHashKey(Utils.pick(self.config.weapons)), 500, false, true)
    if self.config.armor and self.config.armor > 0 then
        SetPedArmour(ped, self.config.armor)
    end
    Entity(ped).state:set('pvpNpc', self.zone.id, true)

    self.peds[ped] = true
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
    self.peds[ped] = nil
    self.respawnQueue[#self.respawnQueue + 1] = GetGameTimer() + self.config.respawn * 1000

    if killer then
        CombatService.rewardNpcKill(killer)
    end

    LootService.drop(GetEntityCoords(ped), LootService.roll(self.config.loot))

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

    -- Un PNJ par tick pour étaler les spawns
    if self:hasFreeSlot() then
        self:spawnNpc()
    end
end
