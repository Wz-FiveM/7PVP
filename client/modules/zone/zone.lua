---Blips, détection de la zone courante et restrictions en zone safe.
---@class ZoneModule
local Zone = PVP.define('Zone')
local State = PVP.use('State')
local Nui = PVP.use('Nui')
local Zones = PVP.use('Zones')
local PvpPositions = PVP.use('PvpPositions')
local Effects = PVP.use('Effects')
local Creator = PVP.use('Creator')
local Events = PVP.use('Events')
local Locale = PVP.use('Locale')

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
    -- Noms des repères dans la nouvelle langue (un changement de mode en cours les refera de lui-même)
    AddEventHandler(Events.internal.languageChanged, function()
        if Zone.blipMode == State.mode then Zone.refreshBlips() end
    end)
    -- Zones du PvP déplacées par un admin (voir FreeroamConfigService) : repères et zone du joueur
    -- refaits au prochain passage de Zone.watchLoop
    RegisterNetEvent(Events.client.freeroamSettings, function(name, zones)
        local kind = PvpPositions.ZONE_SETTINGS[name]
        if kind and type(zones) == 'table' then
            PvpPositions.setZones(kind, zones)
            Zone.blipMode = false
        end
    end)
    CreateThread(Zone.watchLoop)
    CreateThread(Zone.safeLoop)
    CreateThread(Zone.pveLoop)
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
    AddTextComponentSubstringPlayerName(Locale.t(zone.label))
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
    -- En PvP et en 1VS1 Bike, jamais de tir en véhicule (voir Vehicles.weaponLoop)
    SetPlayerCanDoDriveBy(PlayerId(), not enabled and not State.noDriveBy())
end

function Zone.safeLoop()
    while true do
        -- Fin du mode passif : la protection tombe
        if Zone.protected ~= Zone.isProtected() then Zone.applyProtection() end
        if Zone.protected then
            Zone.applySafeRestrictions()
            Wait(0)
        else
            Zone.clearStuckInvincibility()
            Wait(250)
        end
    end
end

---Hors zone safe et hors mode passif, en PvP, rien ne doit laisser le personnage invincible : une invincibilité
---restée d'ailleurs (créateur, changement de personnage...) rendait des joueurs intouchables pour les autres.
function Zone.clearStuckInvincibility()
    if not State.inPvp() or not State.isAlive() or State.activity or Creator.active then return end
    if State.godmode or State.noclip or State.spectating then return end
    SetEntityInvincible(PlayerPedId(), false)
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

-- Mode PvP : en dessous de cette vitesse (m/s), un véhicule sans conducteur reste solide
-- (on peut y grimper pour fuir les zombies, s'en servir de couvert)
Zone.CAR_KILL_MIN_SPEED = 1.0

function Zone.pveLoop()
    while true do
        if State.inPvp() or LocalPlayer.state.pveWorld == true then
            Zone.preventPveCarKill()
            Wait(0)
        else
            Wait(250)
        end
    end
end

---Mode PvP (monde PvP et monde zombies) : pas de carkill, un véhicule en marche traverse les joueurs à pied
---(les zombies, eux, se font toujours écraser). Le choc ne passe pas par le serveur, c'est le client de la
---victime qui l'encaisse. Réglé aussi pour les autres joueurs : sans ça, le conducteur bute sur une cible
---qui ne bouge pas chez elle.
function Zone.preventPveCarKill()
    local peds = {}
    for _, player in ipairs(GetActivePlayers()) do
        local ped = GetPlayerPed(player)
        if not IsPedInAnyVehicle(ped, false) then peds[#peds + 1] = ped end
    end
    for _, vehicle in ipairs(GetGamePool('CVehicle')) do
        if GetEntitySpeed(vehicle) >= Zone.CAR_KILL_MIN_SPEED or IsPedAPlayer(GetPedInVehicleSeat(vehicle, -1)) then
            local coords = GetEntityCoords(vehicle)
            for _, ped in ipairs(peds) do
                if #(GetEntityCoords(ped) - coords) <= Zone.CAR_KILL_RADIUS then
                    SetEntityNoCollisionEntity(vehicle, ped, true)
                    SetEntityNoCollisionEntity(ped, vehicle, true)
                end
            end
        end
    end
end
