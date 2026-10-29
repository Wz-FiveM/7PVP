---CVC côté client (server/modules/activities/cvc_service.lua) : placement dans le convoi, kit,
---limite de la zone de combat, repères des coéquipiers, spectateur après la mort, HUD.
---Le serveur décide des vivants et de la fin des manches ; il bloque aussi les tirs alliés.
---@class CvcModule
local Cvc = PVP.define('Cvc')
local State = PVP.use('State')
local Nui = PVP.use('Nui')
local PedUtils = PVP.use('PedUtils')
local Death = PVP.use('Death')
local Freeroam = PVP.use('Freeroam')
local Events = PVP.use('Events')

Cvc.ACTIVITY = 'cvc'
Cvc.FADE = 400
Cvc.VEHICLE_WAIT = 8000
-- Pendant le compte à rebours : pas de déplacement, pas de conduite, pas de tir
Cvc.LOCKED_CONTROLS = { 24, 25, 30, 31, 32, 33, 34, 35, 71, 72, 75, 257 }

---@type table|nil manche en cours (données envoyées par le serveur)
Cvc.round = nil
---@type integer|nil véhicule créé par ce joueur (conducteur)
Cvc.vehicle = nil
Cvc.pendingSeat = 0
Cvc.lockedUntil = 0
Cvc.arenaBlip = nil
---@type table<integer, integer> coéquipier -> repère
Cvc.mateBlips = {}
---@type table[] derniers coéquipiers reçus
Cvc.mates = {}
Cvc.outside = false
Cvc.nextOutsideDamage = 0

function Cvc.init()
    RegisterNetEvent(Events.client.cvcQueue, function(data)
        Nui.send('cvcQueue', data or { count = 0 })
    end)
    RegisterNetEvent(Events.client.cvcRound, function(data)
        CreateThread(function()
            Cvc.startRound(data)
        end)
    end)
    RegisterNetEvent(Events.client.cvcVehicle, function(netId)
        CreateThread(function()
            Cvc.boardVehicle(netId)
        end)
    end)
    RegisterNetEvent(Events.client.cvcState, function(data)
        Cvc.onState(data)
    end)
    RegisterNetEvent(Events.client.cvcRoundEnd, function(data)
        Nui.send('cvcBanner', data)
    end)
    RegisterNetEvent(Events.client.cvcEnd, function(data)
        CreateThread(function()
            Cvc.finish(data)
        end)
    end)
    CreateThread(Cvc.loop)
end

---@return boolean une partie de CVC est en cours pour ce joueur
function Cvc.isActive()
    return State.activity == Cvc.ACTIVITY
end

-- ---------------------------------------------------------------------------
-- Manche
-- ---------------------------------------------------------------------------

---@param data table round, team, arena, spawn, vehicleKey, seat, model, kit, countdown, ...
function Cvc.startRound(data)
    State.activity = Cvc.ACTIVITY
    Cvc.round = data
    Cvc.lockedUntil = GetGameTimer() + data.countdown * 1000
    Nui.send('cvcHud', {
        open = true,
        round = data.round,
        team = data.team.label,
        teamId = data.team.id,
        arena = data.arena.label,
        countdown = data.countdown,
        roundTime = data.roundTime,
        roundsToWin = data.roundsToWin,
        scores = data.scores,
    })

    DoScreenFadeOut(Cvc.FADE)
    while not IsScreenFadedOut() do Wait(0) end
    Cvc.deleteVehicle()
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

    Cvc.giveKit(ped, data.kit)
    Cvc.drawArena(data.arena)

    if data.seat == -1 then
        Cvc.createVehicle(data, ground)
    else
        Cvc.pendingSeat = data.seat
    end
    DoScreenFadeIn(Cvc.FADE)
end

