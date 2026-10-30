---Missile Predator du mode Call of Duty : le joueur sort une tablette et pilote le missile, vu du dessus,
---jusqu'à l'impact. Le point visé est toujours au centre de l'image : la caméra regarde droit vers le sol
---et la souris la déplace à l'horizontale, sans la faire tourner. Le personnage reste sur place, vulnérable :
---sa mort met fin au vol. Le client annonce l'impact, le serveur applique les dégâts (cod_streaks.lua).
---@class CodPredatorModule
local CodPredator = PVP.define('CodPredator')
local Cod = PVP.use('Cod')
local Nui = PVP.use('Nui')
local PedUtils = PVP.use('PedUtils')
local Events = PVP.use('Events')

CodPredator.TABLET_MODEL = GetHashKey('prop_cs_tablet')
CodPredator.TABLET_BONE = 60309 -- main gauche
CodPredator.ANIM_DICT = 'amb@code_human_in_bus_passenger_idles@female@tablet@base'
CodPredator.ANIM_NAME = 'base'
CodPredator.ANIM_FLAGS = 49 -- en boucle, haut du corps seulement
CodPredator.MISSILE_MODEL = GetHashKey('w_lr_rpg_rocket')
CodPredator.TRAIL = 'proj_rpg_trail'
CodPredator.CAMERA_FILTER = 'scanline_cam_cheap'
CodPredator.WEAPON_UNARMED = GetHashKey('WEAPON_UNARMED')
CodPredator.CONTROL_LOOK_LR = 1
CodPredator.CONTROL_LOOK_UD = 2
CodPredator.CONTROL_BOOST = 24 -- clic gauche
CodPredator.CONTROL_MOVE_LR = 30
CodPredator.CONTROL_MOVE_UD = 31 -- -1 = avancer
-- Pendant le vol : ni déplacement, ni tir, ni changement d'arme
CodPredator.LOCKED_CONTROLS = { 1, 2, 3, 4, 5, 6, 12, 13, 14, 15, 16, 17, 21, 22, 23, 24, 25, 30, 31, 32, 33, 34, 35, 37, 44, 45, 75, 140, 141, 142, 257, 263, 264 }
CodPredator.PROBE_FLAGS = 1 + 2 + 4 + 8 + 16 -- carte, véhicules, personnages, objets
CodPredator.NOSE = 1.5 -- m devant le missile pour détecter le contact
CodPredator.LOST_TIME = 500 -- ms de neige à l'écran après l'impact
CodPredator.STATUS_INTERVAL = 100 -- ms entre deux envois de l'altitude au HUD
CodPredator.MARKER_SCALE = 0.03 -- taille des cercles sur les joueurs, en proportion de l'altitude
CodPredator.MARKER_MIN = 1.2
CodPredator.ENEMY_COLOR = { 255, 90, 60 }

---@type table|nil vol en cours : tablet, weapon, missile, cam, coords, yaw, nextStatus
CodPredator.flight = nil

---@return boolean
function CodPredator.isActive()
    return CodPredator.flight ~= nil
end

---Lancé par le serveur : la série a déjà été retirée au joueur.
function CodPredator.launch()
    if CodPredator.flight then return end
    local flight = {}
    CodPredator.flight = flight
    CreateThread(function()
        CodPredator.openTablet(flight)
        if CodPredator.flight ~= flight then return end
        CodPredator.startFlight(flight)
        while CodPredator.flight == flight do
            CodPredator.lockControls()
            local impact = CodPredator.advance(flight)
            if impact then return CodPredator.finish(flight, impact) end
            Wait(0)
        end
    end)
end

function CodPredator.lockControls()
    for _, control in ipairs(CodPredator.LOCKED_CONTROLS) do DisableControlAction(0, control, true) end
end

---@param flight table
---@param duration integer ms
function CodPredator.holdControls(flight, duration)
    local untilAt = GetGameTimer() + duration
    while CodPredator.flight == flight and GetGameTimer() < untilAt do
        CodPredator.lockControls()
        Wait(0)
    end
end

-- ---------------------------------------------------------------------------
-- Tablette
-- ---------------------------------------------------------------------------

