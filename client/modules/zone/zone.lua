---Blips, détection de la zone courante et restrictions en zone safe.
---@class ZoneModule
local Zone = PVP.define('Zone')
local State = PVP.use('State')
local Nui = PVP.use('Nui')
local Zones = PVP.use('Zones')
local Effects = PVP.use('Effects')

Zone.CHECK_INTERVAL = 500

-- Zone safe : on peut viser (25) mais pas tirer ni frapper
Zone.SAFE_DISABLED_CONTROLS = {
    24, 47, 58, 257, -- tir, détonation, lancer
    140, 141, 142, 143, 263, 264, -- corps à corps
    69, 70, 92, 114, -- tir en véhicule
}

Zone.PASSIVE = 'passive' -- effet du mode passif (Config.Effects)
-- Protection appliquée au personnage (zone safe ou mode passif) : invincible, sans tir
Zone.protected = false

---@type integer[] repères des zones du mode en cours
Zone.blips = {}
---@type string|nil|false mode dont les repères sont affichés (false : pas encore créés)
Zone.blipMode = false

function Zone.init()
    CreateThread(Zone.watchLoop)
    CreateThread(Zone.safeLoop)
end

---Repères des zones du mode en cours (refaits quand on change de mode).
function Zone.refreshBlips()
    for _, blip in ipairs(Zone.blips) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end
    Zone.blips = {}
    Zone.blipMode = State.mode
    for _, zone in ipairs(Config.Zones) do
        if zone.blip and Zones.inMode(zone, State.mode) then
            Zone.createBlip(zone)
        end
    end
end

---@param zone table
function Zone.createBlip(zone)
    local area = AddBlipForRadius(zone.coords.x, zone.coords.y, zone.coords.z, zone.radius)
    SetBlipColour(area, zone.blip.color)
    SetBlipAlpha(area, 90)
    Zone.blips[#Zone.blips + 1] = area

    local blip = AddBlipForCoord(zone.coords.x, zone.coords.y, zone.coords.z)
    SetBlipSprite(blip, zone.blip.sprite)
    SetBlipColour(blip, zone.blip.color)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(zone.label)
    EndTextCommandSetBlipName(blip)
    Zone.blips[#Zone.blips + 1] = blip
end

---Après un respawn le ped est neuf : on force la réapplication de la zone.
function Zone.reset()
    State.zone = false
end

function Zone.watchLoop()
    while true do
        Wait(Zone.CHECK_INTERVAL)
        if State.mode ~= Zone.blipMode then
            Zone.refreshBlips()
            Zone.reset()
        end
        if State.spawned then
            Zone.update()
        end
    end
end

function Zone.update()
    local zone = Zones.getAt(GetEntityCoords(PlayerPedId()), State.mode)
    if zone == State.zone then return end

    local wasSafe = State.isInSafeZone()
    State.zone = zone
    local safe = State.isInSafeZone()
    -- Pas en partie de course ou de CVC : le départ de la partie fait aussi « sortir » de la zone
    -- (ni en mode spectateur : le personnage de l'admin suit le joueur regardé)
    if wasSafe and not safe and State.isAlive() and not State.activity and not State.spectating then
        Effects.start({ id = Zone.PASSIVE, duration = Config.PassiveMode.duration })
    elseif safe then
        Effects.stop(Zone.PASSIVE)
    end
    Zone.applyProtection()
    Nui.send('zone', Zones.toInfo(zone))
    if State.menuOpen then
        Nui.sendMenuState()
    end
end

---@return boolean en zone safe ou en mode passif juste après en être sorti
function Zone.isProtected()
    return State.isInSafeZone() or Effects.isActive(Zone.PASSIVE)
end

function Zone.applyProtection()
    Zone.protected = Zone.isProtected()
    Zone.setSafe(Zone.protected)
end

---@param enabled boolean
function Zone.setSafe(enabled)
    -- Les options admin (invincible, noclip, spectateur) gardent l'invincibilité hors zone safe
    SetEntityInvincible(PlayerPedId(), enabled or State.godmode or State.noclip or State.spectating)
    -- En PvP, jamais de tir en véhicule (voir Vehicles.weaponLoop)
    SetPlayerCanDoDriveBy(PlayerId(), not enabled and not State.inPvp())
end

function Zone.safeLoop()
    while true do
        -- Fin du mode passif : la protection tombe
        if Zone.protected ~= Zone.isProtected() then Zone.applyProtection() end
        if Zone.protected then
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
    Zone.preventCarKill()
end

-- Anti car-kill : distance où les véhicules traversent le joueur à pied
Zone.CAR_KILL_RADIUS = 40.0

---En zone safe, un véhicule ne peut ni écraser ni renverser un joueur à pied :
---les collisions entre lui et les véhicules proches sont coupées (à refaire à chaque image).
function Zone.preventCarKill()
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then return end
    local coords = GetEntityCoords(ped)
    for _, vehicle in ipairs(GetGamePool('CVehicle')) do
        if #(GetEntityCoords(vehicle) - coords) <= Zone.CAR_KILL_RADIUS then
            SetEntityNoCollisionEntity(vehicle, ped, true)
            SetEntityNoCollisionEntity(ped, vehicle, true)
        end
    end
end