---@param ped integer
---@param kit table { weapons, armor }
function Cvc.giveKit(ped, kit)
    RemoveAllPedWeapons(ped, true)
    SetPedInfiniteAmmoClip(ped, false)
    for _, entry in ipairs(kit.weapons) do
        local hash = GetHashKey(entry.weapon)
        GiveWeaponToPed(ped, hash, entry.ammo, false, false)
        -- Les armes du Freeroam ont des munitions infinies : pas en CVC
        SetPedInfiniteAmmo(ped, false, hash)
        SetPedAmmo(ped, hash, entry.ammo)
    end
    SetEntityHealth(ped, GetEntityMaxHealth(ped))
    SetPedArmour(ped, kit.armor or 0)
end

---Conducteur : crée le véhicule de son équipage et envoie son net id aux passagers (via le serveur).
---@param data table
---@param ground number
function Cvc.createVehicle(data, ground)
    local hash = GetHashKey(data.model)
    if not PedUtils.loadModel(hash) then return end
    local spawn = data.spawn
    local vehicle = CreateVehicle(hash, spawn.x, spawn.y, ground + 0.5, spawn.w, true, false)
    SetModelAsNoLongerNeeded(hash)
    if vehicle == 0 then return end

    SetEntityAsMissionEntity(vehicle, true, true)
    SetVehicleOnGroundProperly(vehicle)
    SetVehicleNumberPlateText(vehicle, data.team.label:upper())
    SetVehRadioStation(vehicle, 'OFF')
    SetPedIntoVehicle(PlayerPedId(), vehicle, -1)
    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    SetNetworkIdCanMigrate(netId, true)
    Cvc.vehicle = vehicle
    TriggerServerEvent(Events.server.cvcVehicle, data.vehicleKey, netId)
end

---Passager : monte dans le véhicule créé par le conducteur de son équipage.
---@param netId integer
function Cvc.boardVehicle(netId)
    local limit = GetGameTimer() + Cvc.VEHICLE_WAIT
    while not NetworkDoesNetworkIdExist(netId) and GetGameTimer() < limit do Wait(100) end
    if not NetworkDoesNetworkIdExist(netId) then return end
    local vehicle = NetToVeh(netId)
    if vehicle ~= 0 then SetPedIntoVehicle(PlayerPedId(), vehicle, Cvc.pendingSeat) end
end

---@param arena { label: string, center: vector3, radius: number }
function Cvc.drawArena(arena)
    if Cvc.arenaBlip and DoesBlipExist(Cvc.arenaBlip) then RemoveBlip(Cvc.arenaBlip) end
    Cvc.arenaBlip = AddBlipForRadius(arena.center.x, arena.center.y, arena.center.z, arena.radius)
    SetBlipColour(Cvc.arenaBlip, 5)
    SetBlipAlpha(Cvc.arenaBlip, 80)
end

---Compte à rebours (commandes bloquées) et dégâts hors de la zone de combat.
function Cvc.loop()
    while true do
        if Cvc.isActive() and Cvc.round then
            local now = GetGameTimer()
            if now < Cvc.lockedUntil then
                for _, control in ipairs(Cvc.LOCKED_CONTROLS) do DisableControlAction(0, control, true) end
            end
            Cvc.checkArena(now)
            Wait(0)
        else
            Wait(500)
        end
    end
end

---@param now integer
function Cvc.checkArena(now)
    if State.dead then return end
    local ped = PlayerPedId()
    local arena = Cvc.round.arena
    local outside = #(GetEntityCoords(ped).xy - arena.center.xy) > arena.radius
    if outside ~= Cvc.outside then
        Cvc.outside = outside
        Nui.send('cvcOutside', { outside = outside })
    end
    if outside and now >= Cvc.nextOutsideDamage then
        Cvc.nextOutsideDamage = now + 1000
        ApplyDamageToPed(ped, Cvc.round.outsideDamage, false)
    end
end

