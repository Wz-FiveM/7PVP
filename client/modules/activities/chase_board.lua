---Tableau du classement ELO de la course poursuite (Config.Chase.board) : une page web
---(web/build/board.html) rendue en texture DUI et dessinée comme un écran posé dans la zone safe
---du Freeroam. Le top est lu dans le state bag global publié par le serveur (ChaseRating).
---Le navigateur DUI est créé la première fois que le joueur s'approche, puis gardé (page statique).
---@class ChaseBoardModule
local ChaseBoard = PVP.define('ChaseBoard')
local State = PVP.use('State')

ChaseBoard.STATE_KEY = '7pvp:chaseBoard'
ChaseBoard.WIDTH = 1024 -- taille de la texture (voir web/src/board/board.css)
ChaseBoard.HEIGHT = 768
ChaseBoard.TXD = '7pvp_chase_board'
ChaseBoard.TEXTURE = 'board'
ChaseBoard.CHECK_INTERVAL = 1000 -- ms entre deux vérifications de distance (loin de l'écran)
-- Le contenu est renvoyé régulièrement : la page peut ne pas être prête au premier envoi
ChaseBoard.RESEND_INTERVAL = 2000

ChaseBoard.dui = nil
ChaseBoard.txd = nil
ChaseBoard.sentAt = 0
---@type vector3[]|nil coins de l'écran : haut gauche, haut droite, bas droite, bas gauche
ChaseBoard.corners = nil

function ChaseBoard.init()
    AddEventHandler('onResourceStop', function(resource)
        if resource == GetCurrentResourceName() then ChaseBoard.destroy() end
    end)
    AddStateBagChangeHandler(ChaseBoard.STATE_KEY, 'global', function(_, _, rows)
        ChaseBoard.send(rows)
    end)
    CreateThread(ChaseBoard.loop)
end

function ChaseBoard.loop()
    local config = Config.Chase.board
    while true do
        local near = State.mode == 'freeroam'
            and #(GetEntityCoords(PlayerPedId()) - config.coords) < config.drawDistance
        if near then
            ChaseBoard.create()
            ChaseBoard.draw()
            if GetGameTimer() - ChaseBoard.sentAt > ChaseBoard.RESEND_INTERVAL then ChaseBoard.send() end
            Wait(0)
        else
            Wait(ChaseBoard.CHECK_INTERVAL)
        end
    end
end

function ChaseBoard.create()
    if ChaseBoard.dui then return end
    ChaseBoard.txd = ChaseBoard.txd or CreateRuntimeTxd(ChaseBoard.TXD)
    local url = ('nui://%s/web/build/board.html'):format(GetCurrentResourceName())
    ChaseBoard.dui = CreateDui(url, ChaseBoard.WIDTH, ChaseBoard.HEIGHT)
    CreateRuntimeTextureFromDuiHandle(ChaseBoard.txd, ChaseBoard.TEXTURE, GetDuiHandle(ChaseBoard.dui))
    ChaseBoard.corners = ChaseBoard.computeCorners()
    ChaseBoard.sentAt = 0
end

function ChaseBoard.destroy()
    if not ChaseBoard.dui then return end
    DestroyDui(ChaseBoard.dui)
    ChaseBoard.dui = nil
end

---Écran déplacé par un admin (Config.Chase.board modifié) : coins recalculés.
function ChaseBoard.relocate()
    if ChaseBoard.dui then ChaseBoard.corners = ChaseBoard.computeCorners() end
end

---@param rows table|nil top reçu (sinon celui du state bag)
function ChaseBoard.send(rows)
    if not ChaseBoard.dui then return end
    SendDuiMessage(ChaseBoard.dui, json.encode({
        rows = rows or GlobalState[ChaseBoard.STATE_KEY] or {},
        size = Config.Chase.elo.boardSize,
    }))
    ChaseBoard.sentAt = GetGameTimer()
end

---Coins de l'écran, posé au sol (le sol est cherché sous le point de config).
---@return vector3[]
function ChaseBoard.computeCorners()
    local config = Config.Chase.board
    local base = config.coords
    local found, ground = GetGroundZFor_3dCoord(base.x, base.y, base.z + 5.0, false)
    local bottom = (found and ground or base.z) + config.elevation
    local height = config.width * ChaseBoard.HEIGHT / ChaseBoard.WIDTH
    -- Vu de face (en regardant l'écran), la droite de l'écran
    local heading = math.rad(config.heading)
    local right = vector3(-math.cos(heading), -math.sin(heading), 0.0) * (config.width / 2)
    local center = vector3(base.x, base.y, bottom)
    local top = vector3(0.0, 0.0, height)
    return { center - right + top, center + right + top, center + right, center - right }
end

---Dessine l'écran (à chaque image), seulement vu de face.
function ChaseBoard.draw()
    local corners = ChaseBoard.corners
    if not corners or IsNuiFocused() then return end
    local heading = math.rad(Config.Chase.board.heading)
    local front = vector3(-math.sin(heading), math.cos(heading), 0.0)
    local toCamera = GetFinalRenderedCamCoord() - Config.Chase.board.coords
    if toCamera.x * front.x + toCamera.y * front.y <= 0.0 then return end

    local tl, tr, br, bl = corners[1], corners[2], corners[3], corners[4]
    -- Les deux sens de rotation : un seul est visible selon le côté que le jeu garde
    ChaseBoard.triangle(tl, tr, br, 0.0, 0.0, 1.0, 0.0, 1.0, 1.0)
    ChaseBoard.triangle(tl, br, bl, 0.0, 0.0, 1.0, 1.0, 0.0, 1.0)
    ChaseBoard.triangle(br, tr, tl, 1.0, 1.0, 1.0, 0.0, 0.0, 0.0)
    ChaseBoard.triangle(bl, br, tl, 0.0, 1.0, 1.0, 1.0, 0.0, 0.0)
end

---@param a vector3
---@param b vector3
---@param c vector3
function ChaseBoard.triangle(a, b, c, u1, v1, u2, v2, u3, v3)
    DrawSpritePoly(a.x, a.y, a.z, b.x, b.y, b.z, c.x, c.y, c.z, 255, 255, 255, 255,
        ChaseBoard.TXD, ChaseBoard.TEXTURE, u1, v1, 1.0, u2, v2, 1.0, u3, v3, 1.0)
end
