---IA des PNJ des zones PvE. Seul le client propriétaire (au sens réseau)
---d'un PNJ le pilote et signale sa mort au serveur.
---@class PveModule
local Pve = PVP.define('Pve')
local Zones = PVP.use('Zones')
local PedUtils = PVP.use('PedUtils')
local Events = PVP.use('Events')

Pve.SCAN_INTERVAL = 1000

Pve.npcGroup = 0
Pve.configured = {} -- [ped] = true quand l'IA a été appliquée sur ce client
Pve.reported = {} -- [ped] = true quand la mort a été signalée
Pve.wandering = {} -- [ped] = true quand le PNJ patrouille

function Pve.init()
    Pve.setupRelationships()
    CreateThread(Pve.loop)
end

function Pve.setupRelationships()
    local _, group = AddRelationshipGroup('PVP_NPC')
    local playerGroup = GetHashKey('PLAYER')
    Pve.npcGroup = group
    SetRelationshipBetweenGroups(5, group, playerGroup)
    SetRelationshipBetweenGroups(5, playerGroup, group)
    SetRelationshipBetweenGroups(0, group, group)
end

function Pve.loop()
    while true do
        Wait(Pve.SCAN_INTERVAL)
        Pve.scan()
        Pve.cleanup()
    end
end

function Pve.scan()
    local myId = PlayerId()
    for _, ped in ipairs(GetGamePool('CPed')) do
        if NetworkGetEntityIsNetworked(ped) and not IsPedAPlayer(ped) then
            local zone = Zones.byId(Entity(ped).state.pvpNpc)
            if zone and NetworkGetEntityOwner(ped) == myId then
                Pve.updatePed(ped, zone)
            end
        end
    end
end

function Pve.cleanup()
    for _, tracked in ipairs({ Pve.configured, Pve.reported, Pve.wandering }) do
        for ped in pairs(tracked) do
            if not DoesEntityExist(ped) then tracked[ped] = nil end
        end
    end
end

---@param ped integer
---@param zone table
function Pve.updatePed(ped, zone)
    if IsEntityDead(ped) then
        Pve.reportDeath(ped)
        return
    end

    if not Pve.configured[ped] then
        Pve.setupPed(ped, zone.npc)
        Pve.configured[ped] = true
    end

    if not IsPedInCombat(ped, 0) then
        Pve.updateBehaviour(ped, zone)
    end
end

---@param ped integer
function Pve.reportDeath(ped)
    if Pve.reported[ped] then return end
    Pve.reported[ped] = true
    TriggerServerEvent(Events.server.npcDied, NetworkGetNetworkIdFromEntity(ped), PedUtils.getKillerServerId(ped))
end

---@param ped integer
---@param npc table bloc `npc` de la zone
function Pve.setupPed(ped, npc)
    local state = Entity(ped).state

    -- La vie n'est appliquée qu'une fois, sinon un changement de propriétaire la remettrait au max
    if not state.pvpNpcReady then
        SetPedMaxHealth(ped, npc.health)
        SetEntityHealth(ped, npc.health)
        state:set('pvpNpcReady', true, true)
    end

    SetPedRelationshipGroupHash(ped, Pve.npcGroup)
    SetPedAccuracy(ped, npc.accuracy)
    SetPedCombatAbility(ped, 2)
    SetPedCombatRange(ped, 2)
    SetPedCombatMovement(ped, 2)
    SetPedCombatAttributes(ped, 5, true) -- peut se battre à mains nues
    SetPedCombatAttributes(ped, 46, true) -- se bat toujours
    SetPedFleeAttributes(ped, 0, false)
    SetPedSeeingRange(ped, Config.NpcAggroRange)
    SetPedHearingRange(ped, Config.NpcAggroRange)
    SetPedDropsWeaponsWhenDead(ped, false)
    SetPedKeepTask(ped, true)
end

---Attaque si un joueur est à portée, sinon patrouille dans la zone.
---@param ped integer
---@param zone table
function Pve.updateBehaviour(ped, zone)
    if PedUtils.nearestPlayerDistance(GetEntityCoords(ped)) <= Config.NpcAggroRange then
        Pve.wandering[ped] = nil
        TaskCombatHatedTargetsAroundPed(ped, Config.NpcAggroRange, 0)
    elseif not Pve.wandering[ped] then
        Pve.wandering[ped] = true
        TaskWanderInArea(ped, zone.coords.x, zone.coords.y, zone.coords.z, zone.radius * 0.6, 2.0, 5.0)
    end
end
