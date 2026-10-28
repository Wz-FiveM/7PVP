---Debout sur le toit d'un véhicule qui roule ou qui vole (Config.VehicleRoof) : la physique de GTA
---fait glisser le joueur et le fait tomber. Il est donc accroché au véhicule, à l'endroit où il se
---tient ; les touches de marche déplacent ce point sur le toit (sans dépasser les bords), le corps
---suit la caméra pour viser et tirer. Espace le décroche, F le met à une place libre.
---@class VehicleRoofModule
local VehicleRoof = PVP.define('VehicleRoof')
local State = PVP.use('State')

VehicleRoof.IDLE_INTERVAL = 150
VehicleRoof.PROBE_DEPTH = 1.8 -- m sous le centre du joueur pour trouver le toit
VehicleRoof.PROBE_VEHICLES = 2 -- masque des véhicules pour le rayon
VehicleRoof.RELEASE_DELAY = 1000 -- ms à l'arrêt au sol avant de rendre la marche normale
VehicleRoof.REATTACH_DELAY = 1500 -- ms après un saut avant de pouvoir être raccroché
VehicleRoof.CONTROL_JUMP = 22
VehicleRoof.CONTROL_ENTER = 23
VehicleRoof.CONTROL_MOVE_LR = 30
VehicleRoof.CONTROL_MOVE_UD = 31

---@type integer|nil véhicule sur lequel le joueur est accroché
VehicleRoof.vehicle = nil
---@type vector3|nil position du joueur dans le repère du véhicule
VehicleRoof.offset = nil
---@type { minX: number, maxX: number, minY: number, maxY: number }|nil
VehicleRoof.bounds = nil
VehicleRoof.slowSince = nil
VehicleRoof.blockedUntil = 0

function VehicleRoof.init()
    if not Config.VehicleRoof.enabled then return end
    CreateThread(VehicleRoof.loop)
end

function VehicleRoof.loop()
    while true do
        local ped = PlayerPedId()
        if VehicleRoof.vehicle then
            VehicleRoof.update(ped)
            Wait(0)
        else
            local vehicle = VehicleRoof.vehicleUnder(ped)
            if vehicle then VehicleRoof.attach(ped, vehicle) end
            Wait(vehicle and 0 or VehicleRoof.IDLE_INTERVAL)
        end
    end
end

---@param vehicle integer
---@return boolean le véhicule roule ou vole (sinon on marche dessus normalement)
function VehicleRoof.isMoving(vehicle)
    return IsEntityInAir(vehicle) or GetEntitySpeed(vehicle) >= Config.VehicleRoof.minSpeed
end

---Véhicule en mouvement sous les pieds du joueur (à pied, debout dessus).
---@param ped integer
---@return integer|nil
function VehicleRoof.vehicleUnder(ped)
    if not State.spawned or State.dead or GetGameTimer() < VehicleRoof.blockedUntil then return nil end
    if IsPedInAnyVehicle(ped, false) or IsEntityAttached(ped) or not IsPedOnVehicle(ped) then return nil end

    local coords = GetEntityCoords(ped)
    local probe = StartExpensiveSynchronousShapeTestLosProbe(coords.x, coords.y, coords.z,
        coords.x, coords.y, coords.z - VehicleRoof.PROBE_DEPTH, VehicleRoof.PROBE_VEHICLES, ped, 0)
    local _, hit, _, _, entity = GetShapeTestResult(probe)
    if (hit ~= true and hit ~= 1) or entity == 0 or GetEntityType(entity) ~= 2 then return nil end
    if not VehicleRoof.isMoving(entity) then return nil end
    return entity
end

---@param ped integer
---@param vehicle integer
function VehicleRoof.attach(ped, vehicle)
    local min, max = GetModelDimensions(GetEntityModel(vehicle))
    local margin = Config.VehicleRoof.edgeMargin
    VehicleRoof.vehicle = vehicle
    VehicleRoof.offset = GetOffsetFromEntityGivenWorldCoords(vehicle, GetEntityCoords(ped))
    VehicleRoof.bounds = { minX = min.x + margin, maxX = max.x - margin, minY = min.y + margin, maxY = max.y - margin }
    VehicleRoof.slowSince = nil
    VehicleRoof.place(ped)
