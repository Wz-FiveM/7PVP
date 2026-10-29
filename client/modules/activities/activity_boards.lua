---Tableaux du classement ELO des modes de jeu du Freeroam (Config.FreeroamBoards) : une page web
---(web/build/board.html) par mode, rendue en texture DUI et dessinée comme un écran posé dans la zone
---safe. Le top de chaque mode est lu dans son state bag global, publié par le serveur (ActivityRating).
---Le navigateur DUI d'un tableau est créé la première fois que le joueur s'approche, puis gardé.
---@class ActivityBoard
---@field activity string clé de Config.FreeroamActivities
---@field dui any|nil
---@field txd string nom du dictionnaire de texture (un par tableau)
---@field txdHandle any|nil
---@field sentAt integer
---@field corners vector3[]|nil coins de l'écran : haut gauche, haut droite, bas droite, bas gauche

---@class ActivityBoardsModule
local ActivityBoards = PVP.define('ActivityBoards')
local State = PVP.use('State')

ActivityBoards.STATE_PREFIX = '7pvp:board:'
ActivityBoards.WIDTH = 1024 -- taille de la texture (voir web/src/board/board.css)
ActivityBoards.HEIGHT = 768
ActivityBoards.TXD_PREFIX = '7pvp_board_'
ActivityBoards.TEXTURE = 'board'
ActivityBoards.CHECK_INTERVAL = 1000 -- ms entre deux vérifications de distance (loin des écrans)
-- Le contenu est renvoyé régulièrement : la page peut ne pas être prête au premier envoi
ActivityBoards.RESEND_INTERVAL = 2000

---@type table<string, ActivityBoard> par mode
ActivityBoards.boards = {}

function ActivityBoards.init()
    AddEventHandler('onResourceStop', function(resource)
        if resource == GetCurrentResourceName() then ActivityBoards.destroyAll() end
    end)
    for _, config in ipairs(Config.FreeroamBoards.boards) do
        local activity = config.activity
        AddStateBagChangeHandler(ActivityBoards.STATE_PREFIX .. activity, 'global', function(_, _, rows)
            local board = ActivityBoards.boards[activity]
            if board then ActivityBoards.send(board, rows) end
        end)
    end
    CreateThread(ActivityBoards.loop)
end

