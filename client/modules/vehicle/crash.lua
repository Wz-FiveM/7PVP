---Accidents de véhicule, en PvP uniquement (voir Config.VehicleCrash) :
---  - à bord, le ped est protégé des chocs et ne traverse pas le pare-brise ;
---  - éjecté (chute de moto, saut en marche), il garde la protection un court instant, sans ragdoll :
---    s'il a commencé à tomber, il est remis debout aussitôt.
---Les balles, le feu et les explosions blessent normalement. À bord, le ragdoll reste autorisé :
---bloqué, il fige le véhicule (voir Fall).
---@class VehicleCrashModule
local VehicleCrash = PVP.define('VehicleCrash')
local State = PVP.use('State')
local Fall = PVP.use('Fall')

VehicleCrash.IDLE_INTERVAL = 100
VehicleCrash.FLAG_WINDSCREEN = 32 -- le ped peut traverser le pare-brise

VehicleCrash.protected = false
VehicleCrash.protectedUntil = 0 -- ms de fin de la protection après avoir quitté le véhicule
VehicleCrash.windscreen = true -- réglage du ped à rendre en fin de protection

function VehicleCrash.init()
    if not Config.VehicleCrash.enabled then return end
    CreateThread(VehicleCrash.loop)
end

function VehicleCrash.loop()
    while true do
        local ped = PlayerPedId()
        if State.isAlive() and State.inPvp() and VehicleCrash.update(ped) then
            Wait(0)
        else
            if VehicleCrash.protected then VehicleCrash.release(ped) end
            Wait(VehicleCrash.IDLE_INTERVAL)
        end
    end
end

---@param ped integer
---@return boolean le ped est protégé : à bord ou tout juste sorti du véhicule
function VehicleCrash.update(ped)
    local now = GetGameTimer()
    local aboard = Fall.inVehicle(ped)
    if aboard then
        VehicleCrash.protectedUntil = now + Config.VehicleCrash.exitGrace
    elseif now >= VehicleCrash.protectedUntil then
        return false
    end
    VehicleCrash.protect(ped, aboard)
    return true
end

---Réappliqué à chaque image : Fall retire les mêmes protections quand une chute se termine.
---@param ped integer
---@param aboard boolean
function VehicleCrash.protect(ped, aboard)
    if not VehicleCrash.protected then
        VehicleCrash.protected = true
        VehicleCrash.windscreen = GetPedConfigFlag(ped, VehicleCrash.FLAG_WINDSCREEN, true)
    end
    SetEntityProofs(ped, false, false, false, true, false, false, false, false)
    SetPedConfigFlag(ped, VehicleCrash.FLAG_WINDSCREEN, false)
    SetPedCanRagdoll(ped, aboard)
    if not aboard and (IsPedRagdoll(ped) or IsPedGettingUp(ped)) then
        ClearPedTasksImmediately(ped)
    end
end

---@param ped integer
function VehicleCrash.release(ped)
    VehicleCrash.protected = false
    SetPedConfigFlag(ped, VehicleCrash.FLAG_WINDSCREEN, VehicleCrash.windscreen)
    -- En pleine chute, c'est Fall qui rendra les protections à l'atterrissage
    if not Fall.active then Fall.unprotect(ped) end
end
