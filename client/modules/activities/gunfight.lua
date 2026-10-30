---Duels 1VS1 côté client, GunFight (à pied) et Bike (à moto) (server/modules/activities/gunfight_service.lua) :
---placement au départ, moto, pistolet, limite de la zone de combat, caméra sur l'adversaire après la
---mort, HUD. Le serveur décide des vivants et de la fin des manches ; il bloque aussi les tirs hors manche.
---@class GunfightModule
local Gunfight = PVP.define('Gunfight')
local State = PVP.use('State')
local Nui = PVP.use('Nui')
local PedUtils = PVP.use('PedUtils')
local Death = PVP.use('Death')
local Freeroam = PVP.use('Freeroam')
local Events = PVP.use('Events')
local Zone = PVP.use('Zone')

Gunfight.FADE = 400
Gunfight.PLATE = '1VS1'
-- Pendant le compte à rebours : pas de déplacement ni de tir, à pied comme à moto
Gunfight.LOCKED_CONTROLS = {
    21, 22, 24, 25, 30, 31, 32, 33, 34, 35, 44, 140, 141, 142, 257,
    59, 60, 63, 64, 68, 69, 70, 71, 72, 75, 76, 92, 106,
}

---@type string|nil mode du duel en cours ('gunfight' ou 'bike', clé de Config.FreeroamActivities)
Gunfight.activity = nil
---@type table|nil manche en cours (données envoyées par le serveur)
Gunfight.round = nil
---@type integer|nil moto de la manche (1VS1 Bike)
Gunfight.vehicle = nil
Gunfight.lockedUntil = 0
Gunfight.arenaBlip = nil
Gunfight.outside = false
Gunfight.nextOutsideDamage = 0

function Gunfight.init()
    RegisterNetEvent(Events.client.gunfightQueue, function(data)
        Nui.send('gunfightQueue', data or { count = 0 })
    end)
    RegisterNetEvent(Events.client.gunfightRound, function(data)
        CreateThread(function()
            Gunfight.startRound(data)
        end)
    end)
    RegisterNetEvent(Events.client.gunfightState, function(data)
        if Gunfight.isActive() then Nui.send('gunfightState', data) end
    end)
    RegisterNetEvent(Events.client.gunfightRoundEnd, function(data)
        Nui.send('gunfightBanner', data)
    end)
    RegisterNetEvent(Events.client.gunfightEnd, function(data)
        CreateThread(function()
            Gunfight.finish(data)
        end)
    end)
    CreateThread(Gunfight.loop)
end

---@return boolean un 1VS1 est en cours pour ce joueur
function Gunfight.isActive()
    return Gunfight.activity ~= nil and State.activity == Gunfight.activity
end

-- ---------------------------------------------------------------------------
-- Manche
-- ---------------------------------------------------------------------------

---@param data table activity, round, opponent, opponentId, spawn, vehicle, arena, kit, countdown, ...
function Gunfight.startRound(data)
    Gunfight.activity = data.activity
    State.activity = data.activity
    -- 1VS1 Bike : drive-by coupé (State.noDriveBy)
    Zone.applyProtection()
    Gunfight.round = data
    Gunfight.lockedUntil = GetGameTimer() + data.countdown * 1000
    Nui.send('gunfightHud', {
        open = true,
        round = data.round,
        opponent = data.opponent,
        countdown = data.countdown,
        roundTime = data.roundTime,
        roundsToWin = data.roundsToWin,
        scores = data.scores,
    })

    DoScreenFadeOut(Gunfight.FADE)
    while not IsScreenFadedOut() do Wait(0) end
    Freeroam.setMenu(false)
    Freeroam.deleteVehicle()

    local spawn = data.spawn
    Death.stopSpectate()
    if State.dead or IsEntityDead(PlayerPedId()) then
        NetworkResurrectLocalPlayer(spawn.x, spawn.y, spawn.z, spawn.w, true, false)
        State.dead = false
    end
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then ClearPedTasksImmediately(ped) end
    RequestCollisionAtCoord(spawn.x, spawn.y, spawn.z)
    SetEntityCoordsNoOffset(ped, spawn.x, spawn.y, spawn.z, false, false, false)
    local timeout = GetGameTimer() + 5000
    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < timeout do Wait(0) end
    local ground = PedUtils.findGroundZ(spawn.x, spawn.y, spawn.z)
    SetEntityCoordsNoOffset(ped, spawn.x, spawn.y, ground, false, false, false)
    SetEntityHeading(ped, spawn.w)
    ClearPedBloodDamage(ped)

    Gunfight.giveKit(ped, data.kit)
    Gunfight.deleteVehicle()
    if data.vehicle then Gunfight.createVehicle(data.vehicle, spawn, ground) end
    Gunfight.drawArena(data.arena)
    DoScreenFadeIn(Gunfight.FADE)
end

---1VS1 Bike : moto de la manche, le joueur dessus.
---@param model string
---@param spawn vector4
---@param ground number
function Gunfight.createVehicle(model, spawn, ground)
    local hash = GetHashKey(model)
    if not PedUtils.loadModel(hash) then return end
    local vehicle = CreateVehicle(hash, spawn.x, spawn.y, ground + 0.5, spawn.w, true, false)
    SetModelAsNoLongerNeeded(hash)
    if vehicle == 0 then return end

    SetEntityAsMissionEntity(vehicle, true, true)
    SetVehicleOnGroundProperly(vehicle)
    SetVehicleNumberPlateText(vehicle, Gunfight.PLATE)
    SetVehRadioStation(vehicle, 'OFF')
    SetVehicleEngineOn(vehicle, true, true, false)
    SetPedIntoVehicle(PlayerPedId(), vehicle, -1)
    Gunfight.vehicle = vehicle
