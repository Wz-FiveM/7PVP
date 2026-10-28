---Debout sur le toit d'un véhicule qui roule ou qui vole (Config.VehicleRoof) : la physique de GTA
---fait glisser le joueur et le fait tomber. Il est donc accroché au véhicule, à l'endroit où il se
---tient ; les touches de marche déplacent ce point sur le toit (sans dépasser les bords). Il reste
---droit même quand le véhicule penche, se tourne vers où il marche avec l'animation de marche, et
---vers la caméra quand il vise ou tire. Espace le décroche, F le met à une place libre.
---@class VehicleRoofModule
local VehicleRoof = PVP.define('VehicleRoof')
local State = PVP.use('State')

VehicleRoof.IDLE_INTERVAL = 150
VehicleRoof.PROBE_DEPTH = 1.8 -- m sous le centre du joueur pour trouver le toit
VehicleRoof.PROBE_VEHICLES = 2 -- masque des véhicules pour le rayon
VehicleRoof.RELEASE_DELAY = 1000 -- ms à l'arrêt au sol avant de rendre la marche normale
VehicleRoof.REATTACH_DELAY = 1500 -- ms après un saut avant de pouvoir être raccroché
VehicleRoof.ANIM_FLAGS = 1 -- en boucle
VehicleRoof.CONTROL_SPRINT = 21
VehicleRoof.CONTROL_JUMP = 22
VehicleRoof.CONTROL_ENTER = 23
VehicleRoof.CONTROL_ATTACK = 24
VehicleRoof.CONTROL_AIM = 25
VehicleRoof.CONTROL_MOVE_LR = 30
VehicleRoof.CONTROL_MOVE_UD = 31

---@type integer|nil véhicule sur lequel le joueur est accroché
VehicleRoof.vehicle = nil
---@type vector3|nil position du joueur dans le repère du véhicule
VehicleRoof.offset = nil
---@type number cap du joueur par rapport à celui du véhicule (°)
VehicleRoof.heading = 0.0
---@type { minX: number, maxX: number, minY: number, maxY: number }|nil
VehicleRoof.bounds = nil
---@type string|nil animation de marche en cours
VehicleRoof.clip = nil
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
    VehicleRoof.heading = GetEntityHeading(ped) - GetEntityHeading(vehicle)
    VehicleRoof.bounds = { minX = min.x + margin, maxX = max.x - margin, minY = min.y + margin, maxY = max.y - margin }
    VehicleRoof.slowSince = nil
    RequestAnimDict(Config.VehicleRoof.anim.dict)
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
    VehicleRoof.animate(ped, nil)
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

    local aiming = IsControlPressed(0, VehicleRoof.CONTROL_AIM) or IsControlPressed(0, VehicleRoof.CONTROL_ATTACK)
    local moving, running = VehicleRoof.walk(vehicle, aiming)
    if aiming then
        -- Vise ou tire : le corps suit la caméra, pas d'animation de marche (elle couperait la visée)
        VehicleRoof.heading = GetGameplayCamRot(2).z - GetEntityHeading(vehicle)
        VehicleRoof.animate(ped, nil)
    else
        local anim = Config.VehicleRoof.anim
        VehicleRoof.animate(ped, moving and (running and anim.run or anim.walk) or nil)
    end
    VehicleRoof.place(ped)
end

