---@class PedUtilsModule
local PedUtils = PVP.define('PedUtils')

PedUtils.UNDERGROUND_Z = -15.0 -- plus bas : intérieurs souterrains
PedUtils.UNDERGROUND_PROBE = 1.5
PedUtils.SPOT_ATTEMPTS = 100
PedUtils.INTERIOR_TIMEOUT = 10000 -- ms pour qu'un intérieur souterrain soit chargé
PedUtils.SPOT_WAIT = 50
PedUtils.SPOT_DROP = 10.0 -- un sol plus bas est celui de l'étage du dessous (sol des tunnels Doomsday : jusqu'à 5 m sous leur origine)
PedUtils.SPOT_SNAP = 25.0
PedUtils.FLOOR_DEPTH = 40.0 -- sous un point souterrain, sol cherché jusque-là s'il a un plafond au-dessus
PedUtils.FLOORS = 8 -- surfaces traversées au plus (toits des intérieurs) pour le trouver
PedUtils.CEILING_HEIGHT = 30.0
-- Autour d'un point souterrain hors des pièces : distances (m), directions par cercle, hauteurs de départ
PedUtils.NEARBY_RADII = { 0, 2, 4, 6, 9, 12, 15 }
PedUtils.NEARBY_DIRECTIONS = 8
PedUtils.NEARBY_RISES = { 0.0, 6.0 }

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
        local fx, fy, floor = PedUtils.findIndoorFloor(x, y, z)
        if fx then
            if #(vector3(fx, fy, floor) - wanted) > PedUtils.SPOT_DROP then
                -- Dans la console F8 : de quoi corriger le point
                print(('[sol] %.1f, %.1f, %.1f : intérieur trouvé en %.2f, %.2f, %.2f'):format(x, y, z, fx, fy, floor))
            end
            return fx, fy, floor, true
        end
        local found, ground = PedUtils.findFloor(x, y, z)
        if found then return x, y, ground, true end
        local safe, point = GetSafeCoordForPed(x, y, z, true, 16)
        if safe and #(point - wanted) <= PedUtils.SPOT_SNAP then return point.x, point.y, point.z, true end
        Wait(PedUtils.SPOT_WAIT)
    end
    -- Dans la console F8 : de quoi corriger le point
    print(('[sol] rien sous %.1f, %.1f, %.1f (intérieur %d, chargé : %s)'):format(x, y, z, interior,
        tostring(interior ~= 0 and IsInteriorReady(interior))))
    return x, y, z, false
end

---Sous terre, le premier sol sous un point peut être le dessus d'un intérieur (son toit) : on descend
---jusqu'au premier sol qui est dans une pièce de l'intérieur. Sans pièce nulle part, le premier sol pas
---trop bas fait l'affaire.
---@param x number
---@param y number
---@param z number
---@return boolean found
---@return number ground
---@return boolean covered sol sous un plafond
function PedUtils.findFloor(x, y, z)
    local start = z + PedUtils.UNDERGROUND_PROBE
    local first = nil
    for _ = 1, PedUtils.FLOORS do
        local found, ground = GetGroundZFor_3dCoord(x, y, start, false)
        if not found or z - ground > PedUtils.FLOOR_DEPTH then break end
        first = first or ground
        if PedUtils.isIndoors(x, y, ground) then return true, ground, true end
        start = ground - 0.5
    end
    if first and z - first <= PedUtils.SPOT_DROP then return true, first, false end
    return false, z, false
end

