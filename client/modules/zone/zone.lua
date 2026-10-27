---Blips, détection de la zone courante et restrictions en zone safe.
---@class ZoneModule
local Zone = PVP.define('Zone')
local State = PVP.use('State')
local Nui = PVP.use('Nui')
local Zones = PVP.use('Zones')

Zone.CHECK_INTERVAL = 500

Zone.SAFE_DISABLED_CONTROLS = {
    24, 25, 47, 58, -- tir, visée, armes
    140, 141, 142, 143, 257, 263, 264, -- corps à corps
    69, 70, 92, 114, -- tir en véhicule
}

function Zone.init()
    Zone.createBlips()
    CreateThread(Zone.watchLoop)
    CreateThread(Zone.safeLoop)
end

function Zone.createBlips()
    for _, zone in ipairs(Config.Zones) do
        if zone.blip then
            Zone.createBlip(zone)
        end
    end
end

---@param zone table
function Zone.createBlip(zone)
    local area = AddBlipForRadius(zone.coords.x, zone.coords.y, zone.coords.z, zone.radius)
    SetBlipColour(area, zone.blip.color)
    SetBlipAlpha(area, 90)

    local blip = AddBlipForCoord(zone.coords.x, zone.coords.y, zone.coords.z)
    SetBlipSprite(blip, zone.blip.sprite)
    SetBlipColour(blip, zone.blip.color)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(zone.label)
    EndTextCommandSetBlipName(blip)
end

---Après un respawn le ped est neuf : on force la réapplication de la zone.
function Zone.reset()
    State.zone = false
end

function Zone.watchLoop()
    while true do
        Wait(Zone.CHECK_INTERVAL)
        if State.spawned then
            Zone.update()
        end
    end
end

function Zone.update()
    local zone = Zones.getAt(GetEntityCoords(PlayerPedId()))
    if zone == State.zone then return end

    State.zone = zone
    Zone.setSafe(State.isInSafeZone())
    Nui.send('zone', Zones.toInfo(zone))
    if State.menuOpen then
        Nui.sendMenuState()
    end
end

---@param enabled boolean
function Zone.setSafe(enabled)
    SetEntityInvincible(PlayerPedId(), enabled)
    SetPlayerCanDoDriveBy(PlayerId(), not enabled)
end

function Zone.safeLoop()
    while true do
        if State.isInSafeZone() then
            Zone.applySafeRestrictions()
            Wait(0)
        else
            Wait(250)
        end
    end
end

function Zone.applySafeRestrictions()
    DisablePlayerFiring(PlayerId(), true)
    for _, control in ipairs(Zone.SAFE_DISABLED_CONTROLS) do
        DisableControlAction(0, control, true)
    end
end
