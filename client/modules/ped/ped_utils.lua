---@class PedUtilsModule
local PedUtils = PVP.define('PedUtils')

PedUtils.UNDERGROUND_Z = -15.0 -- plus bas : intérieurs souterrains
PedUtils.UNDERGROUND_PROBE = 1.5
PedUtils.SPOT_ATTEMPTS = 100
PedUtils.INTERIOR_TIMEOUT = 10000 -- ms pour qu'un intérieur souterrain soit chargé
PedUtils.SPOT_WAIT = 50
PedUtils.SPOT_DROP = 10.0 -- un sol plus bas est celui de l'étage du dessous (sol des tunnels Doomsday : jusqu'à 5 m sous leur origine)
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
    local interior = PedUtils.waitInterior(wanted)
    for _ = 1, PedUtils.SPOT_ATTEMPTS do
        RequestCollisionAtCoord(x, y, z)
        local found, ground = GetGroundZFor_3dCoord(x, y, z + PedUtils.UNDERGROUND_PROBE, false)
        if found and z - ground <= PedUtils.SPOT_DROP then return x, y, ground, true end
        local safe, point = GetSafeCoordForPed(x, y, z, true, 16)
        if safe and #(point - wanted) <= PedUtils.SPOT_SNAP then return point.x, point.y, point.z, true end
        Wait(PedUtils.SPOT_WAIT)
    end
    -- Dans la console F8 : de quoi corriger le point
    print(('[sol] rien sous %.1f, %.1f, %.1f (intérieur %d, chargé : %s)'):format(x, y, z, interior,
        tostring(interior ~= 0 and IsInteriorReady(interior))))
    return x, y, z, false
end

---Sous terre, le sol est celui d'un intérieur : tant que le jeu ne l'a pas chargé, il n'y a rien sous
---les pieds. Le joueur doit déjà être sur place, c'est sa position qui fait charger l'intérieur.
---@param coords vector3
---@return integer intérieur, 0 si le point n'est dans aucun
function PedUtils.waitInterior(coords)
    local interior = GetInteriorAtCoords(coords.x, coords.y, coords.z)
    if interior == 0 then return 0 end
    local timeout = GetGameTimer() + PedUtils.INTERIOR_TIMEOUT
    while not IsInteriorReady(interior) and GetGameTimer() < timeout do Wait(0) end
    return interior
end

---Le jeu ne met une entité dans un intérieur que lorsqu'elle y entre par une ouverture : posée
---directement dedans, elle reste « dehors », sur le sol de l'intérieur mais sans qu'il s'affiche
---(et sans être vue de ceux qui y sont). On lui donne la pièce où elle se trouve.
---@param entity integer
---@param viewport? boolean aussi la caméra du joueur (pour son propre personnage)
---@return boolean placée dans une pièce
function PedUtils.enterRoom(entity, viewport)
    local coords = GetEntityCoords(entity)
    local interior = GetInteriorAtCoords(coords.x, coords.y, coords.z)
    if interior == 0 then return false end
    local room = PedUtils.roomAt(interior, coords)
    if not room then return false end
    ForceRoomForEntity(entity, interior, room)
    if viewport then ForceRoomForGameViewport(interior, room) end
    return true
end

---@param interior integer
---@param coords vector3
---@return integer|nil clé de la pièce qui contient `coords` (sinon la plus proche), nil si l'intérieur n'en a pas
function PedUtils.roomAt(interior, coords)
    local count = GetInteriorRoomCount(interior)
    if not count or count < 2 then return nil end
    local point = PedUtils.toInterior(interior, coords)
    local best, bestDistance = nil, math.huge
    -- La pièce 0 est « limbo », le dehors
    for index = 1, count - 1 do
        local minX, minY, minZ, maxX, maxY, maxZ = GetInteriorRoomExtents(interior, index)
        local center = vector3((minX + maxX) / 2, (minY + maxY) / 2, (minZ + maxZ) / 2)
        local inside = point.x >= minX and point.x <= maxX and point.y >= minY and point.y <= maxY
            and point.z >= minZ and point.z <= maxZ
        local distance = inside and -1 or #(point - center)
        if distance < bestDistance then
            best, bestDistance = index, distance
        end
    end
    return best and GetHashKey(GetInteriorRoomName(interior, best)) or nil
end

---Les dimensions des pièces sont données dans le repère de l'intérieur.
---@param interior integer
---@param coords vector3
---@return vector3
function PedUtils.toInterior(interior, coords)
    local px, py, pz = GetInteriorPosition(interior)
    local qx, qy, qz, qw = GetInteriorRotation(interior)
    local v = coords - vector3(px, py, pz)
    -- Rotation inverse (quaternion conjugué) : v + 2w(q × v) + 2q × (q × v), avec q = -(qx, qy, qz)
    local q = vector3(-qx, -qy, -qz)
    local t = PedUtils.cross(q, v) * 2.0
    return v + t * qw + PedUtils.cross(q, t)
end

---@param a vector3
---@param b vector3
---@return vector3
function PedUtils.cross(a, b)
    return vector3(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x)
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