function ActivityBoards.loop()
    local settings = Config.FreeroamBoards
    while true do
        local near = {}
        if State.mode == 'freeroam' then
            local position = GetEntityCoords(PlayerPedId())
            for _, config in ipairs(settings.boards) do
                if #(position - config.coords) < settings.drawDistance then near[#near + 1] = config end
            end
        end
        if #near > 0 then ActivityBoards.drawAll(near) end
        Wait(#near > 0 and 0 or ActivityBoards.CHECK_INTERVAL)
    end
end

---Dessine les écrans proches du plus loin au plus proche de la caméra : les polygones ne se
---masquent pas entre eux (le dernier dessiné passe devant), seul l'ordre les superpose correctement.
---@param configs table[] entrées de Config.FreeroamBoards.boards
function ActivityBoards.drawAll(configs)
    local camera = GetFinalRenderedCamCoord()
    local distances = {}
    for _, config in ipairs(configs) do distances[config] = #(camera - config.coords) end
    table.sort(configs, function(a, b) return distances[a] > distances[b] end)

    local now = GetGameTimer()
    for _, config in ipairs(configs) do
        local board = ActivityBoards.create(config)
        ActivityBoards.draw(board, config)
        if now - board.sentAt > ActivityBoards.RESEND_INTERVAL then ActivityBoards.send(board) end
    end
end

---@param config table entrée de Config.FreeroamBoards.boards
---@return ActivityBoard
function ActivityBoards.create(config)
    local board = ActivityBoards.boards[config.activity]
    if board and board.dui then return board end
    board = board or { activity = config.activity, txd = ActivityBoards.TXD_PREFIX .. config.activity, sentAt = 0 }
    ActivityBoards.boards[config.activity] = board
    board.txdHandle = board.txdHandle or CreateRuntimeTxd(board.txd)
    local url = ('nui://%s/web/build/board.html'):format(GetCurrentResourceName())
    board.dui = CreateDui(url, ActivityBoards.WIDTH, ActivityBoards.HEIGHT)
    CreateRuntimeTextureFromDuiHandle(board.txdHandle, ActivityBoards.TEXTURE, GetDuiHandle(board.dui))
    board.corners = ActivityBoards.computeCorners(config)
    board.sentAt = 0
    return board
end

function ActivityBoards.destroyAll()
    for _, board in pairs(ActivityBoards.boards) do
        if board.dui then
            DestroyDui(board.dui)
            board.dui = nil
        end
    end
end

---Écrans déplacés par un admin (Config.FreeroamBoards modifié) : coins recalculés.
function ActivityBoards.relocate()
    for _, config in ipairs(Config.FreeroamBoards.boards) do
        local board = ActivityBoards.boards[config.activity]
        if board and board.dui then board.corners = ActivityBoards.computeCorners(config) end
    end
end

---@param board ActivityBoard
---@param rows table|nil top reçu (sinon celui du state bag)
function ActivityBoards.send(board, rows)
    if not board.dui then return end
    local activity = Config.FreeroamActivities[board.activity] or {}
    SendDuiMessage(board.dui, json.encode({
        rows = rows or GlobalState[ActivityBoards.STATE_PREFIX .. board.activity] or {},
        size = Config.FreeroamBoards.size,
        title = activity.label or board.activity,
        icon = activity.icon,
    }))
    board.sentAt = GetGameTimer()
end

---Coins de l'écran, posé au sol (le sol est cherché sous le point de config).
---@param config table entrée de Config.FreeroamBoards.boards
---@return vector3[]
function ActivityBoards.computeCorners(config)
    local settings = Config.FreeroamBoards
    local base = config.coords
    local found, ground = GetGroundZFor_3dCoord(base.x, base.y, base.z + 5.0, false)
    local bottom = (found and ground or base.z) + settings.elevation
    local height = settings.width * ActivityBoards.HEIGHT / ActivityBoards.WIDTH
    -- Vu de face (en regardant l'écran), la droite de l'écran
    local heading = math.rad(config.heading)
    local right = vector3(-math.cos(heading), -math.sin(heading), 0.0) * (settings.width / 2)
    local center = vector3(base.x, base.y, bottom)
    local top = vector3(0.0, 0.0, height)
    return { center - right + top, center + right + top, center + right, center - right }
end

---Dessine l'écran (à chaque image), seulement vu de face.
---@param board ActivityBoard
---@param config table entrée de Config.FreeroamBoards.boards
function ActivityBoards.draw(board, config)
    local corners = board.corners
    if not corners or IsNuiFocused() then return end
    local heading = math.rad(config.heading)
    local front = vector3(-math.sin(heading), math.cos(heading), 0.0)
    local toCamera = GetFinalRenderedCamCoord() - config.coords
    if toCamera.x * front.x + toCamera.y * front.y <= 0.0 then return end

    local tl, tr, br, bl = corners[1], corners[2], corners[3], corners[4]
    -- Les deux sens de rotation : un seul est visible selon le côté que le jeu garde
    ActivityBoards.triangle(board.txd, tl, tr, br, 0.0, 0.0, 1.0, 0.0, 1.0, 1.0)
    ActivityBoards.triangle(board.txd, tl, br, bl, 0.0, 0.0, 1.0, 1.0, 0.0, 1.0)
    ActivityBoards.triangle(board.txd, br, tr, tl, 1.0, 1.0, 1.0, 0.0, 0.0, 0.0)
    ActivityBoards.triangle(board.txd, bl, br, tl, 0.0, 1.0, 1.0, 1.0, 0.0, 0.0)
end

---@param txd string
---@param a vector3
---@param b vector3
---@param c vector3
function ActivityBoards.triangle(txd, a, b, c, u1, v1, u2, v2, u3, v3)
    DrawSpritePoly(a.x, a.y, a.z, b.x, b.y, b.z, c.x, c.y, c.z, 255, 255, 255, 255,
        txd, ActivityBoards.TEXTURE, u1, v1, 1.0, u2, v2, 1.0, u3, v3, 1.0)
end