---Un point mal placé peut tomber juste à côté du tube d'un tunnel, ou un peu sous son sol : on cherche
---autour de lui, du plus près au plus loin, un sol qui est dans une pièce d'un intérieur.
---@param x number
---@param y number
---@param z number
---@return number|nil x
---@return number|nil y
---@return number|nil ground
function PedUtils.findIndoorFloor(x, y, z)
    for _, radius in ipairs(PedUtils.NEARBY_RADII) do
        local turns = radius == 0 and 1 or PedUtils.NEARBY_DIRECTIONS
        for turn = 1, turns do
            local angle = (turn - 1) / turns * math.pi * 2
            local px, py = x + math.cos(angle) * radius, y + math.sin(angle) * radius
            for _, rise in ipairs(PedUtils.NEARBY_RISES) do
                local found, ground, covered = PedUtils.findFloor(px, py, z + rise)
                if found and covered then return px, py, ground end
            end
        end
    end
    return nil
end

---Debout sur ce sol, on est dans une pièce d'un intérieur. Sur son toit, sous lui ou à côté, on est
---hors de ses pièces. Pour un intérieur dont le jeu ne donne pas les pièces, on cherche un plafond.
---@return boolean
function PedUtils.isIndoors(x, y, ground)
    local coords = vector3(x, y, ground + 1.0)
    local interior = GetInteriorAtCoords(coords.x, coords.y, coords.z)
    if interior == 0 then return false end
    if (GetInteriorRoomCount(interior) or 0) >= 2 then
        return PedUtils.roomIndexAt(interior, coords) ~= nil
    end
    return PedUtils.hasCeiling(x, y, ground)
end

---@return boolean une surface du décor au-dessus de ce sol
function PedUtils.hasCeiling(x, y, ground)
    local probe = StartExpensiveSynchronousShapeTestLosProbe(x, y, ground + 1.0, x, y, ground + PedUtils.CEILING_HEIGHT,
        1, PlayerPedId(), 7)
    local _, hit = GetShapeTestResult(probe)
    return hit == true or hit == 1
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
---(et sans être vue de ceux qui y sont). On lui donne la pièce où elle se trouve, seulement si elle
---n'en a pas et qu'une pièce la contient vraiment : une mauvaise pièce cacherait tout l'intérieur.
---@param entity integer
---@param viewport? boolean aussi la caméra du joueur (pour son propre personnage)
---@return boolean placée dans une pièce
function PedUtils.enterRoom(entity, viewport)
    if GetRoomKeyFromEntity(entity) ~= 0 then return false end
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
---@return integer|nil clé de la pièce qui contient `coords`, nil si aucune
function PedUtils.roomAt(interior, coords)
    local index = PedUtils.roomIndexAt(interior, coords)
    return index and GetHashKey(GetInteriorRoomName(interior, index)) or nil
end

---Le sens de la rotation rendue par le jeu n'est pas vérifié : les deux sont essayés.
---@param interior integer
---@param coords vector3
---@return integer|nil numéro de la pièce qui contient `coords`
function PedUtils.roomIndexAt(interior, coords)
    local count = GetInteriorRoomCount(interior)
    if not count or count < 2 then return nil end
    for _, inverse in ipairs({ true, false }) do
        local point = PedUtils.toInterior(interior, coords, inverse)
        -- La pièce 0 est « limbo », le dehors
        for index = 1, count - 1 do
            local minX, minY, minZ, maxX, maxY, maxZ = GetInteriorRoomExtents(interior, index)
            if point.x >= minX and point.x <= maxX and point.y >= minY and point.y <= maxY
                and point.z >= minZ and point.z <= maxZ then
                return index
            end
        end
    end
    return nil
end

---Les dimensions des pièces sont données dans le repère de l'intérieur.
---@param interior integer
---@param coords vector3
---@param inverse boolean rotation inverse (quaternion conjugué)
---@return vector3
function PedUtils.toInterior(interior, coords, inverse)
    local px, py, pz = GetInteriorPosition(interior)
    local qx, qy, qz, qw = GetInteriorRotation(interior)
    local v = coords - vector3(px, py, pz)
    -- v + 2w(q × v) + 2q × (q × v)
    local sign = inverse and -1.0 or 1.0
    local q = vector3(qx * sign, qy * sign, qz * sign)
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
