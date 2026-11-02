---@class PedUtilsModule
local PedUtils = PVP.define('PedUtils')

---Server id du joueur qui a tué `ped`, ou nil (PNJ, chute, suicide...).
---@param ped integer
---@return integer|nil
function PedUtils.getKillerServerId(ped)
    local source = GetPedSourceOfDeath(ped)
    if source ~= 0 and IsEntityAVehicle(source) then
        source = GetPedInVehicleSeat(source, -1)
    end
    if source ~= 0 and source ~= ped and IsPedAPlayer(source) then
        return GetPlayerServerId(NetworkGetPlayerIndexFromPed(source))
    end
    return nil
end

---@param model integer
---@param timeout? integer ms
---@return boolean
function PedUtils.loadModel(model, timeout)
    local limit = GetGameTimer() + (timeout or 5000)
    repeat
        RequestModel(model)
        if HasModelLoaded(model) then return true end
        Wait(0)
    until GetGameTimer() >= limit
    return HasModelLoaded(model)
end

---Copie locale d'un joueur, sans entité réseau : un personnage neuf avec son modèle et sa tenue.
---ClonePed reprendrait aussi son état : la copie d'un joueur mort reste au sol, même ressuscitée.
---@param source integer personnage réel du joueur
---@return integer|nil
function PedUtils.copyPlayer(source)
    if not DoesEntityExist(source) then return nil end
    local model = GetEntityModel(source)
    if not PedUtils.loadModel(model) then return nil end
    local coords = GetEntityCoords(source)
    local ped = CreatePed(4, model, coords.x, coords.y, coords.z, GetEntityHeading(source), false, false)
    SetModelAsNoLongerNeeded(model)
    if not DoesEntityExist(ped) then return nil end
    ClonePedToTarget(source, ped)
    return ped
end

---@return number z du sol, ou `z` si introuvable
function PedUtils.findGroundZ(x, y, z)
    for _ = 1, 50 do
        local found, ground = GetGroundZFor_3dCoord(x, y, z + 50.0, false)
        if found then return ground end
        Wait(0)
    end
    return z
end

---Distance entre `coords` et le joueur actif le plus proche.
---@param coords vector3
---@return number
function PedUtils.nearestPlayerDistance(coords)
    local best = math.huge
    for _, player in ipairs(GetActivePlayers()) do
        local dist = #(GetEntityCoords(GetPlayerPed(player)) - coords)
        if dist < best then best = dist end
    end
    return best
end
