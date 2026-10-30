---Tablette des séries pilotées du mode Call of Duty (missile Predator, hélico mitrailleur, AC-130) : le personnage
---range son arme et la sort, l'écran monte (HUD) puis l'image passe à une caméra. Le personnage reste sur place,
---vulnérable : sa mort met fin à la séance.
---@class CodTabletModule
local CodTablet = PVP.define('CodTablet')
local Cod = PVP.use('Cod')
local Nui = PVP.use('Nui')
local PedUtils = PVP.use('PedUtils')

CodTablet.MODEL = GetHashKey('prop_cs_tablet')
CodTablet.BONE = 60309 -- main gauche
CodTablet.ANIM_DICT = 'amb@code_human_in_bus_passenger_idles@female@tablet@base'
CodTablet.ANIM_NAME = 'base'
CodTablet.ANIM_FLAGS = 49 -- en boucle, haut du corps seulement
CodTablet.CAMERA_FILTER = 'scanline_cam_cheap'
CodTablet.WEAPON_UNARMED = GetHashKey('WEAPON_UNARMED')
-- Pendant la séance : ni déplacement, ni tir, ni changement d'arme
CodTablet.LOCKED_CONTROLS = { 1, 2, 3, 4, 5, 6, 12, 13, 14, 15, 16, 17, 21, 22, 23, 24, 25, 30, 31, 32, 33, 34, 35, 37, 44, 45, 75, 140, 141, 142, 257, 263, 264 }
CodTablet.LOST_TIME = 500 -- ms de neige à l'écran à la fin
CodTablet.STATUS_INTERVAL = 100 -- ms entre deux envois de l'état au HUD
CodTablet.MARKER_SCALE = 0.03 -- taille des cercles sur les joueurs, en proportion de l'altitude
CodTablet.MARKER_MIN = 1.2
CodTablet.ENEMY_COLOR = { 255, 90, 60 }

---@type table|nil séance en cours : weapon, tablet, cam, onStop, nextStatus
CodTablet.session = nil

---@return boolean
function CodTablet.isActive()
    return CodTablet.session ~= nil
end

---@param options { title: string, help: string[], onReady: fun(session: table), onStop: fun(session: table)|nil }
function CodTablet.open(options)
    if CodTablet.session then return end
    local session = { onStop = options.onStop, nextStatus = 0 }
    CodTablet.session = session
    CreateThread(function()
        CodTablet.takeOut(session, options)
        if CodTablet.session == session then options.onReady(session) end
    end)
end

function CodTablet.lockControls()
    for _, control in ipairs(CodTablet.LOCKED_CONTROLS) do DisableControlAction(0, control, true) end
end

---@param session table
---@param duration integer ms
function CodTablet.hold(session, duration)
    local untilAt = GetGameTimer() + duration
    while CodTablet.session == session and GetGameTimer() < untilAt do
        CodTablet.lockControls()
        Wait(0)
    end
end

---@param session table
---@param options table
function CodTablet.takeOut(session, options)
    local ped = PlayerPedId()
    local seconds = Config.Cod.tabletTime
    session.weapon = GetSelectedPedWeapon(ped)
    SetCurrentPedWeapon(ped, CodTablet.WEAPON_UNARMED, true)
    PlaySoundFrontend(-1, 'Menu_Accept', 'Phone_SoundSet_Default', true)
    Nui.send('codTablet', { state = 'opening', seconds = seconds, title = options.title, help = options.help })

    if PedUtils.loadModel(CodTablet.MODEL) and CodTablet.session == session then
        local coords = GetEntityCoords(ped)
        session.tablet = CreateObject(CodTablet.MODEL, coords.x, coords.y, coords.z, true, true, false)
        AttachEntityToEntity(session.tablet, ped, GetPedBoneIndex(ped, CodTablet.BONE),
            0.03, 0.002, 0.0, 10.0, 160.0, 0.0, true, true, false, true, 1, true)
        SetModelAsNoLongerNeeded(CodTablet.MODEL)
    end
    RequestAnimDict(CodTablet.ANIM_DICT)
    local timeout = GetGameTimer() + 2000
    while not HasAnimDictLoaded(CodTablet.ANIM_DICT) and GetGameTimer() < timeout do
        CodTablet.lockControls()
        Wait(0)
    end
    if CodTablet.session == session then
        TaskPlayAnim(ped, CodTablet.ANIM_DICT, CodTablet.ANIM_NAME, 8.0, -8.0, -1, CodTablet.ANIM_FLAGS, 0.0, false, false, false)
    end
    CodTablet.hold(session, seconds * 1000)