---Déplace le point d'accroche selon les touches de marche, dans la direction de la caméra, et
---tourne le joueur vers où il marche (sauf s'il vise).
---@param vehicle integer
---@param aiming boolean
---@return boolean moving, boolean running
function VehicleRoof.walk(vehicle, aiming)
    local sideways = GetControlNormal(0, VehicleRoof.CONTROL_MOVE_LR)
    local backwards = GetControlNormal(0, VehicleRoof.CONTROL_MOVE_UD) -- -1 = avancer
    if sideways == 0.0 and backwards == 0.0 then return false, false end

    local running = not aiming and IsControlPressed(0, VehicleRoof.CONTROL_SPRINT)
    local speed = running and Config.VehicleRoof.runSpeed or Config.VehicleRoof.walkSpeed
    local heading = math.rad(GetGameplayCamRot(2).z)
    local forward = vector3(-math.sin(heading), math.cos(heading), 0.0)
    local right = vector3(math.cos(heading), math.sin(heading), 0.0)
    local move = (right * sideways - forward * backwards) * (speed * GetFrameTime())

    -- Déplacement monde -> repère du véhicule (son origine y vaut 0, 0, 0)
    local origin = GetEntityCoords(vehicle)
    local delta = GetOffsetFromEntityGivenWorldCoords(vehicle, origin.x + move.x, origin.y + move.y, origin.z + move.z)
    local offset, bounds = VehicleRoof.offset, VehicleRoof.bounds
    VehicleRoof.offset = vector3(
        math.min(bounds.maxX, math.max(bounds.minX, offset.x + delta.x)),
        math.min(bounds.maxY, math.max(bounds.minY, offset.y + delta.y)),
        offset.z
    )

    if not aiming then
        local target = GetHeadingFromVector_2d(move.x, move.y) - GetEntityHeading(vehicle)
        local diff = (target - VehicleRoof.heading + 180.0) % 360.0 - 180.0
        local step = Config.VehicleRoof.turnSpeed * GetFrameTime()
        VehicleRoof.heading = VehicleRoof.heading + math.max(-step, math.min(step, diff))
    end
    return true, running
end

---Lance (ou arrête avec nil) l'animation de marche, une seule fois tant qu'elle joue.
---@param ped integer
---@param clip string|nil
function VehicleRoof.animate(ped, clip)
    local dict = Config.VehicleRoof.anim.dict
    local current = VehicleRoof.clip
    if clip == current and (not clip or IsEntityPlayingAnim(ped, dict, clip, 3)) then return end
    if current and current ~= clip then StopAnimTask(ped, dict, current, 4.0) end
    VehicleRoof.clip = nil
    if not clip then return end
    if not HasAnimDictLoaded(dict) then return RequestAnimDict(dict) end
    TaskPlayAnim(ped, dict, clip, 4.0, 4.0, -1, VehicleRoof.ANIM_FLAGS, 0.0, false, false, false)
    VehicleRoof.clip = clip
end

---Rotation, dans le repère du véhicule, qui garde le joueur droit (debout à la verticale) avec le
---cap voulu, même quand le véhicule penche (Deluxo en vol, virage, montée).
---@param vehicle integer
---@param heading number cap voulu dans le monde (°)
---@return number pitch, number roll, number yaw
function VehicleRoof.uprightRotation(vehicle, heading)
    local vRight, vForward, vUp = GetEntityMatrix(vehicle)
    local h = math.rad(heading)
    -- Axes voulus du joueur (horizontaux dans le monde), exprimés dans le repère du véhicule
    local fx, fy = -math.sin(h), math.cos(h)
    local rx, ry = fy, -fx
    local forward = vector3(
        fx * vRight.x + fy * vRight.y,
        fx * vForward.x + fy * vForward.y,
        fx * vUp.x + fy * vUp.y
    )
    local rightZ = rx * vUp.x + ry * vUp.y
    local upZ = vUp.z
    -- Ordre de rotation GTA (Z puis X puis Y) : avant = (-sin z cos x, cos z cos x, sin x)
    local pitch = math.deg(math.asin(math.max(-1.0, math.min(1.0, forward.z))))
    local roll = math.deg(math.atan(-rightZ, upZ))
    local yaw = math.deg(math.atan(-forward.x, forward.y))
    return pitch, roll, yaw
end

---Accroche (ou raccroche) le joueur à son point sur le toit, droit et tourné selon son cap.
---@param ped integer
function VehicleRoof.place(ped)
    local vehicle = VehicleRoof.vehicle
    local offset = VehicleRoof.offset
    local pitch, roll, yaw = VehicleRoof.uprightRotation(vehicle, GetEntityHeading(vehicle) + VehicleRoof.heading)
    AttachEntityToEntity(ped, vehicle, 0, offset.x, offset.y, offset.z, pitch, roll, yaw,
        false, false, false, false, 2, true)
end
