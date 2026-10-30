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
CodTablet.CAMERA_FILTER = 'heliGunCam' -- l'image de la caméra de tir des hélicoptères du jeu
CodTablet.WEAPON_UNARMED = GetHashKey('WEAPON_UNARMED')
-- Pendant la séance : ni déplacement, ni tir, ni changement d'arme
CodTablet.LOCKED_CONTROLS = { 1, 2, 3, 4, 5, 6, 12, 13, 14, 15, 16, 17, 21, 22, 23, 24, 25, 30, 31, 32, 33, 34, 35, 37, 44, 45, 75, 140, 141, 142, 257, 263, 264 }
CodTablet.LOST_TIME = 500 -- ms de neige à l'écran à la fin
CodTablet.STATUS_INTERVAL = 100 -- ms entre deux envois de l'état au HUD
CodTablet.BOX_BODY = 1.0 -- m de part et d'autre du centre du personnage, pour son cadre
CodTablet.BOX_MIN = 0.012 -- demi-hauteur minimale du cadre à l'écran
CodTablet.BOX_RATIO = 0.7 -- largeur du cadre par rapport à sa hauteur
CodTablet.BOX_ARM = 0.4 -- longueur des coins, par rapport au cadre
CodTablet.BOX_LINE = 0.0018 -- épaisseur des coins à l'écran
CodTablet.ENEMY_COLOR = { 255, 90, 60 }
-- Losange au-dessus des joueurs en vue à bord, dessiné par-dessus le décor. Tailles en proportion de la hauteur d'écran
CodTablet.ICON_HEIGHT = 1.5 -- m au-dessus du centre du personnage
CodTablet.ICON_SIZE = 0.03
CodTablet.ICON_OUTLINE = 0.006
CodTablet.ICON_ROWS = 4 -- bandes de chaque côté de celle du milieu
CodTablet.ICON_OUTLINE_COLOR = { 0, 0, 0 }

---@type table|nil séance en cours : weapon, tablet, cam, onStop, nextStatus, clear
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
---@param clear boolean|nil vue à bord : ni filtre ni cadre de tablette, losanges sur les joueurs
function CodTablet.startView(session, coords, pitch, yaw, fov, clear)
    session.clear = clear
    session.cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(session.cam, coords.x, coords.y, coords.z)
    SetCamRot(session.cam, pitch, 0.0, yaw, 2)
    SetCamFov(session.cam, fov)
    SetCamActive(session.cam, true)
    RenderScriptCams(true, false, 0, true, true)
    if not clear then SetTimecycleModifier(CodTablet.CAMERA_FILTER) end
    Nui.send('codTablet', { state = 'flying', clear = clear == true })
end

---À chaque image de vol : le décor et ses collisions se chargent autour du point regardé, pas de la caméra.
---@param coords vector3 caméra
---@param focus vector3 point regardé au sol
function CodTablet.frame(coords, focus)
    SetFocusPosAndVel(focus.x, focus.y, focus.z, 0.0, 0.0, 0.0)
    RequestCollisionAtCoord(focus.x, focus.y, focus.z)
    HideHudAndRadarThisFrame()
    if CodTablet.session and CodTablet.session.clear then
        CodTablet.drawIcons()
    else
        CodTablet.drawPlayers()
    end
end

---@param session table
---@param status table voir CodTabletStatus (web/src/types/cod.ts)
function CodTablet.sendStatus(session, status)
    local now = GetGameTimer()
    if now < session.nextStatus then return end
    session.nextStatus = now + CodTablet.STATUS_INTERVAL
    Nui.send('codTabletStatus', status)
end

---Chaque joueur vivant : bleu pour les coéquipiers, rouge pour les ennemis.
---@param draw fun(coords: vector3, color: integer[])
function CodTablet.forEachPlayer(draw)
    local mates = {}
    for _, id in ipairs(Cod.mates) do mates[id] = true end
    local me = PlayerId()
    for _, player in ipairs(GetActivePlayers()) do
        local ped = GetPlayerPed(player)
        if player ~= me and not IsPedDeadOrDying(ped, true) then
            draw(GetEntityCoords(ped), mates[GetPlayerServerId(player)] and Cod.MATE_COLOR or CodTablet.ENEMY_COLOR)
        end
    end
end

---Cercle au sol sous chaque joueur.
---@param altitude number
function CodTablet.drawPlayers()
    local aspect = GetAspectRatio(false)
    CodTablet.forEachPlayer(function(coords, color)
        local visible, x, y = GetScreenCoordFromWorldCoord(coords.x, coords.y, coords.z)
        if not visible then return end
        local _, _, top = GetScreenCoordFromWorldCoord(coords.x, coords.y, coords.z + CodTablet.BOX_BODY)
        local halfHeight = math.max(math.abs(y - top), CodTablet.BOX_MIN)
        CodTablet.drawBox(x, y, halfHeight * CodTablet.BOX_RATIO / aspect, halfHeight, aspect, color)
    end)
end

---Cadre de ciblage : seulement ses quatre coins.
---@param x number centre, à l'écran
---@param y number
---@param halfWidth number
---@param halfHeight number
---@param aspect number
---@param color integer[]
function CodTablet.drawBox(x, y, halfWidth, halfHeight, aspect, color)
    local armX, armY = halfWidth * 2 * CodTablet.BOX_ARM, halfHeight * 2 * CodTablet.BOX_ARM
    local lineX, lineY = CodTablet.BOX_LINE / aspect, CodTablet.BOX_LINE
    for _, sideX in ipairs({ -1, 1 }) do
        for _, sideY in ipairs({ -1, 1 }) do
            local cornerX, cornerY = x + sideX * halfWidth, y + sideY * halfHeight
            DrawRect(cornerX - sideX * armX / 2, cornerY, armX, lineY, color[1], color[2], color[3], 235)
            DrawRect(cornerX, cornerY - sideY * armY / 2, lineX, armY, color[1], color[2], color[3], 235)
        end
    end
end

---Losange au-dessus de chaque joueur, de la même taille à l'écran quelle que soit la distance.
function CodTablet.drawIcons()
    local aspect = GetAspectRatio(false)
    CodTablet.forEachPlayer(function(coords, color)
        local visible, x, y = GetScreenCoordFromWorldCoord(coords.x, coords.y, coords.z + CodTablet.ICON_HEIGHT)
        if visible then
            CodTablet.drawDiamond(x, y, CodTablet.ICON_SIZE + CodTablet.ICON_OUTLINE, aspect, CodTablet.ICON_OUTLINE_COLOR)
            CodTablet.drawDiamond(x, y, CodTablet.ICON_SIZE, aspect, color)
        end
    end)
end

---Un losange fait de bandes horizontales : le jeu ne sait dessiner à l'écran que des rectangles droits sans texture.
---@param x number
---@param y number
---@param size number hauteur, en proportion de celle de l'écran
---@param aspect number
---@param color integer[]
function CodTablet.drawDiamond(x, y, size, aspect, color)
    local rows = CodTablet.ICON_ROWS
    local rowHeight = size / (rows * 2 + 1)
    for row = -rows, rows do
        local width = size / aspect * (1 - math.abs(row) / (rows + 1))
        -- Les bandes se chevauchent d'un rien pour qu'aucun trait ne les sépare
        DrawRect(x, y + row * rowHeight, width, rowHeight * 1.2, color[1], color[2], color[3], 255)
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
