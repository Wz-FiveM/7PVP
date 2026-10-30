---Choix du point d'un bombardement du mode Call of Duty : vue du dessus depuis la tablette (CodTablet), le point visé
---est au centre de l'image. Rien n'est lancé avant la confirmation : annuler (ou mourir) garde la série.
---@class CodStrikeMapModule
local CodStrikeMap = PVP.define('CodStrikeMap')
local Cod = PVP.use('Cod')
local CodTablet = PVP.use('CodTablet')
local Events = PVP.use('Events')

CodStrikeMap.CONTROL_LOOK_LR = 1
CodStrikeMap.CONTROL_LOOK_UD = 2
CodStrikeMap.CONTROL_CONFIRM = 24 -- clic gauche
CodStrikeMap.CONTROL_CANCEL = 25 -- clic droit
CodStrikeMap.CONTROL_MOVE_LR = 30
CodStrikeMap.CONTROL_MOVE_UD = 31 -- -1 = avancer
CodStrikeMap.CONTROL_TURN_LEFT = 14 -- molette
CodStrikeMap.CONTROL_TURN_RIGHT = 15
CodStrikeMap.GROUND_FLAGS = 1 + 16 -- carte, objets
CodStrikeMap.COLOR = { 255, 90, 60 }
-- Série -> ses réglages dans Config.Cod
CodStrikeMap.BOMBINGS = { precision = 'precision', stealth = 'stealth', harrier = 'harrierBombing' }

---@param streak { id: string, label: string }
function CodStrikeMap.open(streak)
    CodTablet.open({
        title = streak.label,
        help = { 'Souris : déplacer', 'Molette : tourner', 'Clic gauche : confirmer', 'Clic droit : annuler' },
        onReady = function(session)
            CodStrikeMap.run(session, Config.Cod[CodStrikeMap.BOMBINGS[streak.id]])
        end,
    })
end

---@param session table
---@param bombing table
function CodStrikeMap.run(session, bombing)
    local settings = Config.Cod.strikeMap
    local coords = GetEntityCoords(PlayerPedId())
    local top = Cod.match.arena.center.z + settings.height
    session.x, session.y = coords.x, coords.y
    session.yaw = GetGameplayCamRot(2).z
    session.heading = session.yaw
    CodTablet.startView(session, vector3(session.x, session.y, top), -90.0, session.yaw, settings.fov)

    while CodTablet.session == session do
        CodTablet.lockControls()
        CodStrikeMap.move(session)
        if IsDisabledControlJustPressed(0, CodStrikeMap.CONTROL_TURN_LEFT) then session.heading = session.heading + settings.turnStep end
        if IsDisabledControlJustPressed(0, CodStrikeMap.CONTROL_TURN_RIGHT) then session.heading = session.heading - settings.turnStep end

        local camera = vector3(session.x, session.y, top)
        SetCamCoord(session.cam, camera.x, camera.y, camera.z)
        local ground = CodStrikeMap.groundAt(camera)
        CodTablet.frame(camera, vector3(session.x, session.y, ground))
        CodStrikeMap.drawBombs(session, bombing, top, ground)
        CodTablet.sendStatus(session, {
            altitude = math.floor(settings.height),
            heading = session.heading,
            range = math.floor(camera.z - ground),
            x = session.x,
            y = session.y,
        })

        if IsDisabledControlJustPressed(0, CodStrikeMap.CONTROL_CANCEL) then return CodTablet.stop() end
        if IsDisabledControlJustPressed(0, CodStrikeMap.CONTROL_CONFIRM) then
            TriggerServerEvent(Events.server.codUseStreak, { x = session.x, y = session.y, z = ground, heading = session.heading })
            return CodTablet.lose(session)
        end
        Wait(0)
    end
end

---La souris donne un déplacement par image, les touches une vitesse.
---@param session table
function CodStrikeMap.move(session)
    local settings = Config.Cod.strikeMap
    local arena = Cod.match.arena
    local delta = math.max(GetFrameTime(), 0.001)
    local steer = settings.height * settings.steer
    local right = GetDisabledControlNormal(0, CodStrikeMap.CONTROL_LOOK_LR) * steer
        + GetDisabledControlNormal(0, CodStrikeMap.CONTROL_MOVE_LR) * settings.steerKeys * delta
    local forward = -GetDisabledControlNormal(0, CodStrikeMap.CONTROL_LOOK_UD) * steer
        - GetDisabledControlNormal(0, CodStrikeMap.CONTROL_MOVE_UD) * settings.steerKeys * delta
    local yaw = math.rad(session.yaw)
    local x = session.x + math.cos(yaw) * right - math.sin(yaw) * forward
    local y = session.y + math.sin(yaw) * right + math.cos(yaw) * forward

    local offset = vector2(x - arena.center.x, y - arena.center.y)
    if #offset > arena.radius then
        offset = offset / #offset * arena.radius
        x, y = arena.center.x + offset.x, arena.center.y + offset.y
    end
    session.x, session.y = x, y
end

---@param camera vector3
---@return number hauteur du sol ou du toit sous la caméra (milieu de la carte s'il n'est pas chargé)
function CodStrikeMap.groundAt(camera)
    local floor = Cod.match.arena.center.z - Config.Cod.predator.floor
    local ray = StartExpensiveSynchronousShapeTestLosProbe(camera.x, camera.y, camera.z, camera.x, camera.y, floor,
        CodStrikeMap.GROUND_FLAGS, PlayerPedId(), 7)
    local _, hit, coords = GetShapeTestResult(ray)
    return hit == 1 and coords.z or Cod.match.arena.center.z
end

---Un cercle par bombe, aux mêmes endroits que CodStreaks.bombLine côté serveur.
---@param session table
---@param bombing table
---@param top number hauteur de la caméra
---@param fallback number hauteur si le sol n'est pas chargé à cet endroit
function CodStrikeMap.drawBombs(session, bombing, top, fallback)
    local yaw = math.rad(session.heading)
    local forwardX, forwardY = -math.sin(yaw), math.cos(yaw)
    local size = bombing.radius * 2
    local color = CodStrikeMap.COLOR
    for index = 1, bombing.bombs do
        local along = bombing.length * ((index - 1) / math.max(bombing.bombs - 1, 1) - 0.5)
        local x, y = session.x + forwardX * along, session.y + forwardY * along
        local found, ground = GetGroundZFor_3dCoord(x, y, top, false)
        DrawMarker(27, x, y, (found and ground or fallback) + 0.2, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, size, size, 1.0,
            color[1], color[2], color[3], 150, false, false, 2, false, nil, nil, false)
    end
end