---Le personnage range son arme et sort la tablette : l'écran monte en même temps (HUD), puis couvre l'image.
---@param flight table
function CodPredator.openTablet(flight)
    local ped = PlayerPedId()
    local seconds = Config.Cod.predator.tablet
    flight.weapon = GetSelectedPedWeapon(ped)
    SetCurrentPedWeapon(ped, CodPredator.WEAPON_UNARMED, true)
    PlaySoundFrontend(-1, 'Menu_Accept', 'Phone_SoundSet_Default', true)
    Nui.send('codPredator', { state = 'opening', seconds = seconds })

    if PedUtils.loadModel(CodPredator.TABLET_MODEL) and CodPredator.flight == flight then
        local coords = GetEntityCoords(ped)
        flight.tablet = CreateObject(CodPredator.TABLET_MODEL, coords.x, coords.y, coords.z, true, true, false)
        AttachEntityToEntity(flight.tablet, ped, GetPedBoneIndex(ped, CodPredator.TABLET_BONE),
            0.03, 0.002, 0.0, 10.0, 160.0, 0.0, true, true, false, true, 1, true)
        SetModelAsNoLongerNeeded(CodPredator.TABLET_MODEL)
    end
    RequestAnimDict(CodPredator.ANIM_DICT)
    local timeout = GetGameTimer() + 2000
    while not HasAnimDictLoaded(CodPredator.ANIM_DICT) and GetGameTimer() < timeout do
        CodPredator.lockControls()
        Wait(0)
    end
    if CodPredator.flight == flight then
        TaskPlayAnim(ped, CodPredator.ANIM_DICT, CodPredator.ANIM_NAME, 8.0, -8.0, -1, CodPredator.ANIM_FLAGS, 0.0, false, false, false)
    end
    CodPredator.holdControls(flight, seconds * 1000)
end

-- ---------------------------------------------------------------------------
-- Vol
-- ---------------------------------------------------------------------------

---Départ au-dessus du milieu de la carte, le haut de l'image dans la direction où regardait le joueur.
---@param flight table
function CodPredator.startFlight(flight)
    local loaded = PedUtils.loadModel(CodPredator.MISSILE_MODEL)
    if CodPredator.flight ~= flight then return end

    local settings = Config.Cod.predator
    local center = Cod.match.arena.center
    flight.coords = vector3(center.x, center.y, center.z + settings.height)
    flight.yaw = GetGameplayCamRot(2).z
    flight.nextStatus = 0

    if loaded then
        local coords = flight.coords
        flight.missile = CreateObject(CodPredator.MISSILE_MODEL, coords.x, coords.y, coords.z, true, true, false)
        SetEntityCollision(flight.missile, false, false)
        SetEntityHasGravity(flight.missile, false)
        SetEntityRotation(flight.missile, -90.0, 0.0, flight.yaw, 2, true)
        SetModelAsNoLongerNeeded(CodPredator.MISSILE_MODEL)
        RequestNamedPtfxAsset('core')
        UseParticleFxAssetNextCall('core')
        StartNetworkedParticleFxLoopedOnEntity(CodPredator.TRAIL, flight.missile, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.5, false, false, false)
    end

    flight.cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(flight.cam, flight.coords.x, flight.coords.y, flight.coords.z)
    SetCamRot(flight.cam, -90.0, 0.0, flight.yaw, 2)
    SetCamFov(flight.cam, settings.fov)
    SetCamActive(flight.cam, true)
    RenderScriptCams(true, false, 0, true, true)
    SetTimecycleModifier(CodPredator.CAMERA_FILTER)
    Nui.send('codPredator', { state = 'flying' })
end

---Une image de vol.
---@param flight table
---@return vector3|nil point d'impact
function CodPredator.advance(flight)
    local settings = Config.Cod.predator
    local center = Cod.match.arena.center
    local from = flight.coords
    local delta = math.max(GetFrameTime(), 0.001)
    local boost = IsDisabledControlPressed(0, CodPredator.CONTROL_BOOST)
    local speed = boost and settings.boostSpeed or settings.speed

    -- La souris donne un déplacement par image, les touches une vitesse
    local steer = math.max(from.z - center.z, settings.minSteerHeight) * settings.steer
    local right = GetDisabledControlNormal(0, CodPredator.CONTROL_LOOK_LR) * steer
        + GetDisabledControlNormal(0, CodPredator.CONTROL_MOVE_LR) * settings.steerKeys * delta
    local forward = -GetDisabledControlNormal(0, CodPredator.CONTROL_LOOK_UD) * steer
        - GetDisabledControlNormal(0, CodPredator.CONTROL_MOVE_UD) * settings.steerKeys * delta
    local yaw = math.rad(flight.yaw)
    local x = from.x + math.cos(yaw) * right - math.sin(yaw) * forward
    local y = from.y + math.sin(yaw) * right + math.cos(yaw) * forward

    local offset = vector2(x - center.x, y - center.y)
    local radius = Cod.match.arena.radius
    if #offset > radius then
        offset = offset / #offset * radius
        x, y = center.x + offset.x, center.y + offset.y
    end
    local to = vector3(x, y, from.z - speed * delta)

    local impact = CodPredator.findImpact(flight, from, to)
    if impact then return impact end

    flight.coords = to
    if flight.missile and DoesEntityExist(flight.missile) then
        SetEntityCoordsNoOffset(flight.missile, to.x, to.y, to.z, false, false, false)
        -- Pour que le mouvement reste fluide chez les autres joueurs entre deux synchronisations
        SetEntityVelocity(flight.missile, (to.x - from.x) / delta, (to.y - from.y) / delta, -speed)
    end
    SetCamCoord(flight.cam, to.x, to.y, to.z - CodPredator.NOSE)
    -- Le décor et ses collisions se chargent autour du point visé, pas de l'altitude du missile
    SetFocusPosAndVel(to.x, to.y, center.z, 0.0, 0.0, 0.0)
    RequestCollisionAtCoord(to.x, to.y, center.z)
    HideHudAndRadarThisFrame()
    CodPredator.drawPlayers(to.z)

    local now = GetGameTimer()
    if now >= flight.nextStatus then
        flight.nextStatus = now + CodPredator.STATUS_INTERVAL
        Nui.send('codPredatorStatus', { altitude = math.max(0, math.floor(to.z - center.z)), boost = boost })
    end
    return nil
