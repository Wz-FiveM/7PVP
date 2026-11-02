---Gamertags : nom et barre de vie au-dessus de la tête des joueurs à portée, avec le label du crew
---et, en PvP, les couleurs de nom choisies par le joueur.
---Option admin : tous les joueurs, avec leur ID. En PvP, chacun voit aussi les membres de son crew.
---Jamais au lobby ni dans le créateur.
---@class GamertagsModule
local Gamertags = PVP.define('Gamertags')
local State = PVP.use('State')
local Crew = PVP.use('Crew')
local NameColors = PVP.use('NameColors')

Gamertags.active = false -- option admin
Gamertags.crewTag = nil -- label du crew du joueur
Gamertags.running = false -- boucle en cours (couper puis remettre l'option ne doit pas en lancer une deuxième)
Gamertags.tags = {} -- joueur -> { id, ped, label }

-- Composants des gamertags du jeu
Gamertags.COMPONENT_NAME = 0
Gamertags.COMPONENT_HEALTH = 2

Gamertags.REFRESH_MS = 500

function Gamertags.init()
    AddEventHandler('onResourceStop', function(resource)
        if resource == GetCurrentResourceName() then Gamertags.clear() end
    end)
end

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
    while Gamertags.active or Gamertags.crewTag do
        if State.mode then Gamertags.refresh() else Gamertags.clear() end
        Wait(Gamertags.REFRESH_MS)
    end
    Gamertags.clear()
    Gamertags.running = false
end

---Crée les gamertags des joueurs à portée et retire ceux qui n'y sont plus.
function Gamertags.refresh()
    local me = PlayerId()
    local coords = GetEntityCoords(PlayerPedId())
    local seen = {}

    for _, player in ipairs(GetActivePlayers()) do
        local ped = GetPlayerPed(player)
        local range = player ~= me and ped ~= 0 and Gamertags.rangeOf(player)
        if range and #(GetEntityCoords(ped) - coords) <= range then
            seen[player] = true
            Gamertags.show(player, ped)
        end
    end

    for player in pairs(Gamertags.tags) do
        if not seen[player] then Gamertags.remove(player) end
    end
end

---@param player number
---@return number|nil portée de son gamertag, nil s'il n'en a pas
function Gamertags.rangeOf(player)
    if Gamertags.active then return Config.Admin.GamertagDistance end
    local crew = Crew.tagOf(GetPlayerServerId(player))
    if crew and crew == Gamertags.crewTag then return Config.Crews.gamertagDistance end
    return nil
end

---Les couleurs ne comptent qu'en PvP.
---@param player number
---@return string son nom, avec ses couleurs
function Gamertags.nameOf(player)
    local name = GetPlayerName(player)
    if State.mode ~= 'pvp' then return name end
    return NameColors.format(name, Player(GetPlayerServerId(player)).state[NameColors.STATE_KEY])
end

---@param player number
---@return string « [MGZ] Nom », précédé de l'ID avec l'option admin
function Gamertags.labelOf(player)
    local serverId = GetPlayerServerId(player)
    local label = Crew.label(serverId, Gamertags.nameOf(player))
    return Gamertags.active and ('[%d] %s'):format(serverId, label) or label
end

---@param player number
---@param ped number
function Gamertags.show(player, ped)
    local tag = Gamertags.tags[player]
    local label = Gamertags.labelOf(player)
    -- Le personnage change à la réapparition : le gamertag suit l'ancien, on le recrée
    if tag and (tag.ped ~= ped or tag.label ~= label or not IsMpGamerTagActive(tag.id)) then
        Gamertags.remove(player)
        tag = nil
    end
    if tag then return end

    local id = CreateFakeMpGamerTag(ped, label, false, false, '', 0)
    SetMpGamerTagVisibility(id, Gamertags.COMPONENT_NAME, true)
    SetMpGamerTagVisibility(id, Gamertags.COMPONENT_HEALTH, true)
    SetMpGamerTagAlpha(id, Gamertags.COMPONENT_HEALTH, 255)
    Gamertags.tags[player] = { id = id, ped = ped, label = label }
end

---@param player number
function Gamertags.remove(player)
    RemoveMpGamerTag(Gamertags.tags[player].id)
    Gamertags.tags[player] = nil
end

function Gamertags.clear()
    for player in pairs(Gamertags.tags) do Gamertags.remove(player) end
end
