---Chutes sans dégâts ni animation de GTA (voir Config.Fall) :
---  - pendant une vraie chute, le ped est protégé des chocs (les dégâts de chute en sont)
---    et ne peut pas passer en ragdoll ;
---  - une pose neutre remplace l'animation « bras en l'air » ;
---  - à l'atterrissage, la roulade est coupée et les protections sont retirées.
---Le parachute n'est pas concerné.
---@class FallModule
local Fall = PVP.define('Fall')
local State = PVP.use('State')

Fall.IDLE_INTERVAL = 100
-- Délai après l'atterrissage avant de rendre les protections (le choc arrive juste après le contact)
Fall.LAND_GRACE = 400
Fall.ANIM_FLAGS = 1 -- en boucle

Fall.active = false

function Fall.init()
    if not Config.Fall.enabled then return end
    CreateThread(Fall.loop)
end

function Fall.loop()
    while true do
        local ped = PlayerPedId()
        if State.spawned and not State.dead and Fall.isFalling(ped) then
            if not Fall.active then Fall.start(ped) end
            Wait(0)
        else
            if Fall.active then Fall.land(ped) end
            Wait(Fall.IDLE_INTERVAL)
        end
    end
end

---Vraie chute : en l'air, en train de descendre vite, sans parachute ni véhicule.
---@param ped integer
---@return boolean
function Fall.isFalling(ped)
    if not IsPedFalling(ped) or IsPedInAnyVehicle(ped, false) then return false end
    if IsPedInParachuteFreeFall(ped) or GetPedParachuteState(ped) > 0 then return false end
    return Fall.active or GetEntityVelocity(ped).z <= -Config.Fall.minSpeed
end

---@param ped integer
function Fall.start(ped)
    Fall.active = true
    -- Chocs (dont la chute) sans dégâts, pas de ragdoll
    SetEntityProofs(ped, false, false, false, true, false, false, false, false)
    SetPedCanRagdoll(ped, false)
    Fall.playPose(ped)
end

---@param ped integer
function Fall.playPose(ped)
    local dict = Config.Fall.animDict
    RequestAnimDict(dict)
    local timeout = GetGameTimer() + 500
    while not HasAnimDictLoaded(dict) and GetGameTimer() < timeout do Wait(0) end
    -- Animation absente : on garde au moins l'absence de dégâts et de ragdoll
    if not HasAnimDictLoaded(dict) then return end
    TaskPlayAnim(ped, dict, Config.Fall.animName, 8.0, 8.0, -1, Fall.ANIM_FLAGS, 0.0, false, false, false)
end

---@param ped integer
function Fall.land(ped)
    Fall.active = false
    -- Coupe la pose et la roulade d'atterrissage : le joueur se retrouve debout
    StopAnimTask(ped, Config.Fall.animDict, Config.Fall.animName, 8.0)
    ClearPedTasks(ped)
    RemoveAnimDict(Config.Fall.animDict)
    Wait(Fall.LAND_GRACE)
    SetEntityProofs(ped, false, false, false, false, false, false, false, false)
    SetPedCanRagdoll(ped, true)
end