end

---L'écran de la tablette couvre l'image : on passe à la caméra.
---@param session table
---@param coords vector3
---@param pitch number
---@param yaw number
---@param fov number
function CodTablet.startView(session, coords, pitch, yaw, fov)
    session.cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(session.cam, coords.x, coords.y, coords.z)
    SetCamRot(session.cam, pitch, 0.0, yaw, 2)
    SetCamFov(session.cam, fov)
    SetCamActive(session.cam, true)
    RenderScriptCams(true, false, 0, true, true)
    SetTimecycleModifier(CodTablet.CAMERA_FILTER)
    Nui.send('codTablet', { state = 'flying' })
end

---À chaque image de vol : le décor et ses collisions se chargent autour du point regardé, pas de la caméra.
---@param coords vector3 caméra
---@param focus vector3 point regardé au sol
function CodTablet.frame(coords, focus)
    SetFocusPosAndVel(focus.x, focus.y, focus.z, 0.0, 0.0, 0.0)
    RequestCollisionAtCoord(focus.x, focus.y, focus.z)
    HideHudAndRadarThisFrame()
    CodTablet.drawPlayers(coords.z - Cod.match.arena.center.z)
end

---@param session table
---@param status table altitude, boost, weapon, ready, remaining
function CodTablet.sendStatus(session, status)
    local now = GetGameTimer()
    if now < session.nextStatus then return end
    session.nextStatus = now + CodTablet.STATUS_INTERVAL
    Nui.send('codTabletStatus', status)
end

---Cercle au sol sous chaque joueur vivant : bleu pour les coéquipiers, rouge pour les ennemis.
---@param altitude number
function CodTablet.drawPlayers(altitude)
    local mates = {}
    for _, id in ipairs(Cod.mates) do mates[id] = true end
    local me = PlayerId()
    local size = math.max(altitude * CodTablet.MARKER_SCALE, CodTablet.MARKER_MIN)
    for _, player in ipairs(GetActivePlayers()) do
        local ped = GetPlayerPed(player)
        if player ~= me and not IsPedDeadOrDying(ped, true) then
            local coords = GetEntityCoords(ped)
            local color = mates[GetPlayerServerId(player)] and Cod.MATE_COLOR or CodTablet.ENEMY_COLOR
            DrawMarker(27, coords.x, coords.y, coords.z - 0.9, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, size, size, 1.0,
                color[1], color[2], color[3], 220, false, false, 2, false, nil, nil, false)
        end
    end
end

---Fin normale : l'écran passe à la neige, puis retour au personnage.
---@param session table
function CodTablet.lose(session)
    if CodTablet.session ~= session then return end
    Nui.send('codTablet', { state = 'lost' })
    CodTablet.hold(session, CodTablet.LOST_TIME)
    if CodTablet.session == session then CodTablet.stop() end
end

---Fin immédiate, quelle qu'en soit la raison (mort, réapparition, fin de partie).
function CodTablet.stop()
    local session = CodTablet.session
    if not session then return end
    CodTablet.session = nil

    if session.onStop then session.onStop(session) end
    if session.tablet and DoesEntityExist(session.tablet) then DeleteObject(session.tablet) end
    if session.cam then
        RenderScriptCams(false, false, 0, true, true)
        DestroyCam(session.cam, false)
        ClearFocus()
        ClearTimecycleModifier()
    end
    local ped = PlayerPedId()
    StopAnimTask(ped, CodTablet.ANIM_DICT, CodTablet.ANIM_NAME, 2.0)
    RemoveAnimDict(CodTablet.ANIM_DICT)
    if session.weapon and not IsPedDeadOrDying(ped, true) then SetCurrentPedWeapon(ped, session.weapon, true) end
    Nui.send('codTablet', { state = false })
end