end

---@param ped integer
---@param enterVehicle? boolean F : place libre dans le véhicule
function VehicleRoof.detach(ped, enterVehicle)
    local vehicle = VehicleRoof.vehicle
    VehicleRoof.vehicle = nil
    VehicleRoof.offset = nil
    VehicleRoof.bounds = nil
    VehicleRoof.blockedUntil = GetGameTimer() + VehicleRoof.REATTACH_DELAY
    if IsEntityAttached(ped) then DetachEntity(ped, true, false) end
    if enterVehicle and vehicle and DoesEntityExist(vehicle) then
        local seat = VehicleRoof.freeSeat(vehicle)
        if seat then SetPedIntoVehicle(ped, vehicle, seat) end
    end
end

---@param vehicle integer
---@return integer|nil place libre (-1 = conducteur)
function VehicleRoof.freeSeat(vehicle)
    for seat = -1, GetVehicleMaxNumberOfPassengers(vehicle) - 1 do
        if IsVehicleSeatFree(vehicle, seat) then return seat end
    end
    return nil
end

---@param ped integer
function VehicleRoof.update(ped)
    local vehicle = VehicleRoof.vehicle
    if not DoesEntityExist(vehicle) or State.dead or not State.spawned or IsPedInAnyVehicle(ped, false) then
        return VehicleRoof.detach(ped)
    end
    if IsControlJustPressed(0, VehicleRoof.CONTROL_JUMP) then return VehicleRoof.detach(ped) end
    if IsControlJustPressed(0, VehicleRoof.CONTROL_ENTER) then return VehicleRoof.detach(ped, true) end

    -- Véhicule arrêté au sol : on rend la marche normale (on peut en descendre)
    if VehicleRoof.isMoving(vehicle) then
        VehicleRoof.slowSince = nil
    else
        VehicleRoof.slowSince = VehicleRoof.slowSince or GetGameTimer()
        if GetGameTimer() - VehicleRoof.slowSince > VehicleRoof.RELEASE_DELAY then
            VehicleRoof.blockedUntil = 0
            return VehicleRoof.detach(ped)
        end
    end

    VehicleRoof.walk(vehicle)
    VehicleRoof.place(ped)
end

---Déplace le point d'accroche selon les touches de marche, dans la direction de la caméra.
---@param vehicle integer
function VehicleRoof.walk(vehicle)
    local sideways = GetControlNormal(0, VehicleRoof.CONTROL_MOVE_LR)
    local backwards = GetControlNormal(0, VehicleRoof.CONTROL_MOVE_UD) -- -1 = avancer
    if sideways == 0.0 and backwards == 0.0 then return end

    local heading = math.rad(GetGameplayCamRot(2).z)
    local forward = vector3(-math.sin(heading), math.cos(heading), 0.0)
    local right = vector3(math.cos(heading), math.sin(heading), 0.0)
    local move = (right * sideways - forward * backwards) * (Config.VehicleRoof.walkSpeed * GetFrameTime())

    -- Déplacement monde -> repère du véhicule (son origine y vaut 0, 0, 0)
    local origin = GetEntityCoords(vehicle)
    local delta = GetOffsetFromEntityGivenWorldCoords(vehicle, origin.x + move.x, origin.y + move.y, origin.z + move.z)
    local offset, bounds = VehicleRoof.offset, VehicleRoof.bounds
    VehicleRoof.offset = vector3(
        math.min(bounds.maxX, math.max(bounds.minX, offset.x + delta.x)),
        math.min(bounds.maxY, math.max(bounds.minY, offset.y + delta.y)),
        offset.z
    )
end

---Accroche (ou raccroche) le joueur à son point sur le toit, tourné vers la caméra.
---@param ped integer
function VehicleRoof.place(ped)
    local offset = VehicleRoof.offset
    local heading = GetGameplayCamRot(2).z - GetEntityHeading(VehicleRoof.vehicle)
    AttachEntityToEntity(ped, VehicleRoof.vehicle, 0, offset.x, offset.y, offset.z, 0.0, 0.0, heading,
        false, false, false, false, 2, true)
end
