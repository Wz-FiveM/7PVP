---Missile Predator du mode Call of Duty : piloté depuis la tablette (CodTablet), vu du dessus, jusqu'à l'impact.
---Le point visé est toujours au centre de l'image : la caméra regarde droit vers le sol et la souris la déplace à
---l'horizontale, sans la faire tourner. Le client annonce l'impact, le serveur applique les dégâts (cod_streaks.lua).
---Aucune entité réseau : le pilote envoie sa position et chaque autre client affiche sa copie locale du missile.
---@class CodPredatorModule
local CodPredator = PVP.define('CodPredator')
local Cod = PVP.use('Cod')
local CodEffects = PVP.use('CodEffects')
local CodTablet = PVP.use('CodTablet')
local PedUtils = PVP.use('PedUtils')
local Events = PVP.use('Events')

CodPredator.MISSILE_MODEL = GetHashKey('w_lr_rpg_rocket')
CodPredator.TRAIL = 'proj_rpg_trail'
CodPredator.TRAIL_SCALE = 3.0
CodPredator.CONTROL_LOOK_LR = 1
CodPredator.CONTROL_LOOK_UD = 2
CodPredator.CONTROL_BOOST = 24 -- clic gauche
CodPredator.CONTROL_MOVE_LR = 30
CodPredator.CONTROL_MOVE_UD = 31 -- -1 = avancer
CodPredator.PROBE_FLAGS = 1 + 2 + 4 + 8 + 16 -- carte, véhicules, personnages, objets
CodPredator.NOSE = 1.5 -- m devant le missile pour détecter le contact
CodPredator.STREAM_INTERVAL = 100 -- ms entre deux envois de la position du missile
CodPredator.STREAM_TIMEOUT = 600 -- ms sans nouvelle position avant de retirer le missile (impact, pilote mort)
CodPredator.LOD_DISTANCE = 1000 -- m : le modèle est petit, le jeu le masquerait de loin
CodPredator.ASSET_TIMEOUT = 2000 -- ms
CodPredator.STREAK_LENGTH = 25.0 -- m de la traînée lumineuse au-dessus du missile, visible de loin
CodPredator.LIGHT_RANGE = 40.0
CodPredator.LIGHT_INTENSITY = 6.0

---@type table<integer, table> pilote -> missile affiché ici : from, to, at, entity, trail
CodPredator.missiles = {}

function CodPredator.init()
    CodEffects.EXTERNAL.predatorMove = CodPredator.onMove
end

---Lancé par le serveur : la série a déjà été retirée au joueur.
function CodPredator.launch()
    CodTablet.open({
        title = 'Missile Predator',
        help = { 'Souris : diriger', 'Clic gauche : accélérer' },
        onReady = CodPredator.fly,
    })
end

---@param session table
function CodPredator.fly(session)
    CodPredator.start(session)
    while CodTablet.session == session do
        CodTablet.lockControls()
        local impact = CodPredator.advance(session)
        if impact then
            TriggerServerEvent(Events.server.codPredatorImpact, { x = impact.x, y = impact.y, z = impact.z })
            return CodTablet.lose(session)
        end
        Wait(0)
    end
end

---Départ au-dessus du milieu de la carte, le haut de l'image dans la direction où regardait le joueur.
---@param session table
function CodPredator.start(session)
    local settings = Config.Cod.predator
    local center = Cod.match.arena.center
    session.coords = vector3(center.x, center.y, center.z + settings.height)
    session.yaw = GetGameplayCamRot(2).z
    session.nextStream = 0
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

    local impact = CodPredator.findImpact(from, to)
    if impact then return impact end

    session.coords = to
    local now = GetGameTimer()
    if now >= session.nextStream then
        session.nextStream = now + CodPredator.STREAM_INTERVAL
        TriggerServerEvent(Events.server.codPredatorMove, { x = to.x, y = to.y, z = to.z })
    end
    SetCamCoord(session.cam, to.x, to.y, to.z - CodPredator.NOSE)
    CodTablet.frame(to, vector3(to.x, to.y, center.z))
    local altitude = math.max(0, to.z - center.z)
    CodTablet.sendStatus(session, {
        altitude = math.floor(altitude),
        boost = boost,
        speed = math.floor(speed),
        impact = altitude / speed,
        heading = session.yaw,
        x = to.x,
        y = to.y,
    })
    return nil
end

