---Course poursuite côté client (server/modules/activities/chase_service.lua) : vote du véhicule,
---placement au départ de chaque manche et HUD (sans repère ni distance de l'adversaire). Les règles (distance,
---immobilisation, temps) sont vérifiées par le serveur, qui envoie l'état à afficher.
---@class ChaseModule
local Chase = PVP.define('Chase')
local State = PVP.use('State')
local Nui = PVP.use('Nui')
local PedUtils = PVP.use('PedUtils')
local Callback = PVP.use('Callback')
local Events = PVP.use('Events')

Chase.ACTIVITY = 'chase'
Chase.FADE = 400

---@type integer|nil véhicule de la manche en cours
Chase.vehicle = nil
Chase.voting = false

function Chase.init()
    RegisterNetEvent(Events.client.chaseQueue, function(data)
        Nui.send('chaseQueue', data or { count = 0 })
    end)
    RegisterNetEvent(Events.client.chaseVote, function(data)
        Chase.openVote(data)
    end)
    RegisterNetEvent(Events.client.chaseRound, function(data)
        CreateThread(function()
            Chase.startRound(data)
        end)
    end)
    RegisterNetEvent(Events.client.chaseState, function(data)
        Chase.onState(data)
    end)
    RegisterNetEvent(Events.client.chaseRoundEnd, function(data)
        Nui.send('chaseBanner', data)
    end)
    RegisterNetEvent(Events.client.chaseEnd, function(data)
        CreateThread(function()
            Chase.finish(data)
        end)
    end)

    RegisterNUICallback('chaseVote', function(data, cb)
        local result = Callback.await(Events.callbacks.chaseVote, type(data) == 'table' and data.model or nil) or { ok = false }
        if result.ok then Chase.closeVote() end
        if result.message then Nui.notify(result.message, result.ok and 'success' or 'error') end
        cb(result)
    end)
end

---@return boolean une course est en cours pour ce joueur
function Chase.isActive()
    return State.activity == Chase.ACTIVITY
end

-- ---------------------------------------------------------------------------
-- Vote
-- ---------------------------------------------------------------------------

---@param data { vehicles: table[], seconds: integer, opponent: string }
function Chase.openVote(data)
    State.activity = Chase.ACTIVITY
    Chase.voting = true
    SetNuiFocus(true, true)
    Nui.send('chaseVote', { open = true, vehicles = data.vehicles, seconds = data.seconds, opponent = data.opponent })
end

function Chase.closeVote()
    if not Chase.voting then return end
    Chase.voting = false
    SetNuiFocus(false, false)
    Nui.send('chaseVote', { open = false })
end

-- ---------------------------------------------------------------------------
-- Manches
-- ---------------------------------------------------------------------------

---@param data table round, role, model, spawn, countdown, roundTime, escapeDistance, arrestTime, scores, opponent
function Chase.startRound(data)
    Chase.closeVote()
    State.activity = Chase.ACTIVITY
    Nui.send('chaseHud', {
        open = true,
        round = data.round,
        role = data.role,
        scores = data.scores,
        opponent = data.opponent,
        countdown = data.countdown,
        roundTime = data.roundTime,
        escapeDistance = data.escapeDistance,
        arrestTime = data.arrestTime,
    })

    DoScreenFadeOut(Chase.FADE)
    while not IsScreenFadedOut() do Wait(0) end
    Chase.deleteVehicle()

    local spawn = data.spawn
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then ClearPedTasksImmediately(ped) end
    RequestCollisionAtCoord(spawn.x, spawn.y, spawn.z)
    SetEntityCoordsNoOffset(ped, spawn.x, spawn.y, spawn.z, false, false, false)
    local timeout = GetGameTimer() + 5000
    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < timeout do Wait(0) end
    local ground = PedUtils.findGroundZ(spawn.x, spawn.y, spawn.z)

    local hash = GetHashKey(data.model)
    if PedUtils.loadModel(hash) then
        local vehicle = CreateVehicle(hash, spawn.x, spawn.y, ground + 0.5, spawn.w, true, false)
        SetModelAsNoLongerNeeded(hash)
        if vehicle ~= 0 then
            SetEntityAsMissionEntity(vehicle, true, true)
            SetVehicleOnGroundProperly(vehicle)
            SetVehicleNumberPlateText(vehicle, data.role == 'cop' and 'POLICE' or 'VOLEUR')
            SetVehRadioStation(vehicle, 'OFF')
            SetPedIntoVehicle(ped, vehicle, -1)
            FreezeEntityPosition(vehicle, true)
            Chase.vehicle = vehicle
        end
    end
    DoScreenFadeIn(Chase.FADE)

    -- Départ quand le compte à rebours du serveur est fini
    Wait(data.countdown * 1000)
    if Chase.vehicle and DoesEntityExist(Chase.vehicle) then FreezeEntityPosition(Chase.vehicle, false) end
end

---État envoyé par le serveur : temps restant et immobilisation du voleur.
---@param data { remaining: integer, arrest: number }
function Chase.onState(data)
    if not Chase.isActive() then return end
    Nui.send('chaseState', { remaining = data.remaining, arrest = data.arrest })
end

---Fin de la partie : retour à la zone safe du Freeroam.
---@param data { result: string, reason: string|nil, scores: table, spawn: vector4|nil }
function Chase.finish(data)
    Chase.closeVote()
    Nui.send('chaseHud', { open = false })
    Nui.send('chaseEnd', { result = data.result, reason = data.reason, scores = data.scores })

    DoScreenFadeOut(Chase.FADE)
    while not IsScreenFadedOut() do Wait(0) end
    Chase.cleanup()
    local spawn = data.spawn
    if spawn then
        local ped = PlayerPedId()
        if IsPedInAnyVehicle(ped, false) then ClearPedTasksImmediately(ped) end
        RequestCollisionAtCoord(spawn.x, spawn.y, spawn.z)
        SetEntityCoordsNoOffset(ped, spawn.x, spawn.y, PedUtils.findGroundZ(spawn.x, spawn.y, spawn.z), false, false, false)
        SetEntityHeading(ped, spawn.w)
    end
    DoScreenFadeIn(Chase.FADE)
end

function Chase.deleteVehicle()
    if Chase.vehicle and DoesEntityExist(Chase.vehicle) then
        SetEntityAsMissionEntity(Chase.vehicle, true, true)
        DeleteVehicle(Chase.vehicle)
    end
    Chase.vehicle = nil
end

function Chase.cleanup()
    Chase.deleteVehicle()
    State.activity = nil
end