end

function Gunfight.deleteVehicle()
    if Gunfight.vehicle and DoesEntityExist(Gunfight.vehicle) then
        SetEntityAsMissionEntity(Gunfight.vehicle, true, true)
        DeleteVehicle(Gunfight.vehicle)
    end
    Gunfight.vehicle = nil
end

---@param ped integer
---@param kit table { weapons, armor }
function Gunfight.giveKit(ped, kit)
    RemoveAllPedWeapons(ped, true)
    SetPedInfiniteAmmoClip(ped, false)
    for _, entry in ipairs(kit.weapons) do
        local hash = GetHashKey(entry.weapon)
        GiveWeaponToPed(ped, hash, entry.ammo, false, true)
        -- Les armes du Freeroam ont des munitions infinies : pas en 1VS1
        SetPedInfiniteAmmo(ped, false, hash)
        SetPedAmmo(ped, hash, entry.ammo)
    end
    SetEntityHealth(ped, GetEntityMaxHealth(ped))
    SetPedArmour(ped, kit.armor or 0)
end

---@param arena { center: vector3, radius: number }
function Gunfight.drawArena(arena)
    if Gunfight.arenaBlip and DoesBlipExist(Gunfight.arenaBlip) then RemoveBlip(Gunfight.arenaBlip) end
    Gunfight.arenaBlip = AddBlipForRadius(arena.center.x, arena.center.y, arena.center.z, arena.radius)
    SetBlipColour(Gunfight.arenaBlip, 1)
    SetBlipAlpha(Gunfight.arenaBlip, 80)
end

---Compte à rebours (commandes bloquées) et dégâts hors de la zone de combat.
function Gunfight.loop()
    while true do
        if Gunfight.isActive() and Gunfight.round then
            local now = GetGameTimer()
            if now < Gunfight.lockedUntil then
                for _, control in ipairs(Gunfight.LOCKED_CONTROLS) do DisableControlAction(0, control, true) end
            end
            Gunfight.checkArena(now)
            Wait(0)
        else
            Wait(500)
        end
    end
end

---@param now integer
function Gunfight.checkArena(now)
    if State.dead then return end
    local ped = PlayerPedId()
    local arena = Gunfight.round.arena
    local outside = #(GetEntityCoords(ped).xy - arena.center.xy) > arena.radius
    if outside ~= Gunfight.outside then
        Gunfight.outside = outside
        Nui.send('gunfightOutside', { outside = outside })
    end
    if outside and now >= Gunfight.nextOutsideDamage then
        Gunfight.nextOutsideDamage = now + 1000
        ApplyDamageToPed(ped, Gunfight.round.outsideDamage, false)
    end
end

---Appelé à la mort (Freeroam.onDeath) : pas de réapparition avant la manche suivante.
function Gunfight.onDeath()
    State.dead = true
    if Gunfight.outside then
        Gunfight.outside = false
        Nui.send('gunfightOutside', { outside = false })
    end
    if Gunfight.round then Death.spectate(Gunfight.round.opponentId) end
end

-- ---------------------------------------------------------------------------
-- Fin
-- ---------------------------------------------------------------------------

---Fin de la partie : retour à la zone safe du Freeroam.
---@param data { result: string, reason: string|nil, scores: table, spawn: vector4|nil }
function Gunfight.finish(data)
    Nui.send('gunfightHud', { open = false })
    Nui.send('gunfightEnd', { result = data.result, reason = data.reason, scores = data.scores, elo = data.elo })

    DoScreenFadeOut(Gunfight.FADE)
    while not IsScreenFadedOut() do Wait(0) end
    Death.stopSpectate()
    local spawn = data.spawn
    if spawn and (State.dead or IsEntityDead(PlayerPedId())) then
        NetworkResurrectLocalPlayer(spawn.x, spawn.y, spawn.z, spawn.w, true, false)
        State.dead = false
    end
    -- 1VS1 Bike : on descend de la moto avant qu'elle soit supprimée
    if IsPedInAnyVehicle(PlayerPedId(), false) then ClearPedTasksImmediately(PlayerPedId()) end
    Gunfight.cleanup()
    local ped = PlayerPedId()
    SetEntityHealth(ped, GetEntityMaxHealth(ped))
    SetPedArmour(ped, 0)
    ClearPedBloodDamage(ped)
    RemoveAllPedWeapons(ped, true)
    Freeroam.restoreWeapons()
    if spawn then
        RequestCollisionAtCoord(spawn.x, spawn.y, spawn.z)
        SetEntityCoordsNoOffset(ped, spawn.x, spawn.y, PedUtils.findGroundZ(spawn.x, spawn.y, spawn.z), false, false, false)
        SetEntityHeading(ped, spawn.w)
    end
    DoScreenFadeIn(Gunfight.FADE)
end

function Gunfight.cleanup()
    Gunfight.deleteVehicle()
    if Gunfight.arenaBlip and DoesBlipExist(Gunfight.arenaBlip) then RemoveBlip(Gunfight.arenaBlip) end
    Gunfight.arenaBlip = nil
    Gunfight.round = nil
    Gunfight.outside = false
    local wasActive = Gunfight.isActive()
    if wasActive then State.activity = nil end
    Gunfight.activity = nil
    if wasActive then Zone.applyProtection() end
end
