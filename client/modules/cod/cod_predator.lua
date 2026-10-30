---Missile Predator du mode Call of Duty : piloté depuis la tablette (CodTablet), vu du dessus, jusqu'à l'impact.
---Le point visé est toujours au centre de l'image : la caméra regarde droit vers le sol et la souris la déplace à
---l'horizontale, sans la faire tourner. Le client annonce l'impact, le serveur applique les dégâts (cod_streaks.lua).
---@class CodPredatorModule
local CodPredator = PVP.define('CodPredator')
local Cod = PVP.use('Cod')
local CodTablet = PVP.use('CodTablet')
local PedUtils = PVP.use('PedUtils')
local Events = PVP.use('Events')

CodPredator.MISSILE_MODEL = GetHashKey('w_lr_rpg_rocket')
CodPredator.TRAIL = 'proj_rpg_trail'
CodPredator.CONTROL_LOOK_LR = 1
CodPredator.CONTROL_LOOK_UD = 2
CodPredator.CONTROL_BOOST = 24 -- clic gauche
CodPredator.CONTROL_MOVE_LR = 30
CodPredator.CONTROL_MOVE_UD = 31 -- -1 = avancer
CodPredator.PROBE_FLAGS = 1 + 2 + 4 + 8 + 16 -- carte, véhicules, personnages, objets
CodPredator.NOSE = 1.5 -- m devant le missile pour détecter le contact

---Lancé par le serveur : la série a déjà été retirée au joueur.
function CodPredator.launch()
    CodTablet.open({
        title = 'Missile Predator',
        help = { 'Souris : diriger', 'Clic gauche : accélérer' },
        onReady = CodPredator.fly,
        onStop = CodPredator.deleteMissile,
    })
end

---@param session table
function CodPredator.deleteMissile(session)
    if session.missile and DoesEntityExist(session.missile) then DeleteObject(session.missile) end
    session.missile = nil
end

---@param session table
function CodPredator.fly(session)
    CodPredator.start(session)
    while CodTablet.session == session do
        CodTablet.lockControls()
        local impact = CodPredator.advance(session)
        if impact then
            CodPredator.deleteMissile(session)
            TriggerServerEvent(Events.server.codPredatorImpact, { x = impact.x, y = impact.y, z = impact.z })
            return CodTablet.lose(session)
        end
        Wait(0)
    end
end

---Départ au-dessus du milieu de la carte, le haut de l'image dans la direction où regardait le joueur.
---@param session table
function CodPredator.start(session)
    local loaded = PedUtils.loadModel(CodPredator.MISSILE_MODEL)
    if CodTablet.session ~= session then return end

    local settings = Config.Cod.predator
    local center = Cod.match.arena.center
    session.coords = vector3(center.x, center.y, center.z + settings.height)
    session.yaw = GetGameplayCamRot(2).z

    if loaded then
        local coords = session.coords
        session.missile = CreateObject(CodPredator.MISSILE_MODEL, coords.x, coords.y, coords.z, true, true, false)
        SetEntityCollision(session.missile, false, false)
        SetEntityHasGravity(session.missile, false)
        SetEntityRotation(session.missile, -90.0, 0.0, session.yaw, 2, true)
        SetModelAsNoLongerNeeded(CodPredator.MISSILE_MODEL)
        RequestNamedPtfxAsset('core')
        UseParticleFxAssetNextCall('core')
        StartNetworkedParticleFxLoopedOnEntity(CodPredator.TRAIL, session.missile, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.5, false, false, false)
    end
    CodTablet.startView(session, session.coords, -90.0, session.yaw, settings.fov)
end

---Une image de vol.
---@param session table
---@return vector3|nil point d'impact
function CodPredator.advance(session)
    local settings = Config.Cod.predator
    local center = Cod.match.arena.center
    local from = session.coords
    local delta = math.max(GetFrameTime(), 0.001)
    local boost = IsDisabledControlPressed(0, CodPredator.CONTROL_BOOST)
    local speed = boost and settings.boostSpeed or settings.speed

    -- La souris donne un déplacement par image, les touches une vitesse
    local steer = math.max(from.z - center.z, settings.minSteerHeight) * settings.steer
    local right = GetDisabledControlNormal(0, CodPredator.CONTROL_LOOK_LR) * steer
        + GetDisabledControlNormal(0, CodPredator.CONTROL_MOVE_LR) * settings.steerKeys * delta
    local forward = -GetDisabledControlNormal(0, CodPredator.CONTROL_LOOK_UD) * steer
        - GetDisabledControlNormal(0, CodPredator.CONTROL_MOVE_UD) * settings.steerKeys * delta
    local yaw = math.rad(session.yaw)
    local x = from.x + math.cos(yaw) * right - math.sin(yaw) * forward
    local y = from.y + math.sin(yaw) * right + math.cos(yaw) * forward

    local offset = vector2(x - center.x, y - center.y)
    local radius = Cod.match.arena.radius
    if #offset > radius then
        offset = offset / #offset * radius
        x, y = center.x + offset.x, center.y + offset.y
    end
    local to = vector3(x, y, from.z - speed * delta)

    local impact = CodPredator.findImpact(session, from, to)
    if impact then return impact end

    session.coords = to
    if session.missile and DoesEntityExist(session.missile) then
        SetEntityCoordsNoOffset(session.missile, to.x, to.y, to.z, false, false, false)
        -- Pour que le mouvement reste fluide chez les autres joueurs entre deux synchronisations
        SetEntityVelocity(session.missile, (to.x - from.x) / delta, (to.y - from.y) / delta, -speed)
    end
    SetCamCoord(session.cam, to.x, to.y, to.z - CodPredator.NOSE)
    CodTablet.frame(to, vector3(to.x, to.y, center.z))
    CodTablet.sendStatus(session, { altitude = math.max(0, math.floor(to.z - center.z)), boost = boost })
    return nil
end

---@param session table
---@param from vector3
---@param to vector3
---@return vector3|nil décor ou joueur touché, eau, ou plancher de sécurité si le sol n'est pas chargé
function CodPredator.findImpact(session, from, to)
    local ray = StartExpensiveSynchronousShapeTestLosProbe(from.x, from.y, from.z, to.x, to.y, to.z - CodPredator.NOSE,
        CodPredator.PROBE_FLAGS, session.missile or 0, 7)
    local _, hit, coords = GetShapeTestResult(ray)
    if hit == 1 then return coords end

    local inWater, water = GetWaterHeight(to.x, to.y, to.z)
    if inWater and to.z <= water then return vector3(to.x, to.y, water) end

    local floor = Cod.match.arena.center.z - Config.Cod.predator.floor
    if to.z <= floor then return vector3(to.x, to.y, floor) end
    return nil
end
