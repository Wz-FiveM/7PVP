---Spawn custom (pas de spawnmanager).
---@class SpawnModule
local Spawn = PVP.define('Spawn')
local State = PVP.use('State')
local Nui = PVP.use('Nui')
local Zone = PVP.use('Zone')
local PedUtils = PVP.use('PedUtils')
local Loadout = PVP.use('Loadout')
local Events = PVP.use('Events')

function Spawn.init()
    RegisterNetEvent(Events.client.spawn, function(spawn)
        Spawn.spawnAt(spawn)
    end)

    CreateThread(Spawn.start)
end

function Spawn.start()
    while not NetworkIsSessionStarted() do Wait(100) end
    Spawn.configureWorld()
    TriggerServerEvent(Events.server.ready)
end

function Spawn.configureWorld()
    if GetResourceState('spawnmanager') == 'started' then
        exports.spawnmanager:setAutoSpawn(false)
    end

    SetMaxWantedLevel(0)
    NetworkSetFriendlyFireOption(true)
    SetPlayerHealthRechargeMultiplier(PlayerId(), 0.0)
    for service = 1, 15 do
        EnableDispatchService(service, false)
    end
end

function Spawn.applyModel()
    local model = GetHashKey(Config.PlayerModel)
    if GetEntityModel(PlayerPedId()) == model then return end
    PedUtils.loadModel(model)
    SetPlayerModel(PlayerId(), model)
    SetModelAsNoLongerNeeded(model)
    SetPedDefaultComponentVariation(PlayerPedId())
end

---@param spawn vector4
function Spawn.spawnAt(spawn)
    DoScreenFadeOut(500)
    while not IsScreenFadedOut() do Wait(0) end

    Spawn.applyModel()
    RequestCollisionAtCoord(spawn.x, spawn.y, spawn.z)
    NetworkResurrectLocalPlayer(spawn.x, spawn.y, spawn.z, spawn.w, true, false)

    local ped = PlayerPedId()
    FreezeEntityPosition(ped, true)
    SetEntityCoordsNoOffset(ped, spawn.x, spawn.y, spawn.z, false, false, false)

    local timeout = GetGameTimer() + 5000
    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < timeout do Wait(0) end
    SetEntityCoordsNoOffset(ped, spawn.x, spawn.y, PedUtils.findGroundZ(spawn.x, spawn.y, spawn.z), false, false, false)
    SetEntityHeading(ped, spawn.w)

    Spawn.resetPed(ped)
    FreezeEntityPosition(ped, false)

    ShutdownLoadingScreen()
    ShutdownLoadingScreenNui()
    DoScreenFadeIn(500)

    State.dead = false
    State.spawned = true
    Zone.reset()
    -- Le changement de modèle et la résurrection retirent les armes : on les réapplique
    Loadout.apply()
    Nui.send('alive')
end

---@param ped integer
function Spawn.resetPed(ped)
    ClearPedTasksImmediately(ped)
    ClearPedBloodDamage(ped)
    SetEntityHealth(ped, GetEntityMaxHealth(ped))
    SetPedArmour(ped, 0)
    SetEntityVisible(ped, true, false)
    SetCanAttackFriendly(ped, true, false)
end
