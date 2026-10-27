---@class PveServiceModule
local PveService = PVP.define('PveService')
local PveZone = PVP.use('PveZone')
local PlayerService = PVP.use('PlayerService')
local CombatService = PVP.use('CombatService')
local Zones = PVP.use('Zones')
local Events = PVP.use('Events')

PveService.TICK_INTERVAL = 1500

---@type table<string, PveZone>
PveService.zones = {}

function PveService.init()
    for _, zone in ipairs(Zones.byType('pve')) do
        if zone.npc then
            PveService.zones[zone.id] = PveZone.new(zone)
        end
    end

    -- Envoyé par le client propriétaire du PNJ (ou par son tueur)
    RegisterNetEvent(Events.server.npcDied, function(netId, killerId)
        PveService.onNpcDied(source, netId, killerId)
    end)

    AddEventHandler('onResourceStop', function(resource)
        if resource == GetCurrentResourceName() then
            PveService.despawnAll()
        end
    end)

    CreateThread(PveService.loop)
end

function PveService.loop()
    while true do
        Wait(PveService.TICK_INTERVAL)
        local now = GetGameTimer()
        for _, zone in pairs(PveService.zones) do
            zone:tick(now)
        end
    end
end

function PveService.despawnAll()
    for _, zone in pairs(PveService.zones) do
        zone:despawnAll()
    end
end

---@param ped integer
---@return PveZone|nil
function PveService.getZoneOf(ped)
    return PveService.zones[Entity(ped).state.pvpNpc]
end

---@param source integer
---@param netId integer
---@param killerId any
function PveService.onNpcDied(source, netId, killerId)
    local ped = NetworkGetEntityFromNetworkId(netId)
    if ped == 0 or not DoesEntityExist(ped) then return end

    local zone = PveService.getZoneOf(ped)
    if not zone then return end

    killerId = tonumber(killerId)
    if NetworkGetEntityOwner(ped) ~= source and killerId ~= source then return end

    local killer = killerId and PlayerService.get(killerId)
    if killer and not CombatService.isWithinKillRange(killer:getCoords(), GetEntityCoords(ped)) then
        killer = nil
    end

    zone:onNpcDeath(ped, killer or nil)
end
