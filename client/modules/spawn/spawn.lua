---Spawn custom (pas de spawnmanager).
---@class SpawnModule
local Spawn = PVP.define('Spawn')
local State = PVP.use('State')
local Nui = PVP.use('Nui')
local Zone = PVP.use('Zone')
local PedUtils = PVP.use('PedUtils')
local Loadout = PVP.use('Loadout')
local Appearance = PVP.use('Appearance')
local AppearanceSchema = PVP.use('AppearanceSchema')
local Events = PVP.use('Events')

function Spawn.init()
    RegisterNetEvent(Events.client.spawn, function(spawn, appearance)
        Spawn.spawnAt(spawn, appearance)
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

---@param spawn vector4
---@param appearance table|nil apparence du personnage (voir shared/modules/appearance.lua)
function Spawn.spawnAt(spawn, appearance)
    DoScreenFadeOut(500)
    while not IsScreenFadedOut() do Wait(0) end

    State.appearance = appearance or State.appearance or AppearanceSchema.default('male')
    Appearance.ensureModel(State.appearance.sex)
    RequestCollisionAtCoord(spawn.x, spawn.y, spawn.z)
    NetworkResurrectLocalPlayer(spawn.x, spawn.y, spawn.z, spawn.w, true, false)

    local ped = PlayerPedId()
    Appearance.apply(ped, State.appearance)
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