end

---@param flight table
---@param from vector3
---@param to vector3
---@return vector3|nil décor ou joueur touché, eau, ou plancher de sécurité si le sol n'est pas chargé
function CodPredator.findImpact(flight, from, to)
    local ray = StartExpensiveSynchronousShapeTestLosProbe(from.x, from.y, from.z, to.x, to.y, to.z - CodPredator.NOSE,
        CodPredator.PROBE_FLAGS, flight.missile or 0, 7)
    local _, hit, coords = GetShapeTestResult(ray)
    if hit == 1 then return coords end

    local inWater, water = GetWaterHeight(to.x, to.y, to.z)
    if inWater and to.z <= water then return vector3(to.x, to.y, water) end

    local floor = Cod.match.arena.center.z - Config.Cod.predator.floor
    if to.z <= floor then return vector3(to.x, to.y, floor) end
    return nil
end

---Cercle au sol sous chaque joueur vivant : bleu pour les coéquipiers, rouge pour les ennemis.
---@param z number hauteur du missile
function CodPredator.drawPlayers(z)
    local mates = {}
    for _, id in ipairs(Cod.mates) do mates[id] = true end
    local me = PlayerId()
    local altitude = z - Cod.match.arena.center.z
    local size = math.max(altitude * CodPredator.MARKER_SCALE, CodPredator.MARKER_MIN)
    for _, player in ipairs(GetActivePlayers()) do
        local ped = GetPlayerPed(player)
        if player ~= me and not IsPedDeadOrDying(ped, true) then
            local coords = GetEntityCoords(ped)
            local color = mates[GetPlayerServerId(player)] and Cod.MATE_COLOR or CodPredator.ENEMY_COLOR
            DrawMarker(27, coords.x, coords.y, coords.z - 0.9, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, size, size, 1.0,
                color[1], color[2], color[3], 220, false, false, 2, false, nil, nil, false)
        end
    end
end

---Impact : l'écran passe à la neige, puis retour au personnage.
---@param flight table
---@param impact vector3
function CodPredator.finish(flight, impact)
    CodPredator.deleteEntity(flight, 'missile')
    Nui.send('codPredator', { state = 'lost' })
    TriggerServerEvent(Events.server.codPredatorImpact, { x = impact.x, y = impact.y, z = impact.z })
    CodPredator.holdControls(flight, CodPredator.LOST_TIME)
    if CodPredator.flight == flight then CodPredator.stop() end
end

---@param flight table
---@param key string
function CodPredator.deleteEntity(flight, key)
    local entity = flight[key]
    if entity and DoesEntityExist(entity) then DeleteObject(entity) end
    flight[key] = nil
end

---Fin du vol, quelle qu'en soit la raison (impact, mort, réapparition, fin de partie).
function CodPredator.stop()
    local flight = CodPredator.flight
    if not flight then return end
    CodPredator.flight = nil

    CodPredator.deleteEntity(flight, 'missile')
    CodPredator.deleteEntity(flight, 'tablet')
    if flight.cam then
        RenderScriptCams(false, false, 0, true, true)
        DestroyCam(flight.cam, false)
        ClearFocus()
        ClearTimecycleModifier()
    end
    local ped = PlayerPedId()
    StopAnimTask(ped, CodPredator.ANIM_DICT, CodPredator.ANIM_NAME, 2.0)
    RemoveAnimDict(CodPredator.ANIM_DICT)
    if flight.weapon and not IsPedDeadOrDying(ped, true) then SetCurrentPedWeapon(ped, flight.weapon, true) end
    Nui.send('codPredator', { state = false })
end