---@param from vector3
---@param to vector3
---@return vector3|nil décor ou joueur touché, eau, ou plancher de sécurité si le sol n'est pas chargé
function CodPredator.findImpact(from, to)
    local ray = StartExpensiveSynchronousShapeTestLosProbe(from.x, from.y, from.z, to.x, to.y, to.z - CodPredator.NOSE,
        CodPredator.PROBE_FLAGS, PlayerPedId(), 7)
    local _, hit, coords = GetShapeTestResult(ray)
    if hit == 1 then return coords end

    local inWater, water = GetWaterHeight(to.x, to.y, to.z)
    if inWater and to.z <= water then return vector3(to.x, to.y, water) end

    local floor = Cod.match.arena.center.z - Config.Cod.predator.floor
    if to.z <= floor then return vector3(to.x, to.y, floor) end
    return nil
end

-- ---------------------------------------------------------------------------
-- Missile vu par les autres joueurs
-- ---------------------------------------------------------------------------

---@param data { pilot: integer, x: number, y: number, z: number }
function CodPredator.onMove(data)
    local now = GetGameTimer()
    local to = vector3(data.x, data.y, data.z)
    local missile = CodPredator.missiles[data.pilot]
    if missile then
        missile.from = CodPredator.position(missile, now)
        missile.to = to
        missile.at = now
        return
    end
    missile = { from = to, to = to, at = now }
    CodPredator.missiles[data.pilot] = missile
    CreateThread(function()
        CodPredator.createModel(data.pilot, missile)
    end)
end

---@param pilot integer
---@param missile table
function CodPredator.createModel(pilot, missile)
    if not PedUtils.loadModel(CodPredator.MISSILE_MODEL) or CodPredator.missiles[pilot] ~= missile then return end
    local coords = missile.to
    missile.entity = CreateObject(CodPredator.MISSILE_MODEL, coords.x, coords.y, coords.z, false, false, false)
    SetEntityCollision(missile.entity, false, false)
    SetEntityHasGravity(missile.entity, false)
    SetEntityRotation(missile.entity, -90.0, 0.0, 0.0, 2, true)
    SetEntityLodDist(missile.entity, CodPredator.LOD_DISTANCE)
    SetModelAsNoLongerNeeded(CodPredator.MISSILE_MODEL)

    RequestNamedPtfxAsset('core')
    local timeout = GetGameTimer() + CodPredator.ASSET_TIMEOUT
    while not HasNamedPtfxAssetLoaded('core') and GetGameTimer() < timeout do Wait(0) end
    if CodPredator.missiles[pilot] ~= missile or not HasNamedPtfxAssetLoaded('core') then return end
    UseParticleFxAssetNextCall('core')
    missile.trail = StartParticleFxLoopedOnEntity(CodPredator.TRAIL, missile.entity, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
        CodPredator.TRAIL_SCALE, false, false, false)
end

---@param missile table
---@param now integer
---@return vector3 position entre les deux derniers relevés
function CodPredator.position(missile, now)
    local progress = math.min((now - missile.at) / CodPredator.STREAM_INTERVAL, 1.0)
    return missile.from + (missile.to - missile.from) * progress
end

---@param now integer
function CodPredator.frame(now)
    for pilot, missile in pairs(CodPredator.missiles) do
        if now - missile.at > CodPredator.STREAM_TIMEOUT then
            CodPredator.remove(pilot, missile)
        else
            local coords = CodPredator.position(missile, now)
            if missile.entity then SetEntityCoordsNoOffset(missile.entity, coords.x, coords.y, coords.z, false, false, false) end
            DrawLine(coords.x, coords.y, coords.z, coords.x, coords.y, coords.z + CodPredator.STREAK_LENGTH, 255, 190, 120, 220)
            DrawLightWithRange(coords.x, coords.y, coords.z, 255, 170, 90, CodPredator.LIGHT_RANGE, CodPredator.LIGHT_INTENSITY)
        end
    end
end

---@param pilot integer
---@param missile table
function CodPredator.remove(pilot, missile)
    CodPredator.missiles[pilot] = nil
    if missile.trail then StopParticleFxLooped(missile.trail, false) end
    if missile.entity and DoesEntityExist(missile.entity) then DeleteEntity(missile.entity) end
end

function CodPredator.clear()
    for pilot, missile in pairs(CodPredator.missiles) do CodPredator.remove(pilot, missile) end
end