---État de la manche : temps, survivants, positions des coéquipiers.
---@param data { remaining: integer, alive: table, mates: table[] }
function Cvc.onState(data)
    if not Cvc.isActive() then return end
    Cvc.mates = data.mates
    local me = GetPlayerServerId(PlayerId())
    local seen = {}
    for _, mate in ipairs(data.mates) do
        if mate.id ~= me then
            seen[mate.id] = true
            local blip = Cvc.mateBlips[mate.id]
            if not blip then
                blip = AddBlipForCoord(mate.coords.x, mate.coords.y, mate.coords.z)
                SetBlipSprite(blip, 1)
                SetBlipScale(blip, 0.8)
                BeginTextCommandSetBlipName('STRING')
                AddTextComponentSubstringPlayerName(mate.name)
                EndTextCommandSetBlipName(blip)
                Cvc.mateBlips[mate.id] = blip
            end
            SetBlipCoords(blip, mate.coords.x, mate.coords.y, mate.coords.z)
            SetBlipColour(blip, mate.alive and Cvc.round.team.blipColor or 4)
        end
    end
    for id, blip in pairs(Cvc.mateBlips) do
        if not seen[id] then
            RemoveBlip(blip)
            Cvc.mateBlips[id] = nil
        end
    end
    -- Mort : on suit un coéquipier encore en vie
    if State.dead and not Death.spectating then Cvc.spectateMate() end
    Nui.send('cvcState', { remaining = data.remaining, alive = data.alive })
end

---Appelé à la mort (Freeroam.onDeath) : pas de réapparition avant la manche suivante.
function Cvc.onDeath()
    State.dead = true
    Nui.notify('Éliminé : tu suis ton équipe jusqu\'à la fin de la manche.', 'error')
    Cvc.spectateMate()
end

function Cvc.spectateMate()
    local me = GetPlayerServerId(PlayerId())
    for _, mate in ipairs(Cvc.mates) do
        if mate.alive and mate.id ~= me then
            Death.spectate(mate.id)
            return
        end
    end
end

-- ---------------------------------------------------------------------------
-- Fin
-- ---------------------------------------------------------------------------

---Fin de la partie : retour à la zone safe du Freeroam.
---@param data { result: string, reason: string|nil, scores: table, spawn: vector4|nil }
function Cvc.finish(data)
    Nui.send('cvcHud', { open = false })
    Nui.send('cvcEnd', { result = data.result, reason = data.reason, scores = data.scores, elo = data.elo })

    DoScreenFadeOut(Cvc.FADE)
    while not IsScreenFadedOut() do Wait(0) end
    Death.stopSpectate()
    local spawn = data.spawn
    if spawn and (State.dead or IsEntityDead(PlayerPedId())) then
        NetworkResurrectLocalPlayer(spawn.x, spawn.y, spawn.z, spawn.w, true, false)
        State.dead = false
    end
    Cvc.cleanup()
    local ped = PlayerPedId()
    SetEntityHealth(ped, GetEntityMaxHealth(ped))
    SetPedArmour(ped, 0)
    RemoveAllPedWeapons(ped, true)
    Freeroam.restoreWeapons()
    if spawn then
        if IsPedInAnyVehicle(ped, false) then ClearPedTasksImmediately(ped) end
        RequestCollisionAtCoord(spawn.x, spawn.y, spawn.z)
        SetEntityCoordsNoOffset(ped, spawn.x, spawn.y, PedUtils.findGroundZ(spawn.x, spawn.y, spawn.z), false, false, false)
        SetEntityHeading(ped, spawn.w)
    end
    DoScreenFadeIn(Cvc.FADE)
end

function Cvc.deleteVehicle()
    if Cvc.vehicle and DoesEntityExist(Cvc.vehicle) then
        SetEntityAsMissionEntity(Cvc.vehicle, true, true)
        DeleteVehicle(Cvc.vehicle)
    end
    Cvc.vehicle = nil
end

function Cvc.cleanup()
    Cvc.deleteVehicle()
    if Cvc.arenaBlip and DoesBlipExist(Cvc.arenaBlip) then RemoveBlip(Cvc.arenaBlip) end
    Cvc.arenaBlip = nil
    for id, blip in pairs(Cvc.mateBlips) do
        RemoveBlip(blip)
        Cvc.mateBlips[id] = nil
    end
    Cvc.round = nil
    Cvc.mates = {}
    Cvc.outside = false
    if State.activity == Cvc.ACTIVITY then State.activity = nil end
end
