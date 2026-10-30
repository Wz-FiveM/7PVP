---Séries pilotées à bord d'un appareil (hélico mitrailleur, AC-130) : depuis la tablette (CodTablet), le joueur vise
---à la souris pendant que l'appareil tourne seul autour de la carte (CodUnits). Le client envoie le point visé, le
---serveur vérifie la cadence et applique les dégâts (server/modules/cod/cod_units.lua).
---@class CodGunnerModule
local CodGunner = PVP.define('CodGunner')
local Cod = PVP.use('Cod')
local CodTablet = PVP.use('CodTablet')
local CodUnits = PVP.use('CodUnits')
local Events = PVP.use('Events')
local PedUtils = PVP.use('PedUtils')

CodGunner.CONTROL_LOOK_LR = 1
CodGunner.CONTROL_LOOK_UD = 2
CodGunner.CONTROL_FIRE = 24 -- clic gauche
CodGunner.CONTROL_SWITCH = 25 -- clic droit
CodGunner.LOOK_SPEED = 6.0 -- degrés par unité de souris
CodGunner.PITCH_MIN = -89.0
CodGunner.PITCH_MAX = -10.0
CodGunner.AIM_DISTANCE = 900.0
CodGunner.PROBE_FLAGS = 1 + 2 + 4 + 8 + 16 -- carte, véhicules, personnages, objets
CodGunner.CAMERA_DROP = 3.0 -- m sous l'appareil
CodGunner.RECOIL_TIME = 120 -- ms pour que le minigun revienne en place après un tir
CodGunner.FIRING_TIME = 150 -- ms après un tir pendant lesquelles des douilles sortent encore

---@param unit table unité de CodUnits, déjà enregistrée
function CodGunner.launch(unit)
    local help = { 'Souris : viser', 'Clic gauche : tirer' }
    if #unit.settings.weapons > 1 then help[#help + 1] = 'Clic droit : changer d\'arme' end
    CodTablet.open({
        title = unit.settings.label,
        help = help,
        onReady = function(session) CodGunner.fly(session, unit) end,
        onStop = function(session) CodGunner.removeGun(session, unit) end,
    })
end

