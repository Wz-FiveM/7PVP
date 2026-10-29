---Monde zombies (Config.PveWorld) : un joueur PvP qui entre dans une zone PvE passe dans un
---bucket de routage à part, partagé avec les autres joueurs qui farment, sans PvP. Il revient
---au monde PvP en sortant de la zone (avec une marge, pour ne pas basculer sans arrêt au bord).
---Les zombies sont créés dans ce bucket (PveZone.spawnNpc) ; un véhicule change de monde avec
---ceux qui sont à bord. Le client sait où il est par le state bag `pveWorld` du joueur.
---@class PveWorldServiceModule
local PveWorldService = PVP.define('PveWorldService')
local PlayerService = PVP.use('PlayerService')
local ModeRegistry = PVP.use('ModeRegistry')
local WorldService = PVP.use('WorldService')
local SpectateService = PVP.use('SpectateService')
local AntiCheatService = PVP.use('AntiCheatService')
local Zones = PVP.use('Zones')
local Events = PVP.use('Events')

PveWorldService.CHECK_INTERVAL = 500
PveWorldService.STATE = 'pveWorld'
PveWorldService.MODE = 'pvp'

---@type table<integer, boolean> joueurs dans le monde zombies
PveWorldService.inside = {}

function PveWorldService.init()
    WorldService.setupBucket(Config.PveWorld.bucket)

    -- Pas de PvP dans le monde zombies : la touche est annulée avant d'être appliquée
    AddEventHandler('weaponDamageEvent', function(sender, data)
        PveWorldService.onWeaponDamage(sender, data)
    end)
    AddEventHandler(Events.internal.playerUnloading, function(playerSource)
        PveWorldService.inside[playerSource] = nil
    end)

    CreateThread(PveWorldService.loop)
end

---@param source integer
---@return boolean
function PveWorldService.isInside(source)
    return PveWorldService.inside[source] == true
end

---@return integer bucket du monde PvP
function PveWorldService.pvpBucket()
    local config = ModeRegistry.getConfig(PveWorldService.MODE)
    return config and config.bucket or 0
end

---@param coords vector3
---@param margin number ajoutée au rayon des zones
---@return boolean dans une zone PvE du mode PvP
function PveWorldService.isInZone(coords, margin)
    for _, zone in ipairs(Zones.byType('pve', PveWorldService.MODE)) do
        if #(coords.xy - zone.coords.xy) <= zone.radius + margin then return true end
    end
    return false
end

function PveWorldService.loop()
    while true do
        Wait(PveWorldService.CHECK_INTERVAL)
        PveWorldService.check()
    end
end

function PveWorldService.check()
    local inMode = {}
    for _, source in ipairs(ModeRegistry.getPlayers(PveWorldService.MODE)) do
        inMode[source] = true
        local player = PlayerService.get(source)
        -- Mort : il reste où il est tombé (son sac aussi) ; la réapparition en zone safe le ramène.
        -- Admin en mode spectateur : son bucket suit le joueur regardé.
        if player and not player.dead and not SpectateService.isWatching(source) then
            local inside = PveWorldService.isInside(source)
            local wanted = PveWorldService.isInZone(player:getCoords(), inside and Config.PveWorld.exitMargin or 0.0)
            if wanted ~= inside then PveWorldService.move(source, wanted) end
        end
    end

    -- Parti du mode PvP (lobby) : son nouveau bucket a déjà été choisi, on oublie seulement l'état
    for source in pairs(PveWorldService.inside) do
        if not inMode[source] then PveWorldService.setInside(source, false) end
    end
end

---Change de monde le joueur, et avec lui son véhicule et tous les joueurs à bord.
---@param source integer
---@param inside boolean
function PveWorldService.move(source, inside)
    local bucket = inside and Config.PveWorld.bucket or PveWorldService.pvpBucket()
    local vehicle = GetVehiclePedIsIn(GetPlayerPed(source), false)
    local riders = { source }
    if vehicle ~= 0 then
        for _, rider in ipairs(PveWorldService.playersIn(vehicle)) do
            if rider ~= source then riders[#riders + 1] = rider end
        end
    end

    for _, rider in ipairs(riders) do
        if PveWorldService.isInside(rider) ~= inside then
            AntiCheatService.grace(rider)
            SetPlayerRoutingBucket(rider, bucket)
            PveWorldService.setInside(rider, inside)
            TriggerClientEvent(Events.client.notify, rider, inside
                and 'Monde zombies : pas de PvP, tu ne croises que les joueurs qui farment.'
                or 'Retour dans le monde PvP.', 'info')
        end
    end
    if vehicle ~= 0 then SetEntityRoutingBucket(vehicle, bucket) end
end

---@param source integer
---@param inside boolean
function PveWorldService.setInside(source, inside)
    PveWorldService.inside[source] = inside or nil
    Player(source).state:set(PveWorldService.STATE, inside, true)
end

---@param vehicle integer
---@return integer[] joueurs à bord (conducteur compris)
function PveWorldService.playersIn(vehicle)
    local riders = {}
    for seat = -1, 6 do
        local ped = GetPedInVehicleSeat(vehicle, seat)
        local owner = ped ~= 0 and NetworkGetEntityOwner(ped) or 0
        if owner ~= 0 and GetPlayerPed(owner) == ped and PlayerService.get(owner) then riders[#riders + 1] = owner end
    end
    return riders
end

---@param sender integer
---@param data table
function PveWorldService.onWeaponDamage(sender, data)
    if not PveWorldService.isInside(sender) or type(data) ~= 'table' then return end

    local ids = data.hitGlobalIds or { data.hitGlobalId }
    for _, netId in ipairs(ids) do
        local ped = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
        if ped ~= 0 and DoesEntityExist(ped) then
            local owner = NetworkGetEntityOwner(ped)
            if PlayerService.get(owner) and GetPlayerPed(owner) == ped then
                CancelEvent()
                return
            end
        end
    end
end
