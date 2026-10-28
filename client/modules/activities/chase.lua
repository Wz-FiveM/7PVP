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
---@type table|nil manche en cours (données du serveur : rôle, adversaire, règles...)
Chase.round = nil
-- GetGameTimer() du départ (fin du compte à rebours)
Chase.runningAt = 0
---@type { at: integer, heading: number }|nil choc avec l'adversaire en cours d'examen (anti-PIT)
Chase.contact = nil
Chase.airSince = nil
Chase.stuntReported = false

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
    RegisterNetEvent(Events.client.chaseRepair, function()
        Chase.repair()
    end)
    RegisterNetEvent(Events.client.chaseEnd, function(data)
        CreateThread(function()
            Chase.finish(data)
        end)
    end)

    CreateThread(Chase.monitorLoop)

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
    Chase.round = data
    Chase.runningAt = GetGameTimer() + data.countdown * 1000
    Chase.contact = nil
    Chase.airSince = nil
    Chase.stuntReported = false
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

---État envoyé par le serveur : temps, immobilisation, santé de son véhicule et avertissements.
---@param data { remaining: integer, arrest: number, health: integer|nil, warns: integer, maxWarns: integer }
function Chase.onState(data)
    if not Chase.isActive() then return end
    Nui.send('chaseState', data)
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
    Chase.round = nil
    State.activity = nil
end

-- ---------------------------------------------------------------------------
-- Règles de conduite (signalées au serveur, qui vérifie et tranche)
-- ---------------------------------------------------------------------------

function Chase.monitorLoop()
    while true do
        local vehicle = Chase.vehicle
        if Chase.isActive() and Chase.round and vehicle and DoesEntityExist(vehicle) and GetGameTimer() >= Chase.runningAt then
            Chase.checkPit(vehicle)
            Chase.checkStunt(vehicle)
            Wait(0)
        else
            Wait(250)
        end
    end
end

---@return integer véhicule de l'adversaire (0 s'il n'est pas chargé ou à pied)
function Chase.opponentVehicle()
    local player = GetPlayerFromServerId(Chase.round.opponentId)
    if player == -1 then return 0 end
    return GetVehiclePedIsIn(GetPlayerPed(player), false)
end

---Anti-PIT, côté victime : un choc de l'adversaire par l'arrière ou le côté, à bonne vitesse,
---suivi d'une rotation brutale de son propre véhicule. Le serveur vérifie avant de sanctionner.
---@param vehicle integer
function Chase.checkPit(vehicle)
    local rules = Chase.round.rules.pit
    local now = GetGameTimer()
    if not Chase.contact then
        local other = Chase.opponentVehicle()
        if other == 0 or not IsEntityTouchingEntity(vehicle, other) then return end
        if GetEntitySpeed(vehicle) * 3.6 < rules.minSpeed then return end
        -- Adversaire devant soi : c'est nous qui le percutons, pas un PIT subi
        local relative = GetOffsetFromEntityGivenWorldCoords(vehicle, GetEntityCoords(other))
        if relative.y > 1.0 then return end
        Chase.contact = { at = now, heading = GetEntityHeading(vehicle) }
        return
    end

    if now - Chase.contact.at > rules.window * 1000 then
        Chase.contact = nil
        return
    end
    local turned = math.abs((GetEntityHeading(vehicle) - Chase.contact.heading + 540.0) % 360.0 - 180.0)
    if turned >= rules.turnAngle then
        Chase.contact = nil
        TriggerServerEvent(Events.server.chaseReport, 'pit')
    end
end

---Anti-stunt : un saut trop haut ou trop long est signalé (le joueur perd la manche).
---@param vehicle integer
function Chase.checkStunt(vehicle)
    if not IsEntityInAir(vehicle) then
        Chase.airSince = nil
        return
    end
    local rules = Chase.round.rules.stunt
    local now = GetGameTimer()
    Chase.airSince = Chase.airSince or now
    if Chase.stuntReported then return end
    if GetEntityHeightAboveGround(vehicle) > rules.maxHeight or now - Chase.airSince > rules.maxAirTime * 1000 then
        Chase.stuntReported = true
        TriggerServerEvent(Events.server.chaseReport, 'stunt')
    end
end

---PIT subi (confirmé par le serveur) : le véhicule récupère toute sa vie.
function Chase.repair()
    local vehicle = Chase.vehicle
    if not vehicle or not DoesEntityExist(vehicle) then return end
    SetVehicleFixed(vehicle)
    SetVehicleDeformationFixed(vehicle)
    SetVehicleEngineHealth(vehicle, 1000.0)
    SetVehicleBodyHealth(vehicle, 1000.0)
    SetVehiclePetrolTankHealth(vehicle, 1000.0)
end