---@param session table
---@param unit table
function CodGunner.fly(session, unit)
    local center = Cod.match.arena.center
    local coords = CodGunner.cameraCoords(unit)
    local toCenter = center - coords
    session.yaw = GetHeadingFromVector_2d(toCenter.x, toCenter.y)
    session.pitch = math.max(CodGunner.PITCH_MIN, math.min(CodGunner.PITCH_MAX, math.deg(math.atan(toCenter.z, #toCenter.xy))))
    session.weaponIndex = 1
    session.ready = {}
    CodTablet.startView(session, coords, session.pitch, session.yaw, unit.settings.fov, unit.settings.doorGun ~= nil)
    if unit.settings.doorGun then
        CreateThread(function() CodGunner.createGun(session, unit) end)
    end

    while CodTablet.session == session and CodUnits.units[unit.id] == unit do
        CodTablet.lockControls()
        CodGunner.frame(session, unit)
        Wait(0)
    end
    CodTablet.lose(session)
end

---@param unit table
---@return vector3
function CodGunner.cameraCoords(unit)
    local coords = CodUnits.position(unit, GetGameTimer())
    return vector3(coords.x, coords.y, coords.z - CodGunner.CAMERA_DROP)
end

---Minigun au premier plan, vu par le seul pilote.
---@param session table
---@param unit table
function CodGunner.createGun(session, unit)
    local settings = unit.settings.doorGun
    local model = GetHashKey(settings.model)
    if not PedUtils.loadModel(model) or CodTablet.session ~= session then return end
    local coords = CodGunner.cameraCoords(unit)
    local gun = CreateObject(model, coords.x, coords.y, coords.z, false, false, false)
    SetModelAsNoLongerNeeded(model)
    SetEntityCollision(gun, false, false)
    FreezeEntityPosition(gun, true)
    local bone = GetEntityBoneIndexByName(gun, CodUnits.MUZZLE_BONE)
    session.gunBarrel = bone == -1 and settings.barrel
        or #GetOffsetFromEntityGivenWorldCoords(gun, GetWorldPositionOfEntityBone(gun, bone))
    session.gun = gun
end

---@param session table
---@param unit table
function CodGunner.removeGun(session, unit)
    unit.gunMuzzle = nil
    if session.gun and DoesEntityExist(session.gun) then DeleteEntity(session.gun) end
    session.gun = nil
end

---Replace le minigun devant la caméra, le canon dans l'axe du regard, et retient sa bouche pour les tirs (CodUnits).
---@param session table
---@param unit table
---@param coords vector3 caméra
---@param now integer
function CodGunner.placeGun(session, unit, coords, now)
    local settings = unit.settings.doorGun
    local pitch, yaw = math.rad(session.pitch), math.rad(session.yaw)
    local forward = CodGunner.direction(session)
    local right = vector3(math.cos(yaw), math.sin(yaw), 0.0)
    local up = vector3(math.sin(yaw) * math.sin(pitch), -math.cos(yaw) * math.sin(pitch), math.cos(pitch))

    local kick = settings.kick * math.max(0.0, 1.0 - (now - (session.lastShot or 0)) / CodGunner.RECOIL_TIME)
    local jitter = (math.random() - 0.5) * kick
    local position = coords + forward * (settings.forward - kick) + right * (settings.right + jitter) + up * (settings.up + jitter)
    SetEntityCoordsNoOffset(session.gun, position.x, position.y, position.z, false, false, false)
    SetEntityRotation(session.gun, 0.0, -session.pitch, session.yaw - CodUnits.BARREL_YAW, 2, false)
    unit.gunMuzzle = position + forward * session.gunBarrel
end

---@param session table
---@param unit table
function CodGunner.frame(session, unit)
    local now = GetGameTimer()
    local coords = CodGunner.cameraCoords(unit)
    if unit.entity and DoesEntityExist(unit.entity) then SetEntityLocallyInvisible(unit.entity) end

    session.yaw = session.yaw - GetDisabledControlNormal(0, CodGunner.CONTROL_LOOK_LR) * CodGunner.LOOK_SPEED
    session.pitch = session.pitch - GetDisabledControlNormal(0, CodGunner.CONTROL_LOOK_UD) * CodGunner.LOOK_SPEED
    session.pitch = math.max(CodGunner.PITCH_MIN, math.min(CodGunner.PITCH_MAX, session.pitch))
    SetCamCoord(session.cam, coords.x, coords.y, coords.z)
    SetCamRot(session.cam, session.pitch, 0.0, session.yaw, 2)
    if session.gun then CodGunner.placeGun(session, unit, coords, now) end

    local aim = CodGunner.aimPoint(session, coords, unit)
    CodTablet.frame(coords, aim)

    local weapons = unit.settings.weapons
    if #weapons > 1 and IsDisabledControlJustPressed(0, CodGunner.CONTROL_SWITCH) then
        session.weaponIndex = session.weaponIndex % #weapons + 1
    end
    local weapon = weapons[session.weaponIndex]
    local readyAt = session.ready[session.weaponIndex] or 0
    if now >= readyAt and IsDisabledControlPressed(0, CodGunner.CONTROL_FIRE) then
        readyAt = now + weapon.cooldown
        session.ready[session.weaponIndex] = readyAt
        session.lastShot = now
        TriggerServerEvent(Events.server.codPilotFire, unit.id, session.weaponIndex, { x = aim.x, y = aim.y, z = aim.z })
    end

    CodTablet.sendStatus(session, {
        weapon = weapon.label,
        ready = 1 - math.max(0, readyAt - now) / weapon.cooldown,
        remaining = math.max(0, math.ceil(unit.remaining - (now - unit.born) / 1000 + unit.elapsed)),
        firing = unit.settings.doorGun ~= nil and now - (session.lastShot or 0) < CodGunner.FIRING_TIME,
    })
end

---@param session table
---@return vector3 direction du regard
function CodGunner.direction(session)
    local pitch, yaw = math.rad(session.pitch), math.rad(session.yaw)
    return vector3(-math.sin(yaw) * math.cos(pitch), math.cos(yaw) * math.cos(pitch), math.sin(pitch))
end

---@param session table
---@param from vector3
---@param unit table
---@return vector3 point du décor au centre de l'image (à la hauteur du milieu de la carte si rien n'est touché)
function CodGunner.aimPoint(session, from, unit)
    local direction = CodGunner.direction(session)
    local to = from + direction * CodGunner.AIM_DISTANCE
    local ray = StartExpensiveSynchronousShapeTestLosProbe(from.x, from.y, from.z, to.x, to.y, to.z, CodGunner.PROBE_FLAGS, unit.entity or 0, 7)
    local _, hit, coords = GetShapeTestResult(ray)
    if hit == 1 then return coords end
    local drop = (from.z - Cod.match.arena.center.z) / math.max(-direction.z, 0.01)
    return from + direction * drop
end
