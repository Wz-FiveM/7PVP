---@class PveServiceModule
local PveService = PVP.define('PveService')
local PveZone = PVP.use('PveZone')
local PlayerService = PVP.use('PlayerService')
local CombatService = PVP.use('CombatService')
local Zones = PVP.use('Zones')
local ModeRegistry = PVP.use('ModeRegistry')
local Events = PVP.use('Events')

PveService.TICK_INTERVAL = 1500
-- Les positions vues par le serveur ont un léger retard sur celles du client
PveService.ATTACK_RANGE_TOLERANCE = 2.0
PveService.ATTACK_COOLDOWN_TOLERANCE = 300
-- Les joueurs à cette distance voient le vomi (les particules sont locales à chaque client)
PveService.VOMIT_BROADCAST_RANGE = 120.0

---@type table<string, PveZone>
PveService.zones = {}
---@type table<integer, integer> dernier vomissement validé par zombie (GetGameTimer)
PveService.lastAttack = {}

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

    -- Envoyé par le client propriétaire du zombie quand il vomit sur un joueur
    RegisterNetEvent(Events.server.zombieAttack, function(netId, targetId)
        PveService.onZombieAttack(source, netId, targetId)
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
        PveService.pruneAttacks()
    end
end

function PveService.pruneAttacks()
    for ped in pairs(PveService.lastAttack) do
        if not DoesEntityExist(ped) then PveService.lastAttack[ped] = nil end
    end
end

---Vérifie l'attaque d'un zombie (propriétaire, portée, délai) puis la diffuse aux joueurs proches :
---la cible subit les dégâts, tous voient le vomi.
---@param source integer
---@param netId any
---@param targetId any
function PveService.onZombieAttack(source, netId, targetId)
    netId = tonumber(netId)
    local ped = netId and NetworkGetEntityFromNetworkId(netId) or 0
    if ped == 0 or not DoesEntityExist(ped) or GetEntityHealth(ped) <= 0 then return end
    if not PveService.getZoneOf(ped) or NetworkGetEntityOwner(ped) ~= source then return end

    local target = PlayerService.get(targetId)
    if not target or target.dead or target.mode ~= 'pvp' then return end

    local zombieType = Config.ZombieTypes[Entity(ped).state.zombieType] or Config.ZombieTypes.walker
    local range = zombieType.range or Config.Zombie.attackRange
    local coords = GetEntityCoords(ped)
    if #(target:getCoords() - coords) > range + PveService.ATTACK_RANGE_TOLERANCE then return end

    local now = GetGameTimer()
    local cooldown = (zombieType.cooldown or Config.Zombie.attackCooldown) - PveService.ATTACK_COOLDOWN_TOLERANCE
    if now - (PveService.lastAttack[ped] or 0) < cooldown then return end
    PveService.lastAttack[ped] = now

    local damage = math.floor(Config.Zombie.damage * zombieType.damage + 0.5)
    for _, id in ipairs(ModeRegistry.getPlayers('pvp')) do
        if #(GetEntityCoords(GetPlayerPed(id)) - coords) <= PveService.VOMIT_BROADCAST_RANGE then
            TriggerClientEvent(Events.client.zombieVomit, id, netId, target.source, damage)
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
