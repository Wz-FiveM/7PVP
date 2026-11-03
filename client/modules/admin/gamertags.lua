---Gamertags : nom et barre de vie au-dessus de la tête des joueurs à portée, avec le label du crew
---et, en PvP, les couleurs de nom choisies par le joueur. Le drapeau de sa langue précède son nom.
---Option admin : tous les joueurs, avec leur ID. En PvP, chacun voit aussi les membres de son crew.
---Jamais au lobby ni dans le créateur.
---Dessinés à chaque image : les gamertags du jeu (CreateFakeMpGamerTag) affichent les codes ~r~ tels quels.
---@class GamertagsModule
local Gamertags = PVP.define('Gamertags')
local State = PVP.use('State')
local Crew = PVP.use('Crew')
local NameColors = PVP.use('NameColors')
local Language = PVP.use('Language')
local Locale = PVP.use('Locale')

Gamertags.active = false -- option admin
Gamertags.crewTag = nil -- label du crew du joueur
Gamertags.running = false -- boucle en cours (couper puis remettre l'option ne doit pas en lancer une deuxième)
Gamertags.tags = {} -- joueur -> { ped, label, flag }
Gamertags.flagTxd = nil
Gamertags.flags = {} -- langue -> texture créée (false si l'image manque)

Gamertags.REFRESH_MS = 500
Gamertags.BONE_HEAD = 31086
Gamertags.HEAD_OFFSET = 0.35 -- mètres entre la tête et la barre de vie
Gamertags.DEAD_HEALTH = 100 -- santé GTA du seuil de mort : la barre compte au-dessus
Gamertags.MAX_LABEL_BYTES = 99 -- au-delà, le jeu coupe le texte : le nom perd ses couleurs

-- Taille du texte selon la distance
Gamertags.FONT = 4
Gamertags.SCALE_NEAR = 0.38
Gamertags.SCALE_FAR = 0.24
Gamertags.SCALE_FAR_DISTANCE = 100.0
Gamertags.TEXT_HEIGHT = 0.075 -- hauteur du texte à l'échelle 1, en part de l'écran

-- Barre de vie à l'échelle SCALE_NEAR, en part de l'écran
Gamertags.BAR_WIDTH = 0.045
Gamertags.BAR_HEIGHT = 0.005

-- Drapeau de la langue (images web/public/flags, 3:2), à gauche du nom
Gamertags.FLAG_TXD = '7pvp_flags'
Gamertags.FLAG_FILE = 'web/build/flags/%s.png'
Gamertags.FLAG_RATIO = 1.5
Gamertags.FLAG_HEIGHT = 0.045 -- hauteur à l'échelle 1, en part de l'écran
Gamertags.FLAG_CENTER = 0.5 -- centre vertical, en part de la hauteur du texte au-dessus de la barre
Gamertags.FLAG_GAP = 0.004 -- espace avec le nom à l'échelle SCALE_NEAR
Gamertags.FLAG_BORDER = 0.0015 -- contour sombre à l'échelle SCALE_NEAR

---@param active boolean
function Gamertags.set(active)
    Gamertags.active = active
    if not active then Gamertags.clear() end
    Gamertags.start()
end

---@param tag string|nil label du crew du joueur
function Gamertags.setCrew(tag)
    Gamertags.crewTag = tag
    Gamertags.start()
end

function Gamertags.start()
    if not Gamertags.running and (Gamertags.active or Gamertags.crewTag) then
        Gamertags.running = true
        CreateThread(Gamertags.loop)
    end
end

function Gamertags.loop()
    local nextRefresh = 0
    while Gamertags.active or Gamertags.crewTag do
        if GetGameTimer() >= nextRefresh then
            nextRefresh = GetGameTimer() + Gamertags.REFRESH_MS
            if State.mode then Gamertags.refresh() else Gamertags.clear() end
        end
        Gamertags.draw()
        Wait(next(Gamertags.tags) and 0 or Gamertags.REFRESH_MS)
    end
    Gamertags.clear()
    Gamertags.running = false
end

---Liste les joueurs à portée, avec le texte de leur gamertag.
function Gamertags.refresh()
    local me = PlayerId()
    local coords = GetEntityCoords(PlayerPedId())
    local tags = {}

    for _, player in ipairs(GetActivePlayers()) do
        local ped = GetPlayerPed(player)
        local range = player ~= me and ped ~= 0 and Gamertags.rangeOf(player)
        if range and #(GetEntityCoords(ped) - coords) <= range then
            tags[player] = { ped = ped, label = Gamertags.labelOf(player), flag = Gamertags.flagOf(GetPlayerServerId(player)) }
        end
    end
    Gamertags.tags = tags
end

---@param player number
---@return number|nil portée de son gamertag, nil s'il n'en a pas
function Gamertags.rangeOf(player)
    if Gamertags.active then return Config.Admin.GamertagDistance end
    local crew = Crew.tagOf(GetPlayerServerId(player))
    if crew and crew == Gamertags.crewTag then return Config.Crews.gamertagDistance end
    return nil
end

---@param serverId integer
---@param name string
---@return string « [MGZ] Nom », précédé du character id avec l'option admin (server id s'il n'est pas chargé)
function Gamertags.format(serverId, name)
    local label = Crew.label(serverId, name)
    return Gamertags.active and ('[%d] %s'):format(State.charIdOf(serverId) or serverId, label) or label
end

---Les couleurs ne comptent qu'en PvP.
---@param player number
---@return string texte de son gamertag, avec les codes couleur GTA
function Gamertags.labelOf(player)
    local serverId = GetPlayerServerId(player)
    local name = GetPlayerName(player)
    local colors = State.mode == 'pvp' and Player(serverId).state[NameColors.STATE_KEY] or nil
    local label = Gamertags.format(serverId, NameColors.format(name, colors))
    if #label > Gamertags.MAX_LABEL_BYTES then return Gamertags.format(serverId, NameColors.format(name)) end
    return label
end

---@param serverId integer
---@return string|nil texture du drapeau de sa langue, nil s'il ne l'a pas encore envoyée
function Gamertags.flagOf(serverId)
    local lang = Player(serverId).state[Language.STATE_KEY]
    if type(lang) ~= 'string' or not Locale.isAvailable(lang) then return nil end
    if Gamertags.flags[lang] == nil then
        Gamertags.flagTxd = Gamertags.flagTxd or CreateRuntimeTxd(Gamertags.FLAG_TXD)
        local texture = CreateRuntimeTextureFromImage(Gamertags.flagTxd, lang, Gamertags.FLAG_FILE:format(lang))
        Gamertags.flags[lang] = texture ~= nil and texture ~= 0
    end
    return Gamertags.flags[lang] and lang or nil
end

function Gamertags.draw()
    local camera = GetFinalRenderedCamCoord()
    for _, tag in pairs(Gamertags.tags) do
        -- Le personnage peut disparaître entre deux mises à jour de la liste
        if DoesEntityExist(tag.ped) and IsEntityVisible(tag.ped) then
            local head = GetPedBoneCoords(tag.ped, Gamertags.BONE_HEAD, 0.0, 0.0, 0.0)
            local onScreen, x, y = GetScreenCoordFromWorldCoord(head.x, head.y, head.z + Gamertags.HEAD_OFFSET)
            if onScreen then Gamertags.drawTag(tag, x, y, #(camera - head)) end
        end
    end
end

---@param tag { ped: number, label: string, flag: string|nil }
---@param x number
---@param y number position de la barre de vie à l'écran
---@param distance number
function Gamertags.drawTag(tag, x, y, distance)
    local far = math.min(distance / Gamertags.SCALE_FAR_DISTANCE, 1.0)
    local scale = Gamertags.SCALE_NEAR + (Gamertags.SCALE_FAR - Gamertags.SCALE_NEAR) * far
    local textX = tag.flag and Gamertags.drawFlag(tag, x, y, scale) or x

    SetTextFont(Gamertags.FONT)
    SetTextScale(0.0, scale)
    SetTextCentre(true)
    SetTextOutline()
    SetTextColour(255, 255, 255, 255)
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(tag.label)
    EndTextCommandDisplayText(textX, y - scale * Gamertags.TEXT_HEIGHT)

    local maxHealth = math.max(1, GetEntityMaxHealth(tag.ped) - Gamertags.DEAD_HEALTH)
    local health = math.min(math.max(GetEntityHealth(tag.ped) - Gamertags.DEAD_HEALTH, 0) / maxHealth, 1.0)
    local width = Gamertags.BAR_WIDTH * scale / Gamertags.SCALE_NEAR
    local height = Gamertags.BAR_HEIGHT * scale / Gamertags.SCALE_NEAR
    DrawRect(x, y, width, height, 0, 0, 0, 160)
    DrawRect(x - width * (1.0 - health) / 2, y, width * health, height, 255, 255, 255, 230)
end

---Drapeau et nom centrés ensemble au-dessus de la barre de vie.
---@param tag { label: string, flag: string }
---@param x number
---@param y number position de la barre de vie à l'écran
---@param scale number
---@return number centre du nom à l'écran
function Gamertags.drawFlag(tag, x, y, scale)
    local aspect = GetAspectRatio(false)
    local ratio = scale / Gamertags.SCALE_NEAR
    local height = Gamertags.FLAG_HEIGHT * scale
    local width = height * Gamertags.FLAG_RATIO / aspect
    local gap = Gamertags.FLAG_GAP * ratio
    local border = Gamertags.FLAG_BORDER * ratio

    SetTextFont(Gamertags.FONT)
    SetTextScale(0.0, scale)
    BeginTextCommandGetWidth('STRING')
    AddTextComponentSubstringPlayerName(tag.label)
    local textWidth = EndTextCommandGetWidth(true)

    local textX = x + (width + gap) / 2
    local flagX = textX - textWidth / 2 - gap - width / 2
    local flagY = y - scale * Gamertags.TEXT_HEIGHT * Gamertags.FLAG_CENTER
    DrawRect(flagX, flagY, width + border * 2 / aspect, height + border * 2, 0, 0, 0, 160)
    DrawSprite(Gamertags.FLAG_TXD, tag.flag, flagX, flagY, width, height, 0.0, 255, 255, 255, 255)
    return textX
end

function Gamertags.clear()
    Gamertags.tags = {}
end
