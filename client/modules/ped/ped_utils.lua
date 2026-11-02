---@class PedUtilsModule
local PedUtils = PVP.define('PedUtils')

PedUtils.UNDERGROUND_Z = -15.0 -- plus bas : intérieurs souterrains
PedUtils.UNDERGROUND_PROBE = 1.5
PedUtils.SPOT_ATTEMPTS = 40
PedUtils.SPOT_WAIT = 50
PedUtils.SPOT_DROP = 4.0 -- un sol plus bas est celui de l'étage du dessous
PedUtils.SPOT_SNAP = 25.0

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
    -- Sous terre, les intérieurs sont empilés : cherché de haut, le sol serait celui de l'étage du dessus
    local above = z < PedUtils.UNDERGROUND_Z and PedUtils.UNDERGROUND_PROBE or 50.0
    for _ = 1, 50 do
        local found, ground = GetGroundZFor_3dCoord(x, y, z + above, false)
        if found then return ground end
        Wait(0)
    end
    return z
end

---Point où poser un joueur. Sous terre, sous un point mal placé il n'y a que du vide : on prend alors
---le point de marche le plus proche, et on prévient si rien ne convient (à l'appelant de ne pas bouger).
---@param x number
---@param y number
---@param z number
---@return number x
---@return number y
---@return number z
---@return boolean found
function PedUtils.findSpot(x, y, z)
    if z >= PedUtils.UNDERGROUND_Z then return x, y, PedUtils.findGroundZ(x, y, z), true end

    local wanted = vector3(x, y, z)
    for _ = 1, PedUtils.SPOT_ATTEMPTS do
        local found, ground = GetGroundZFor_3dCoord(x, y, z + PedUtils.UNDERGROUND_PROBE, false)
        if found and z - ground <= PedUtils.SPOT_DROP then return x, y, ground, true end
        local safe, point = GetSafeCoordForPed(x, y, z, true, 16)
        if safe and #(point - wanted) <= PedUtils.SPOT_SNAP then return point.x, point.y, point.z, true end
        Wait(PedUtils.SPOT_WAIT)
    end
    return x, y, z, false
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
